import argparse
import math
import threading
import time
from pathlib import Path

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision.hand_landmarker import HandLandmark


def clamp(value: float, min_value: float, max_value: float) -> float:
    return max(min_value, min(value, max_value))


class HandTriangleRotationTest:
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

        self.last_result = None
        self.last_latency_ms = -1.0

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

    def _draw_pyramid(self, frame_rgb, hand_landmarks, active: bool) -> None:
        height, width = frame_rgb.shape[:2]

        wrist = hand_landmarks[HandLandmark.WRIST]
        thumb = hand_landmarks[HandLandmark.THUMB_TIP]
        middle = hand_landmarks[HandLandmark.MIDDLE_FINGER_TIP]
        pinky = hand_landmarks[HandLandmark.PINKY_TIP]

        wrist_pt = (int(wrist.x * width), int(wrist.y * height))
        thumb_pt = (int(thumb.x * width), int(thumb.y * height))
        middle_pt = (int(middle.x * width), int(middle.y * height))
        pinky_pt = (int(pinky.x * width), int(pinky.y * height))

        line_color = (0, 255, 0) if active else (0, 200, 255)
        point_color = (0, 255, 0) if active else (255, 150, 0)

        cv2.line(frame_rgb, wrist_pt, thumb_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, wrist_pt, middle_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, wrist_pt, pinky_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, thumb_pt, middle_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, middle_pt, pinky_pt, line_color, 2, cv2.LINE_AA)
        cv2.line(frame_rgb, pinky_pt, thumb_pt, line_color, 2, cv2.LINE_AA)

        cv2.circle(frame_rgb, wrist_pt, 6, point_color, -1, cv2.LINE_AA)
        cv2.circle(frame_rgb, thumb_pt, 6, point_color, -1, cv2.LINE_AA)
        cv2.circle(frame_rgb, middle_pt, 6, point_color, -1, cv2.LINE_AA)
        cv2.circle(frame_rgb, pinky_pt, 6, point_color, -1, cv2.LINE_AA)

    def _compute_rotations(self, hand_world_landmarks):
        thumb = hand_world_landmarks[HandLandmark.THUMB_TIP]
        middle = hand_world_landmarks[HandLandmark.MIDDLE_FINGER_TIP]
        pinky = hand_world_landmarks[HandLandmark.PINKY_TIP]

        # Rotation X: thumb to pinky vector
        pinky_vec_x = pinky.x - thumb.x
        pinky_vec_y = pinky.y - thumb.y
        pinky_vec_z = pinky.z - thumb.z
        
        # Rotation Y: thumb to middle vector
        middle_vec_x = middle.x - thumb.x
        middle_vec_y = middle.y - thumb.y
        middle_vec_z = middle.z - thumb.z

        # Rotation X based on thumb-pinky tilt (pitch)
        horizontal_dist_pinky = (pinky_vec_x * pinky_vec_x + pinky_vec_z * pinky_vec_z) ** 0.5
        rotation_x = float(math.degrees(math.atan2(pinky_vec_y, horizontal_dist_pinky)))

        # Rotation Y based on thumb-middle tilt (roll)
        horizontal_dist_middle = (middle_vec_x * middle_vec_x + middle_vec_z * middle_vec_z) ** 0.5
        rotation_y = float(math.degrees(math.atan2(-middle_vec_y, horizontal_dist_middle)))

        return clamp(rotation_x, -90.0, 90.0), clamp(rotation_y, -90.0, 90.0)

    def _draw_progress_bar(self, frame_rgb, label: str, value_deg: float, x: int, y: int) -> None:
        width = 260
        height = 20

        normalized = (clamp(value_deg, -90.0, 90.0) + 90.0) / 180.0
        fill_w = int(width * normalized)

        cv2.rectangle(frame_rgb, (x, y), (x + width, y + height), (180, 180, 180), 2)
        cv2.rectangle(frame_rgb, (x, y), (x + fill_w, y + height), (0, 210, 120), -1)

        center_x = x + width // 2
        cv2.line(frame_rgb, (center_x, y - 4), (center_x, y + height + 4), (255, 255, 255), 1, cv2.LINE_AA)

        cv2.putText(
            frame_rgb,
            f"{label}: {value_deg:+.1f} deg",
            (x, y - 8),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )

    def run(self) -> None:
        print("Starting triangle rotation test. Press 'q' to quit.")

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

                horizontal_deg = 0.0
                vertical_deg = 0.0
                has_rotation = False

                if result and getattr(result, "hand_landmarks", None):
                    world = getattr(result, "hand_world_landmarks", []) or []
                    for i, hand_landmarks in enumerate(result.hand_landmarks):
                        hand_world = world[i] if i < len(world) else None
                        active = False
                        if hand_world and len(hand_world) > HandLandmark.MIDDLE_FINGER_TIP:
                            horizontal_deg, vertical_deg = self._compute_rotations(hand_world)
                            has_rotation = True
                            active = True
                        self._draw_pyramid(frame_rgb, hand_landmarks, active)

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

                if has_rotation:
                    self._draw_progress_bar(frame_rgb, "Vertical X (Pitch)", horizontal_deg, 16, 66)
                    self._draw_progress_bar(frame_rgb, "Vertical Y (Roll)", vertical_deg, 16, 120)
                else:
                    cv2.putText(
                        frame_rgb,
                        "Show hand to compute rotation",
                        (16, 100),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.7,
                        (255, 255, 0),
                        2,
                        cv2.LINE_AA,
                    )

                cv2.imshow("Hand Triangle Rotation Test", cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR))
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
    parser = argparse.ArgumentParser(description="Standalone hand triangle rotation test")
    parser.add_argument("--model", type=str, default=default_model_path(), help="Path to hand_landmarker.task")
    parser.add_argument("--camera", type=int, default=0, help="OpenCV camera index")
    parser.add_argument("--max-hands", type=int, default=2, help="Maximum hands to detect")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    model = Path(args.model)
    if not model.exists():
        raise FileNotFoundError(f"Model not found: {model}")

    app = HandTriangleRotationTest(
        model_path=str(model),
        camera_index=args.camera,
        max_hands=args.max_hands,
    )
    app.run()


if __name__ == "__main__":
    main()
