extends Control
class_name HandOverlay

enum CaptureFitMode {
	STRETCH,
	CUT_TO_FIT,
}

enum OverlayMode {
	DEFAULT,     # thumb-index pinch overlay
	SPACESHIP,   # thumb-pinky rotation overlay
}

@export var overlay_mode: OverlayMode = OverlayMode.DEFAULT
@export var pinch_threshold_px: float = 22.0
@export var fit_mode: CaptureFitMode = CaptureFitMode.STRETCH
@export var cursor_index_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var cursor_index_offset: Vector2 = Vector2(12.0, -10.0)

var _tips: Array = []
var _capture_size: Vector2 = Vector2.ONE

func _ready() -> void:
	# Connect to global mode changes and update overlay accordingly
	Globals.mode_changed.connect(_on_mode_changed)
	# Set initial overlay mode based on current game mode
	_on_mode_changed(Globals.current_mode)

func _on_mode_changed(new_mode: Globals.Mode) -> void:
	# Update overlay mode when game mode changes
	match new_mode:
		Globals.Mode.SPACESHIP:
			overlay_mode = OverlayMode.SPACESHIP
		Globals.Mode.GUITAR:
			overlay_mode = OverlayMode.DEFAULT
		Globals.Mode.SHAPES:
			overlay_mode = OverlayMode.DEFAULT

func update_hands(tips: Array, capture_width: int, capture_height: int) -> void:
	_tips = tips
	_capture_size = Vector2(max(1, capture_width), max(1, capture_height))
	queue_redraw()

func clear_hands() -> void:
	_tips = []
	queue_redraw()

func _draw() -> void:
	match overlay_mode:
		OverlayMode.DEFAULT:
			_draw_default_overlay()
		OverlayMode.SPACESHIP:
			_draw_spaceship_overlay()

func _draw_default_overlay() -> void:
	for hand_data in _tips:
		if typeof(hand_data) != TYPE_DICTIONARY:
			continue

		var hand_dict: Dictionary = hand_data

		var thumb: Dictionary = hand_dict.get("thumb", Dictionary())
		var index_tip: Dictionary = hand_dict.get("index", Dictionary())
		if typeof(thumb) != TYPE_DICTIONARY or typeof(index_tip) != TYPE_DICTIONARY:
			continue

		var thumb_pos := _map_capture_to_overlay(Vector2(float(thumb.get("x", 0)), float(thumb.get("y", 0))))
		var index_pos := _map_capture_to_overlay(Vector2(float(index_tip.get("x", 0)), float(index_tip.get("y", 0))))
		var middle_pos := (thumb_pos + index_pos) * 0.5

		var pinch_distance_px: float = float(hand_dict.get("pinch_distance_px", 99999.0))
		var is_pinch := pinch_distance_px <= pinch_threshold_px
		var hand_index: int = int(hand_dict.get("hand_index", -1))

		var line_color := Color(0.0, 1.0, 0.0, 0.95) if is_pinch else Color(0.0, 0.86, 1.0, 0.95)
		var point_color := Color(1.0, 0.0, 0.0, 0.95) if is_pinch else Color(1.0, 0.47, 0.0, 0.95)

		draw_line(thumb_pos, index_pos, line_color, 3.0, true)
		draw_line(thumb_pos, middle_pos, line_color, 3.0, true)
		draw_line(index_pos, middle_pos, line_color, 3.0, true)

		draw_circle(thumb_pos, 10.0, point_color)
		draw_circle(index_pos, 10.0, point_color)
		draw_circle(middle_pos, clamp(20.0 * pinch_threshold_px/pinch_distance_px, 6, 15), point_color)

		var label_font: Font = get_theme_default_font()
		if label_font != null and hand_index >= 0:
			draw_string(
				label_font,
				index_pos + cursor_index_offset,
				str(hand_index),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				get_theme_default_font_size(),
				cursor_index_color,
			)

func _draw_spaceship_overlay() -> void:
	for hand_data in _tips:
		if typeof(hand_data) != TYPE_DICTIONARY:
			continue

		var hand_dict: Dictionary = hand_data

		var thumb: Dictionary = hand_dict.get("thumb", Dictionary())
		var pinky_tip: Dictionary = hand_dict.get("pinky", Dictionary())
		if typeof(thumb) != TYPE_DICTIONARY or typeof(pinky_tip) != TYPE_DICTIONARY:
			continue

		var thumb_pos := _map_capture_to_overlay(Vector2(float(thumb.get("x", 0)), float(thumb.get("y", 0))))
		var pinky_pos := _map_capture_to_overlay(Vector2(float(pinky_tip.get("x", 0)), float(pinky_tip.get("y", 0))))
		var middle_pos := (thumb_pos + pinky_pos) * 0.5

		var pinch_distance_px: float = float(hand_dict.get("pinch_distance_px", 99999.0))
		var is_pinch := pinch_distance_px <= pinch_threshold_px

		var line_color := Color(0.0, 1.0, 0.0, 0.95) if is_pinch else Color(0.0, 0.86, 1.0, 0.95)
		var point_color := Color(1.0, 0.0, 0.0, 0.95) if is_pinch else Color(1.0, 0.47, 0.0, 0.95)

		draw_line(thumb_pos, pinky_pos, line_color, 2.0, true)
		draw_line(thumb_pos, middle_pos, line_color, 2.0, true)
		draw_line(pinky_pos, middle_pos, line_color, 2.0, true)

		draw_circle(thumb_pos, 6.0, point_color)
		draw_circle(pinky_pos, 6.0, point_color)
		draw_circle(middle_pos, 6.0, point_color)
										

func map_capture_to_overlay(capture_pos: Vector2) -> Vector2:
	return _map_capture_to_overlay(capture_pos)

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
