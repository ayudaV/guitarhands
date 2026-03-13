from py4godot.classes import gdclass
from py4godot.classes.Image import Image
from py4godot.classes.ImageTexture import ImageTexture
from py4godot.classes.Node import Node
from py4godot.classes.core import PackedByteArray
import os
import time
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.hand_landmarker import HandLandmark

FORMAT_RGB8 = 4
MAX_LANDMARK_DISTANCE = 1.7320508075688772
HAND_LANDMARK_NAMES = [landmark.name for landmark in HandLandmark]


@gdclass
class webcam_socket(Node):
	def _ready(self, camera_index: int = 0) -> None:
		self.camera_index = camera_index
		self.cap = cv2.VideoCapture(self.camera_index)
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {self.camera_index}")

		self.hand_model_path = "ai_models/hand_landmarker.task"
		self._hand_landmarker = self._create_hand_landmarker()

		self._last_hand_landmarks = {}
		self._last_result_hand_landmarks = []
		self._last_detection_latency_ms = -1.0
		self._pending_detection_start = {}
		self._last_timestamp_ms = 0

	def _exit_tree(self) -> None:
		if getattr(self, "cap", None) is not None and self.cap.isOpened():
			self.cap.release()
		if getattr(self, "_hand_landmarker", None) is not None:
			self._hand_landmarker.close()

	def _create_hand_landmarker(self):
		model_path = self.hand_model_path
		if not os.path.isabs(model_path):
			model_path = os.path.join(os.getcwd(), model_path)
		if not os.path.exists(model_path):
			print(f"Error: hand landmarker model not found at {model_path}")
			return None

		base_options = python.BaseOptions(model_asset_path=model_path)
		options = vision.HandLandmarkerOptions(
			base_options=base_options,
			running_mode=vision.RunningMode.LIVE_STREAM,
			num_hands=2,
			min_hand_detection_confidence=0.5,
			min_hand_presence_confidence=0.5,
			min_tracking_confidence=0.5,
			result_callback=self._on_hand_result,
		)
		return vision.HandLandmarker.create_from_options(options)

	def _on_hand_result(self, result, output_image, timestamp_ms: int) -> None:
		start = self._pending_detection_start.pop(timestamp_ms, None)
		if start is not None:
			self._last_detection_latency_ms = (time.perf_counter() - start) * 1000.0

		self._last_result_hand_landmarks = list(getattr(result, "hand_landmarks", []) or [])
		if len(self._last_result_hand_landmarks) > 0:
			hand_landmarks = self._last_result_hand_landmarks[0]
			self._last_hand_landmarks = {
				HAND_LANDMARK_NAMES[i]: hand_landmarks[i]
				for i in range(min(len(hand_landmarks), len(HAND_LANDMARK_NAMES)))
			}
		else:
			self._last_hand_landmarks = {}

	def _next_timestamp_ms(self) -> int:
		now_ms = int(time.monotonic_ns() // 1_000_000)
		if now_ms <= self._last_timestamp_ms:
			now_ms = self._last_timestamp_ms + 1
		self._last_timestamp_ms = now_ms
		return now_ms

	def get_frame(self) -> np.ndarray:
		if not self.cap.isOpened():
			return None
		ret, frame = self.cap.read()
		if not ret:
			return None
		return frame

	def _to_texture(self, frame_rgb: np.ndarray) -> ImageTexture:
		height, width = frame_rgb.shape[:2]
		frame_rgb = np.ascontiguousarray(frame_rgb, dtype=np.uint8)
		pba = PackedByteArray.from_memory_view(memoryview(frame_rgb))
		image = Image.create_from_data(width, height, False, FORMAT_RGB8, pba)
		return ImageTexture.create_from_image(image)

	def get_image(self) -> ImageTexture:
		empty = Image.new()
		frame = self.get_frame()
		if frame is None:
			return ImageTexture.create_from_image(empty)

		frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
		frame_rgb = cv2.flip(frame_rgb, 1)
		return self._to_texture(frame_rgb)

	def get_landmark_distance(self, name_a: str, name_b: str, side: str = "") -> float:
		if not self._last_hand_landmarks:
			return MAX_LANDMARK_DISTANCE

		key_a = str(name_a).upper()
		key_b = str(name_b).upper()
		if key_a in self._last_hand_landmarks and key_b in self._last_hand_landmarks:
			lm1 = self._last_hand_landmarks[key_a]
			lm2 = self._last_hand_landmarks[key_b]
			dx = lm1.x - lm2.x
			dy = lm1.y - lm2.y
			dz = lm1.z - lm2.z
			return float((dx * dx + dy * dy + dz * dz) ** 0.5)

		return MAX_LANDMARK_DISTANCE

	def get_last_detection_latency_ms(self) -> float:
		return float(self._last_detection_latency_ms)

	def get_handtracked_image(self) -> ImageTexture:
		empty = Image.new()
		frame = self.get_frame()
		if frame is None:
			return ImageTexture.create_from_image(empty)

		frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
		frame_rgb = cv2.flip(frame_rgb, 1)

		if self._hand_landmarker is not None:
			timestamp_ms = self._next_timestamp_ms()
			self._pending_detection_start[timestamp_ms] = time.perf_counter()
			self._hand_landmarker.detect_async(
				mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb),
				timestamp_ms,
			)

		for hand_landmarks in self._last_result_hand_landmarks:
			mp.solutions.drawing_utils.draw_landmarks(
				frame_rgb,
				hand_landmarks,
				mp.solutions.hands.HAND_CONNECTIONS,
				mp.solutions.drawing_styles.get_default_hand_landmarks_style(),
				mp.solutions.drawing_styles.get_default_hand_connections_style(),
			)

		return self._to_texture(frame_rgb)
