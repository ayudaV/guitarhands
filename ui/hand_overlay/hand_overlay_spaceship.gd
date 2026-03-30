extends Control
class_name HandOverlaySpaceShip

enum CaptureFitMode {
	STRETCH,
	CUT_TO_FIT,
}
@export var tracked_hands: int = 2
@export var pinch_threshold_px: float = 22.0
@export var fit_mode: CaptureFitMode = CaptureFitMode.STRETCH
@export var trigger_mouse_click: bool = true
@export var trigger_touch_click: bool = true

var _tips: Array = []
var _capture_size: Vector2 = Vector2.ONE
var _pressed_by_hand: Dictionary = {}

func _process(delta: float) -> void:
	var resolution: Vector2 = WebcamSocket.get_capture_resolution()
	var capture_width: int = max(1, int(resolution.x))
	var capture_height: int = max(1, int(resolution.y))
	var tips: Array = WebcamSocket.get_thumb_pinky_tips(tracked_hands)
	update_hands(tips, capture_width, capture_height)

func update_hands(tips: Array, capture_width: int, capture_height: int) -> void:
	_tips = tips
	_capture_size = Vector2(max(1, capture_width), max(1, capture_height))
	queue_redraw()

func clear_hands() -> void:
	_tips = []
	_pressed_by_hand.clear()
	queue_redraw()

func _draw() -> void:
	for hand_data in _tips:
		if typeof(hand_data) != TYPE_DICTIONARY:
			continue

		var hand_dict: Dictionary = hand_data

		var thumb: Dictionary = hand_dict.get("thumb", Dictionary())
		var index_tip: Dictionary = hand_dict.get("pinky", Dictionary())
		if typeof(thumb) != TYPE_DICTIONARY or typeof(index_tip) != TYPE_DICTIONARY:
			continue

		var thumb_pos := _map_capture_to_overlay(Vector2(float(thumb.get("x", 0)), float(thumb.get("y", 0))))
		var index_pos := _map_capture_to_overlay(Vector2(float(index_tip.get("x", 0)), float(index_tip.get("y", 0))))
		var middle_pos := (thumb_pos + index_pos) * 0.5

		var pinch_distance_px: float = float(hand_dict.get("pinch_distance_px", 99999.0))
		var is_pinch := pinch_distance_px <= pinch_threshold_px

		var line_color := Color(0.0, 1.0, 0.0, 0.95) if is_pinch else Color(0.0, 0.86, 1.0, 0.95)
		var point_color := Color(1.0, 0.0, 0.0, 0.95) if is_pinch else Color(1.0, 0.47, 0.0, 0.95)

		draw_line(thumb_pos, index_pos, line_color, 2.0, true)
		draw_line(thumb_pos, middle_pos, line_color, 2.0, true)
		draw_line(index_pos, middle_pos, line_color, 2.0, true)

		draw_circle(thumb_pos, 6.0, point_color)
		draw_circle(index_pos, 6.0, point_color)
		draw_circle(middle_pos, 6.0, point_color)

func _map_capture_to_overlay(capture_pos: Vector2) -> Vector2:
	var overlay_size: Vector2 = size
	var capture_w: float = _capture_size.x
	var capture_h: float = _capture_size.y

	if capture_w <= 0.0 or capture_h <= 0.0 or overlay_size.x <= 0.0 or overlay_size.y <= 0.0:
		return Vector2.ZERO

	if fit_mode == CaptureFitMode.STRETCH:
		return Vector2(
			capture_pos.x * overlay_size.x / capture_w,
			capture_pos.y * overlay_size.y / capture_h,
		)

	var scale: float = float(max(overlay_size.x / capture_w, overlay_size.y / capture_h))
	var drawn_size: Vector2 = Vector2(capture_w * scale, capture_h * scale)
	var offset: Vector2 = (overlay_size - drawn_size) * 0.5
	return Vector2(capture_pos.x * scale + offset.x, capture_pos.y * scale + offset.y)
