from py4godot.classes import gdclass
from py4godot.classes.Image import Image
from py4godot.classes.ImageTexture import ImageTexture
from py4godot.classes.core import Array, PackedByteArray, Vector3
from py4godot.classes.Node import Node
from py4godot.classes.core import Dictionary
import os
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

FORMAT_RGB8 = 4
MAX_LANDMARK_DISTANCE = 1.7320508075688772
HAND_LANDMARK_NAMES = [
	"WRIST",
	"THUMB_CMC",
	"THUMB_MCP",
	"THUMB_IP",
	"THUMB_TIP",
	"INDEX_FINGER_MCP",
	"INDEX_FINGER_PIP",
	"INDEX_FINGER_DIP",
	"INDEX_FINGER_TIP",
	"MIDDLE_FINGER_MCP",
	"MIDDLE_FINGER_PIP",
	"MIDDLE_FINGER_DIP",
	"MIDDLE_FINGER_TIP",
	"RING_FINGER_MCP",
	"RING_FINGER_PIP",
	"RING_FINGER_DIP",
	"RING_FINGER_TIP",
	"PINKY_MCP",
	"PINKY_PIP",
	"PINKY_DIP",
	"PINKY_TIP",
]

@gdclass
class webcam_socket(Node):
	def _ready(self, camera_index: int = 0) -> None:
		self.camera_index = camera_index
		self.image_quality = 90  # JPEG quality
		self.cap = cv2.VideoCapture(self.camera_index)
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {self.camera_index}")
		self.hand_model_path = "ai_models/hand_landmarker.task"
		self._hand_landmarker = self._create_hand_landmarker()
		# Storage for last computed hand landmarks
		self._last_hand_landmarks = {}

	def _create_hand_landmarker(self):
		model_path = getattr(self, "hand_model_path", None) or "ai_models/hand_landmarker.task"
		if not os.path.isabs(model_path):
			model_path = os.path.join(os.getcwd(), model_path)
		if not os.path.exists(model_path):
			print(f"Error: hand landmarker model not found at {model_path}")
			return None
		base_options = python.BaseOptions(model_asset_path=model_path)
		options = vision.HandLandmarkerOptions(
			base_options=base_options,
			num_hands=2,
			min_hand_detection_confidence=0.5,
			min_hand_presence_confidence=0.5,
			min_tracking_confidence=0.5,
		)
		return vision.HandLandmarker.create_from_options(options)

	def get_frame(self) -> np.ndarray:
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {self.camera_index}")
			return None
		ret, frame = self.cap.read()
		if not ret:
			print("Error: failed to capture image")
			return None
		return frame

	def get_image(self) -> ImageTexture:
		_image = Image.new()
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {self.camera_index}")
			return _image
		frame = self.get_frame()
		if frame is None:
			return _image

		# Convert BGR (OpenCV) to RGB (Godot expects RGB pixel data)
		frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
		height, width = frame_rgb.shape[:2]
		frame_rgb = cv2.flip(frame_rgb, 1)
		frame_rgb = np.ascontiguousarray(frame_rgb, dtype=np.uint8)
		pba = PackedByteArray.from_memory_view(memoryview(frame_rgb))
		# Create image from raw RGB8 pixel data
		_image = Image.create_from_data(width, height, False, FORMAT_RGB8, pba)
		img_texture = ImageTexture.create_from_image(_image)
		return img_texture

	def get_last_hand_landmarks_godot(self) -> Dictionary:
		"""
		Return the last computed hand landmarks as a Godot Dictionary.
		Structure:
		{
			"LEFT_HAND": {"WRIST": Vector3(x, y, z), ...},
			"RIGHT_HAND": { ... }
		}
		- Coordinates are normalized (MediaPipe range 0..1 for x/y; z is relative depth).
		- Python dict and Vector3 are automatically marshalled to Godot Dictionary/Vector3.
		"""
		result = Dictionary.new0()
		for side, lm_map in self._last_hand_landmarks.items():
			inner = Dictionary.new0()
			for name, lm in lm_map.items():
				inner.get_or_add(name, Vector3.new3(lm.x, lm.y, lm.z))
			result.get_or_add(side, inner)
		return result

	def get_landmark_distance(self, name_a: str, name_b: str, side: str = "") -> float:
		"""
		Return the Euclidean 3D distance between two hand landmarks from the last processed frame.
		- name_a, name_b: MediaPipe HandLandmark names (e.g., "WRIST", "INDEX_FINGER_TIP").
		- side: optional hand selector; accepts "LEFT_HAND"/"RIGHT_HAND" or short forms like "left"/"right".
		  If omitted, the first hand that contains both landmarks is used.
		- Returns -1.0 when data is unavailable or landmarks are missing.
		"""
		if not getattr(self, "_last_hand_landmarks", None):
			return MAX_LANDMARK_DISTANCE

		key_a = str(name_a).upper()
		key_b = str(name_b).upper()

		hand_key = None
		if side:
			s = str(side).lower()
			hand_key = "LEFT_HAND" if s.startswith("l") else ("RIGHT_HAND" if s.startswith("r") else None)

		# Build candidate hands to check
		candidates = []
		if hand_key and hand_key in self._last_hand_landmarks:
			candidates = [hand_key]
		else:
			candidates = list(self._last_hand_landmarks.keys())

		for hk in candidates:
			lm_map = self._last_hand_landmarks.get(hk, {})
			if key_a in lm_map and key_b in lm_map:
				lm1 = lm_map[key_a]
				lm2 = lm_map[key_b]
				if not (0.0 <= lm1.x <= 1.0 and 0.0 <= lm1.y <= 1.0):
					return MAX_LANDMARK_DISTANCE
				if not (0.0 <= lm2.x <= 1.0 and 0.0 <= lm2.y <= 1.0):
					return MAX_LANDMARK_DISTANCE
				dx = lm1.x - lm2.x
				dy = lm1.y - lm2.y
				dz = lm1.z - lm2.z
				return float((dx * dx + dy * dy + dz * dz) ** 0.5)

		return MAX_LANDMARK_DISTANCE

	def get_handtracked_image(self) -> ImageTexture:
		"""
		Return an ImageTexture with hand landmarks drawn using MediaPipe Hands.
		- Captures a frame from the camera
		- Runs hand tracking (RGB input)
		- Draws landmarks on the frame (BGR)
		- Converts to RGB8 and returns as ImageTexture
		"""
		_image = Image.new()
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {self.camera_index}")
			return ImageTexture.create_from_image(_image)

		frame = self.get_frame()
		if frame is None:
			return ImageTexture.create_from_image(_image)

		# Prepare for MediaPipe Tasks (expects RGB, optionally flip for selfie view)
		image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
		image_rgb = cv2.flip(image_rgb, 1)
		if self._hand_landmarker is None:
			return ImageTexture.create_from_image(_image)
			
		mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=image_rgb)
		hand_res = self._hand_landmarker.detect(mp_image)

		self._last_hand_landmarks = {}
		if hand_res and getattr(hand_res, "hand_landmarks", None):
			for hand_landmarks in hand_res.hand_landmarks:
				label = "RIGHT_HAND"
				if len(hand_landmarks) > 0:
					wrist = hand_landmarks[0]
					label = "RIGHT_HAND" if wrist.x >= 0.5 else "LEFT_HAND"
				mapped_handmarks = {
					HAND_LANDMARK_NAMES[i]: hand_landmarks[i]
					for i in range(min(len(hand_landmarks), len(HAND_LANDMARK_NAMES)))
				}
				self._last_hand_landmarks[label] = mapped_handmarks

		# Draw hand landmarks and connections on the image if available
		if hand_res and getattr(hand_res, "hand_landmarks", None):
			for hand_landmarks in hand_res.hand_landmarks:
				mp.tasks.vision.drawing_utils.draw_landmarks(
					image_rgb,
					hand_landmarks,
					mp.tasks.vision.HandLandmarksConnections.HAND_CONNECTIONS,
					mp.tasks.vision.drawing_styles.get_default_hand_landmarks_style(),
					mp.tasks.vision.drawing_styles.get_default_hand_connections_style(),
				)

		# Convert to RGB for Godot and build ImageTexture
		frame_rgb = image_rgb
		height, width = frame_rgb.shape[:2]
		frame_rgb = np.ascontiguousarray(frame_rgb, dtype=np.uint8)
		pba = PackedByteArray.from_memory_view(memoryview(frame_rgb))
		_image = Image.create_from_data(width, height, False, FORMAT_RGB8, pba)
		img_texture = ImageTexture.create_from_image(_image)
		return img_texture
