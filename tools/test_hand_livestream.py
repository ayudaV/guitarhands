import argparse
import threading
import time
from pathlib import Path

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.hand_landmarker import HandLandmark


class LiveStreamHandLatencyTest:
    def __init__(self, model_path: str, camera_index: int = 0, max_hands: int = 2) -> None:
        self.model_path = str(Path(model_path).resolve())
        self.camera_index = camera_index
        self.max_hands = max_hands

        self.cap = cv2.VideoCapture(self.camera_index)
        if not self.cap.isOpened():
            raise RuntimeError(f"Cannot open camera index {self.camera_index}")

        self._lock = threading.Lock()
        self._pending_start = {}
        self._last_timestamp_ms = 0

        self.last_latency_ms = -1.0
        self.last_result = None
        self._touch_state = {}
        self.click_count = 0
        self.pinch_threshold_m = 0.15

        base_options = python.BaseOptions(model_asset_path=self.model_path)
        options = vision.HandLandmarkerOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.LIVE_STREAM,
            num_hands=self.max_hands,
            min_hand_detection_confidence=0.5,
            min_hand_presence_confidence=0.5,
            min_tracking_confidence=0.5,
            result_callback=self._on_result,
        )
        self.landmarker = vision.HandLandmarker.create_from_options(options)

    def _draw_pinch_ui(self, frame_rgb, hand_landmarks, hand_world_landmarks, hand_id: str) -> None:
        height, width = frame_rgb.shape[:2]
        thumb = hand_landmarks[HandLandmark.THUMB_TIP]
        index = hand_landmarks[HandLandmark.INDEX_FINGER_TIP]

        thumb_pt = (int(thumb.x * width), int(thumb.y * height))
        index_pt = (int(index.x * width), int(index.y * height))
        middle_pt = ((thumb_pt[0] + index_pt[0]) // 2, (thumb_pt[1] + index_pt[1]) // 2)

        is_touching = False
        if hand_landmarks and len(hand_landmarks) > HandLandmark.INDEX_FINGER_TIP:
            thumb_n = hand_landmarks[HandLandmark.THUMB_TIP]
            index_n = hand_landmarks[HandLandmark.INDEX_FINGER_TIP]
            dx = (thumb_n.x - index_n.x) * width
            dy = (thumb_n.y - index_n.y) * height
            pinch_distance_m = (dx * dx + dy * dy) ** 0.5 / 100.0
            is_touching = pinch_distance_m <= self.pinch_threshold_m

        was_touching = self._touch_state.get(hand_id, False)
        if is_touching and not was_touching:
            self.click_count += 1
        self._touch_state[hand_id] = is_touching

        line_color = (0, 255, 0) if is_touching else (0, 220, 255)
        point_color = (0, 0, 255) if is_touching else (255, 120, 0)

        cv2.line(frame_rgb, thumb_pt, index_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, thumb_pt, middle_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, index_pt, middle_pt, line_color, 2, cv2.LINE_AA)

        cv2.circle(frame_rgb, thumb_pt, 6, point_color, -1, cv2.LINE_AA)
        cv2.circle(frame_rgb, index_pt, 6, point_color, -1, cv2.LINE_AA)
        cv2.circle(frame_rgb, middle_pt, 6, point_color, -1, cv2.LINE_AA)

    def _next_timestamp_ms(self) -> int:
        now_ms = int(time.monotonic_ns() // 1_000_000)
        with self._lock:
            if now_ms <= self._last_timestamp_ms:
                now_ms = self._last_timestamp_ms + 1
            self._last_timestamp_ms = now_ms
        return now_ms

    def _on_result(self, result, output_image, timestamp_ms: int) -> None:
        with self._lock:
            start = self._pending_start.pop(timestamp_ms, None)
            if start is not None:
                self.last_latency_ms = (time.perf_counter() - start) * 1000.0
            self.last_result = result

    def run(self) -> None:
        print("Starting live stream test. Press 'q' to quit.")

        try:
            while True:
                ok, frame_bgr = self.cap.read()
                if not ok:
                    print("Failed to read frame from camera.")
                    break

                frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
                frame_rgb = cv2.flip(frame_rgb, 1)

                timestamp_ms = self._next_timestamp_ms()
                with self._lock:
                    self._pending_start[timestamp_ms] = time.perf_counter()

                mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
                self.landmarker.detect_async(mp_image, timestamp_ms)

                with self._lock:
                    result = self.last_result
                    latency_ms = self.last_latency_ms

                if result and getattr(result, "hand_landmarks", None):
                    handedness = getattr(result, "handedness", []) or []
                    world = getattr(result, "hand_world_landmarks", []) or []
                    for i, hand_landmarks in enumerate(result.hand_landmarks):
                        hand_id = f"hand_{i}"
                        if i < len(handedness) and len(handedness[i]) > 0:
                            hand_id = str(handedness[i][0].category_name).upper()
                        hand_world_landmarks = world[i] if i < len(world) else None
                        self._draw_pinch_ui(frame_rgb, hand_landmarks, hand_world_landmarks, hand_id)

                latency_text = (
                    f"Detection latency: {latency_ms:.2f} ms" if latency_ms >= 0 else "Detection latency: waiting..."
                )
                cv2.putText(
                    frame_rgb,
                    latency_text,
                    (16, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7,
                    (0, 255, 0),
                    2,
                    cv2.LINE_AA,
                )

                cv2.putText(
                    frame_rgb,
                    f"Clicks: {self.click_count}",
                    (16, 62),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7,
                    (255, 255, 0),
                    2,
                    cv2.LINE_AA,
                )

                cv2.imshow("MediaPipe Hand Landmarker LIVE_STREAM Test", cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR))

                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
        finally:
            self.close()

    def close(self) -> None:
        if hasattr(self, "landmarker") and self.landmarker is not None:
            self.landmarker.close()
        if hasattr(self, "cap") and self.cap is not None and self.cap.isOpened():
            self.cap.release()
        cv2.destroyAllWindows()


def default_model_path() -> str:
    return str((Path(__file__).resolve().parent.parent / "ai_models" / "hand_landmarker.task").resolve())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Standalone MediaPipe Hand Landmarker LIVE_STREAM latency test")
    parser.add_argument("--model", type=str, default=default_model_path(), help="Path to hand_landmarker.task")
    parser.add_argument("--camera", type=int, default=0, help="OpenCV camera index")
    parser.add_argument("--max-hands", type=int, default=2, help="Maximum hands to detect")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    model = Path(args.model)
    if not model.exists():
        raise FileNotFoundError(f"Model not found: {model}")

    app = LiveStreamHandLatencyTest(
        model_path=str(model),
        camera_index=args.camera,
        max_hands=args.max_hands,
    )
    app.run()


if __name__ == "__main__":
    main()
