from py4godot.classes import gdclass
from py4godot.classes.Image import Image
from py4godot.classes.ImageTexture import ImageTexture
from py4godot.classes.Node import Node
from py4godot.classes.core import PackedByteArray, Dictionary, Array, Vector2
import os
import time
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.hand_landmarker import HandLandmark, HandLandmarksConnections

FORMAT_RGB8 = 4
INVALID_LATENCY_MS = -1.0


@gdclass
class webcam_socket(Node):
	def _ready(self, camera_index: int = 0, max_hands: int = 2) -> None:
		self.camera_index = camera_index
		self.max_hands = max_hands
		self.cap = None
		self._open_webcam(self.camera_index)

		self.hand_model_path = "ai_models/hand_landmarker.task"
		self._hand_landmarker = self._create_hand_landmarker()

		self._last_result_hand_landmarks = []
		self._last_result_timestamp_ms = -1
		self._last_frame_width = 1
		self._last_frame_height = 1
		self._last_image_capture_latency_ms = INVALID_LATENCY_MS
		self._last_mediapipe_latency_ms = INVALID_LATENCY_MS
		self._last_total_latency_ms = INVALID_LATENCY_MS
		self._pending_detection_start = {}
		self._pending_capture_latency_ms = {}
		self._last_timestamp_ms = 0
		self._stable_hand_positions = {}

	def _exit_tree(self) -> None:
		if getattr(self, "cap", None) is not None and self.cap.isOpened():
			self.cap.release()
		if getattr(self, "_hand_landmarker", None) is not None:
			self._hand_landmarker.close()

	def _open_webcam(self, camera_index: int) -> bool:
		if getattr(self, "cap", None) is not None and self.cap.isOpened():
			self.cap.release()

		self.cap = cv2.VideoCapture(camera_index)
		if not self.cap.isOpened():
			print(f"Error: cannot open camera index {camera_index}")
			return False

		self.camera_index = camera_index
		return True

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
			num_hands=self.max_hands,
			min_hand_detection_confidence=0.5,
			min_hand_presence_confidence=0.5,
			min_tracking_confidence=0.5,
			result_callback=self._on_hand_result,
		)
		return vision.HandLandmarker.create_from_options(options)

	def _on_hand_result(self, result, output_image, timestamp_ms: int) -> None:
		start = self._pending_detection_start.pop(timestamp_ms, None)
		capture_latency_ms = self._pending_capture_latency_ms.pop(timestamp_ms, None)

		if start is not None:
			self._last_mediapipe_latency_ms = (time.perf_counter() - start) * 1000.0

		if capture_latency_ms is not None and self._last_mediapipe_latency_ms >= 0:
			self._last_total_latency_ms = capture_latency_ms + self._last_mediapipe_latency_ms

		self._last_result_hand_landmarks = list(getattr(result, "hand_landmarks", []) or [])
		self._last_result_timestamp_ms = int(timestamp_ms)

	def _build_hand_identity_map(self, limit: int) -> dict:
		identity_map = {}
		entries = []

		for raw_index, hand_landmarks in enumerate(self._last_result_hand_landmarks):
			if raw_index >= limit:
				break
			if len(hand_landmarks) == 0:
				continue

			if len(hand_landmarks) > HandLandmark.WRIST:
				anchor = hand_landmarks[HandLandmark.WRIST]
				x_pos = float(getattr(anchor, "x", 0.5))
				y_pos = float(getattr(anchor, "y", 0.5))
			else:
				x_pos = 0.5
				y_pos = 0.5

			entries.append({"raw_index": raw_index, "x": x_pos, "y": y_pos})

		if len(entries) == 0:
			self._stable_hand_positions = {}
			return identity_map

		previous_positions = dict(getattr(self, "_stable_hand_positions", {}) or {})
		assigned_raw_indices = set()
		assigned_slots = set()
		candidate_pairs = []

		for entry in entries:
			for slot_index, previous_pos in previous_positions.items():
				if previous_pos is None:
					continue
				prev_x = float(previous_pos[0])
				prev_y = float(previous_pos[1])
				dx = float(entry["x"] - prev_x)
				dy = float(entry["y"] - prev_y)
				candidate_pairs.append((dx * dx + dy * dy, int(entry["raw_index"]), int(slot_index)))

		for _, raw_index, slot_index in sorted(candidate_pairs, key=lambda item: item[0]):
			if raw_index in assigned_raw_indices or slot_index in assigned_slots:
				continue
			identity_map[raw_index] = int(slot_index)
			assigned_raw_indices.add(raw_index)
			assigned_slots.add(int(slot_index))

		remaining_entries = [entry for entry in entries if int(entry["raw_index"]) not in assigned_raw_indices]
		remaining_entries.sort(key=lambda entry: float(entry["x"]))
		available_slots = [slot_index for slot_index in range(int(max(0, self.max_hands))) if slot_index not in assigned_slots]

		for entry, slot_index in zip(remaining_entries, available_slots):
			raw_index = int(entry["raw_index"])
			identity_map[raw_index] = int(slot_index)
			assigned_raw_indices.add(raw_index)
			assigned_slots.add(int(slot_index))

		new_positions = {}
		for entry in entries:
			raw_index = int(entry["raw_index"])
			slot_index = identity_map.get(raw_index)
			if slot_index is None:
				continue
			new_positions[int(slot_index)] = (float(entry["x"]), float(entry["y"]))

		self._stable_hand_positions = new_positions

		return identity_map

	def _next_timestamp_ms(self) -> int:
		now_ms = int(time.monotonic_ns() // 1_000_000)
		if now_ms <= self._last_timestamp_ms:
			now_ms = self._last_timestamp_ms + 1
		self._last_timestamp_ms = now_ms
		return now_ms

	def _capture_frame_rgb(self):
		if self.cap is None or not self.cap.isOpened():
			return None, INVALID_LATENCY_MS

		capture_start = time.perf_counter()
		ret, frame = self.cap.read()
		capture_latency_ms = (time.perf_counter() - capture_start) * 1000.0
		self._last_image_capture_latency_ms = capture_latency_ms

		if not ret:
			return None, capture_latency_ms

		frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
		frame_rgb = cv2.flip(frame_rgb, 1)
		height, width = frame_rgb.shape[:2]
		self._last_frame_width = int(width)
		self._last_frame_height = int(height)

		return frame_rgb, capture_latency_ms

	def get_available_webcams(self, max_index: int = 10) -> Array:
		available = Array.new0()
		for index in range(max_index):
			test_cap = cv2.VideoCapture(index)
			if test_cap is not None and test_cap.isOpened():
				available.append(int(index))
			if test_cap is not None:
				test_cap.release()
		return available

	def get_capture_resolution(self) -> Vector2:
		return Vector2.new3(float(self._last_frame_width), float(self._last_frame_height))

	def set_webcam(self, camera_index: int) -> bool:
		return self._open_webcam(int(camera_index))

	def get_frame(self) -> np.ndarray:
		if self.cap is None or not self.cap.isOpened():
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

	def _draw_hand_landmarks(self, frame_rgb: np.ndarray, hand_landmarks) -> None:
		height, width = frame_rgb.shape[:2]
		if len(hand_landmarks) == 0:
			return

		points = []
		for landmark in hand_landmarks:
			x = int(landmark.x * width)
			y = int(landmark.y * height)
			points.append((x, y))

		for connection in HandLandmarksConnections.HAND_CONNECTIONS:
			start_idx = connection.start
			end_idx = connection.end
			if start_idx < len(points) and end_idx < len(points):
				cv2.line(frame_rgb, points[start_idx], points[end_idx], (0, 255, 0), 2, cv2.LINE_AA)

		for point in points:
			cv2.circle(frame_rgb, point, 3, (255, 120, 0), -1, cv2.LINE_AA)

	def get_image(self) -> ImageTexture:
		return self.get_image_texture(draw_hand_landmarks=False)

	def get_image_texture(self, draw_hand_landmarks: bool = False) -> ImageTexture:
		empty = Image.new()
		frame_rgb, capture_latency_ms = self._capture_frame_rgb()
		if frame_rgb is None:
			return ImageTexture.create_from_image(empty)

		if self._hand_landmarker is not None:
			timestamp_ms = self._next_timestamp_ms()
			self._pending_detection_start[timestamp_ms] = time.perf_counter()
			self._pending_capture_latency_ms[timestamp_ms] = capture_latency_ms
			self._hand_landmarker.detect_async(
				mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb),
				timestamp_ms,
			)

		if draw_hand_landmarks:
			for hand_landmarks in self._last_result_hand_landmarks:
				self._draw_hand_landmarks(frame_rgb, hand_landmarks)

		return self._to_texture(frame_rgb)

	def get_thumb_index_tips(self, max_hands: int = 2) -> Array:
		tips = Array.new0()
		limit = int(max(0, max_hands))
		width = max(1, int(self._last_frame_width))
		height = max(1, int(self._last_frame_height))
		identity_map = self._build_hand_identity_map(limit)
		ordered_tips = []

		for raw_index, hand_landmarks in enumerate(self._last_result_hand_landmarks):
			if raw_index >= limit:
				break
			if len(hand_landmarks) <= HandLandmark.INDEX_FINGER_TIP:
				continue

			stable_hand_index = int(identity_map.get(raw_index, raw_index))

			thumb = hand_landmarks[HandLandmark.THUMB_TIP]
			index = hand_landmarks[HandLandmark.INDEX_FINGER_TIP]

			thumb_x = int(thumb.x * width)
			thumb_y = int(thumb.y * height)
			index_x = int(index.x * width)
			index_y = int(index.y * height)

			dx = (thumb.x - index.x) * width
			dy = (thumb.y - index.y) * height
			pinch_distance_px = float((dx * dx + dy * dy) ** 0.5)

			thumb_dict = Dictionary.new0()
			thumb_dict["x"] = thumb_x
			thumb_dict["y"] = thumb_y

			index_dict = Dictionary.new0()
			index_dict["x"] = index_x
			index_dict["y"] = index_y

			hand_dict = Dictionary.new0()
			hand_dict["hand_index"] = stable_hand_index
			hand_dict["detection_index"] = raw_index
			hand_dict["thumb"] = thumb_dict
			hand_dict["index"] = index_dict
			hand_dict["pinch_distance_px"] = pinch_distance_px

			ordered_tips.append((stable_hand_index, hand_dict))

		for _, hand_dict in sorted(ordered_tips, key=lambda item: int(item[0])):
			tips.append(hand_dict)

		return tips

	def get_thumb_pinky_tips(self, max_hands: int = 2) -> Array:
		tips = Array.new0()
		limit = int(max(0, max_hands))
		width = max(1, int(self._last_frame_width))
		height = max(1, int(self._last_frame_height))
		identity_map = self._build_hand_identity_map(limit)
		ordered_tips = []

		for raw_index, hand_landmarks in enumerate(self._last_result_hand_landmarks):
			if raw_index >= limit:
				break
			if len(hand_landmarks) <= HandLandmark.PINKY_TIP:
				continue

			stable_hand_index = int(identity_map.get(raw_index, raw_index))

			thumb = hand_landmarks[HandLandmark.THUMB_TIP]
			pinky = hand_landmarks[HandLandmark.PINKY_TIP]

			thumb_x = int(thumb.x * width)
			thumb_y = int(thumb.y * height)
			pinky_x = int(pinky.x * width)
			pinky_y = int(pinky.y * height)

			dx = (thumb.x - pinky.x) * width
			dy = (thumb.y - pinky.y) * height
			pinch_distance_px = float((dx * dx + dy * dy) ** 0.5)

			thumb_dict = Dictionary.new0()
			thumb_dict["x"] = thumb_x
			thumb_dict["y"] = thumb_y

			pinky_dict = Dictionary.new0()
			pinky_dict["x"] = pinky_x
			pinky_dict["y"] = pinky_y

			hand_dict = Dictionary.new0()
			hand_dict["hand_index"] = stable_hand_index
			hand_dict["detection_index"] = raw_index
			hand_dict["thumb"] = thumb_dict
			hand_dict["pinky"] = pinky_dict
			hand_dict["pinch_distance_px"] = pinch_distance_px

			ordered_tips.append((stable_hand_index, hand_dict))

		for _, hand_dict in sorted(ordered_tips, key=lambda item: int(item[0])):
			tips.append(hand_dict)

		return tips

	def get_thumb_pinky_rotations(self, max_hands: int = 2) -> Array:
		rotations = Array.new0()
		limit = int(max(0, max_hands))
		width = max(1, int(self._last_frame_width))
		height = max(1, int(self._last_frame_height))
		identity_map = self._build_hand_identity_map(limit)
		ordered_rotations = []

		for raw_index, hand_landmarks in enumerate(self._last_result_hand_landmarks):
			if raw_index >= limit:
				break
			if len(hand_landmarks) <= HandLandmark.PINKY_TIP:
				continue

			stable_hand_index = int(identity_map.get(raw_index, raw_index))

			thumb = hand_landmarks[HandLandmark.THUMB_TIP]
			pinky = hand_landmarks[HandLandmark.PINKY_TIP]

			thumb_x = int(thumb.x * width)
			thumb_y = int(thumb.y * height)
			pinky_x = int(pinky.x * width)
			pinky_y = int(pinky.y * height)

			dx = float(pinky_x - thumb_x)
			dy = float(pinky_y - thumb_y)
			rotation_rad = float(np.arctan2(dy, dx))
			rotation_deg = float(np.degrees(rotation_rad))

			thumb_dict = Dictionary.new0()
			thumb_dict["x"] = thumb_x
			thumb_dict["y"] = thumb_y

			pinky_dict = Dictionary.new0()
			pinky_dict["x"] = pinky_x
			pinky_dict["y"] = pinky_y

			hand_dict = Dictionary.new0()
			hand_dict["hand_index"] = stable_hand_index
			hand_dict["detection_index"] = raw_index
			hand_dict["thumb"] = thumb_dict
			hand_dict["pinky"] = pinky_dict
			hand_dict["rotation_rad"] = rotation_rad
			hand_dict["rotation_deg"] = rotation_deg

			ordered_rotations.append((stable_hand_index, hand_dict))

		for _, hand_dict in sorted(ordered_rotations, key=lambda item: int(item[0])):
			rotations.append(hand_dict)

		return rotations

	def get_landmark_distance(self, name_a: str, name_b: str, side: str = "") -> float:
		if not self._last_result_hand_landmarks:
			return 0.0

		try:
			landmark_a = HandLandmark[str(name_a).upper()]
			landmark_b = HandLandmark[str(name_b).upper()]
		except KeyError:
			return 0.0

		hand_landmarks = self._last_result_hand_landmarks[0]
		if len(hand_landmarks) <= max(int(landmark_a), int(landmark_b)):
			return 0.0

		lm1 = hand_landmarks[int(landmark_a)]
		lm2 = hand_landmarks[int(landmark_b)]
		dx = lm1.x - lm2.x
		dy = lm1.y - lm2.y
		dz = lm1.z - lm2.z
		return float((dx * dx + dy * dy + dz * dz) ** 0.5)

		return 0.0

	def get_latency(self, latency_type: str = "all") -> float:
		latency_key = str(latency_type).lower()
		if latency_key == "image_capture":
			return float(self._last_image_capture_latency_ms)
		if latency_key == "mediapipe_process":
			return float(self._last_mediapipe_latency_ms)
		return float(self._last_total_latency_ms)

	def get_last_detection_latency_ms(self) -> float:
		return float(self._last_mediapipe_latency_ms)

	def get_latency_breakdown(self):
		latency = Dictionary.new0()
		latency["all"] = float(self._last_total_latency_ms)
		latency["image_capture"] = float(self._last_image_capture_latency_ms)
		latency["mediapipe_process"] = float(self._last_mediapipe_latency_ms)
		return latency

	def get_handtracked_image(self) -> ImageTexture:
		return self.get_image_texture(draw_hand_landmarks=True)
