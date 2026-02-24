from py4godot.classes import gdclass
from py4godot.classes.Image import Image
from py4godot.classes.ImageTexture import ImageTexture
from py4godot.classes.core import Array, PackedByteArray, Vector3
from py4godot.classes.Node import Node
from py4godot.classes.core import Dictionary
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.python.solutions.hands import Hands, HandLandmark
from mediapipe.python.solutions import drawing_utils
from mediapipe.python.solutions.pose import Pose, PoseLandmark, POSE_CONNECTIONS
from mediapipe.python.solutions.hands_connections import HAND_CONNECTIONS

FORMAT_RGB8 = 4

@gdclass
class webcam_socket(Node):
	def _ready(self, camera_index: int = 0) -> None:
		self.camera_index = camera_index
		self.image_quality = 90  # JPEG quality
		self.cap = cv2.VideoCapture(self.camera_index)
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {self.camera_index}")
		# Initialize MediaPipe Hands once to avoid per-frame setup cost
		self._hands = Hands(
			model_complexity=1,
			min_detection_confidence=0.5,
			min_tracking_confidence=0.5,
		)
		# Initialize MediaPipe Pose to infer handedness from wrist positions
		self._pose = Pose(
			model_complexity=1,
			min_detection_confidence=0.5,
			min_tracking_confidence=0.5,
		)
		# Storage for last computed hand landmarks
		self._last_hand_landmarks = {}

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
			return -1.0

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
				dx = lm1.x - lm2.x
				dy = lm1.y - lm2.y
				dz = lm1.z - lm2.z
				return float((dx * dx + dy * dy + dz * dz) ** 0.5)

		return -1.0

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
			return _image

		frame = self.get_frame()
		if frame is None:
			return _image

		# Prepare for MediaPipe (expects RGB, optionally flip for selfie view)
		image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
		image_rgb = cv2.flip(image_rgb, 1)
		image_rgb.flags.writeable = False
		hand_res = self._hands.process(image_rgb)
		pose_res = self._pose.process(image_rgb)
		image_rgb.flags.writeable = True
		# Determine hand labels ('Left'/'Right') by nearest pose wrist


		if pose_res and getattr(pose_res, 'pose_landmarks', None) and hand_res and getattr(hand_res, 'multi_hand_landmarks', None):
			lw = pose_res.pose_landmarks.landmark[PoseLandmark.LEFT_WRIST.value]
			rw = pose_res.pose_landmarks.landmark[PoseLandmark.RIGHT_WRIST.value]
			for hand_landmarks in hand_res.multi_hand_landmarks:
				# Determine hand labels ('Left'/'Right') by nearest pose wrist
				mapped_handmarks = {HandLandmark(i).name: hand_landmarks.landmark[i] for i in range(21)}
				left_distance = np.linalg.norm(np.array([lw.x, lw.y]) - np.array([hand_landmarks.landmark[0].x, hand_landmarks.landmark[0].y]))
				right_distance = np.linalg.norm(np.array([rw.x, rw.y]) - np.array([hand_landmarks.landmark[0].x, hand_landmarks.landmark[0].y]))
				if left_distance > right_distance: #Inverted because of image inverted
					self._last_hand_landmarks["LEFT_HAND"] = mapped_handmarks
				else:
					self._last_hand_landmarks["RIGHT_HAND"] = mapped_handmarks

		# Convert back to BGR for drawing
		image_bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)

		# Draw pose landmarks and connections on the image if available
		if pose_res and getattr(pose_res, 'pose_landmarks', None):
			try:
				drawing_utils.draw_landmarks(
					image_bgr,
					pose_res.pose_landmarks,
					POSE_CONNECTIONS,
				)
			except Exception:
				pass

		# Draw hand landmarks and connections on the image if available
		if hand_res and getattr(hand_res, 'multi_hand_landmarks', None):
			for hand_landmarks in hand_res.multi_hand_landmarks:
				drawing_utils.draw_landmarks(
					image_bgr,
					hand_landmarks,
					HAND_CONNECTIONS,
				)

		# Convert to RGB for Godot and build ImageTexture
		frame_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
		height, width = frame_rgb.shape[:2]
		frame_rgb = np.ascontiguousarray(frame_rgb, dtype=np.uint8)
		pba = PackedByteArray.from_memory_view(memoryview(frame_rgb))
		_image = Image.create_from_data(width, height, False, FORMAT_RGB8, pba)
		img_texture = ImageTexture.create_from_image(_image)
		return img_texture
