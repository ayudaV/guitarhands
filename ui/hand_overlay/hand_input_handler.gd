extends Node
class_name HandInputHandler

@export var overlay_path: NodePath = NodePath("..")
@export var input_device_path: NodePath = NodePath("../MotionCaptureInputDevice")
@export var tracked_hands: int = 2
@export var lost_detection_hold_ms: int = 120
@export var pinch_threshold_px: float = 22.0

var _overlay: HandOverlay = null
var _input_device: MotionCaptureInputDevice = null
var _last_seen_ms_by_hand: Dictionary = {}
var _last_tip_by_hand: Dictionary = {}

func _ready() -> void:
	_resolve_overlay()
	_resolve_input_device()

func _process(delta: float) -> void:
	if _overlay == null:
		_resolve_overlay()
	if _input_device == null:
		_resolve_input_device()

	var resolution: Vector2 = WebcamSocket.get_capture_resolution()
	var capture_width: int = max(1, int(resolution.x))
	var capture_height: int = max(1, int(resolution.y))
	var raw_tips: Array = WebcamSocket.get_thumb_pinky_tips(tracked_hands) if _use_spaceship_mode() else WebcamSocket.get_thumb_index_tips(tracked_hands)
	var tips: Array = _fill_lost_hands(raw_tips)

	if _overlay != null:
		_overlay.pinch_threshold_px = pinch_threshold_px
		_overlay.update_hands(tips, capture_width, capture_height)

	_process_motion_capture_inputs(tips, capture_width, capture_height)

func clear_inputs() -> void:
	if _input_device != null:
		_input_device.clear_all()
	_last_seen_ms_by_hand.clear()
	_last_tip_by_hand.clear()

func _resolve_overlay() -> void:
	var node: Node = get_node_or_null(overlay_path)
	if node != null and node is HandOverlay:
		_overlay = node as HandOverlay
	else:
		_overlay = null

func _resolve_input_device() -> void:
	var node: Node = get_node_or_null(input_device_path)
	if node != null and node is MotionCaptureInputDevice:
		_input_device = node as MotionCaptureInputDevice
	else:
		_input_device = null

func _fill_lost_hands(tips: Array) -> Array:
	var now_ms: int = Time.get_ticks_msec()
	var merged: Array = []
	var seen_hands: Dictionary = {}

	for hand_data in tips:
		if typeof(hand_data) != TYPE_DICTIONARY:
			continue
		var hand_dict: Dictionary = hand_data
		var hand_index: int = int(hand_dict.get("hand_index", -1))
		if hand_index < 0:
			continue

		seen_hands[hand_index] = true
		_last_seen_ms_by_hand[hand_index] = now_ms
		_last_tip_by_hand[hand_index] = hand_dict.duplicate(true)
		merged.append(hand_dict)

	for hand_key in _last_tip_by_hand.keys():
		if seen_hands.has(hand_key):
			continue

		var last_seen_ms: int = int(_last_seen_ms_by_hand.get(hand_key, 0))
		if now_ms - last_seen_ms <= lost_detection_hold_ms:
			merged.append(_last_tip_by_hand[hand_key])
		else:
			_last_seen_ms_by_hand.erase(hand_key)
			_last_tip_by_hand.erase(hand_key)

	return merged

func _process_motion_capture_inputs(tips: Array, capture_width: int, capture_height: int) -> void:
	if _input_device == null:
		return

	var active_pointer_ids: Array = []
	var secondary_tip_key: String = "pinky" if _use_spaceship_mode() else "index"

	for hand_data in tips:
		if typeof(hand_data) != TYPE_DICTIONARY:
			continue

		var hand_dict: Dictionary = hand_data
		var hand_index: int = int(hand_dict.get("hand_index", -1))
		if hand_index < 0:
			continue

		var thumb: Dictionary = hand_dict.get("thumb", Dictionary())
		var secondary_tip: Dictionary = hand_dict.get(secondary_tip_key, Dictionary())
		if typeof(thumb) != TYPE_DICTIONARY or typeof(secondary_tip) != TYPE_DICTIONARY:
			continue

		var thumb_pos := _map_capture_to_screen(
			Vector2(float(thumb.get("x", 0)), float(thumb.get("y", 0))),
			capture_width,
			capture_height
		)
		var secondary_pos := _map_capture_to_screen(
			Vector2(float(secondary_tip.get("x", 0)), float(secondary_tip.get("y", 0))),
			capture_width,
			capture_height
		)

		var pointer_pos := (thumb_pos + secondary_pos) * 0.5
		var pinch_distance_px: float = float(hand_dict.get("pinch_distance_px", 99999.0))
		var is_pressed: bool = pinch_distance_px <= pinch_threshold_px
		active_pointer_ids.append(hand_index)

		var payload := {
			"pinch_distance_px": pinch_distance_px,
			"thumb_pos": thumb_pos,
			"secondary_pos": secondary_pos,
			"secondary_tip_key": secondary_tip_key,
			"detection_index": int(hand_dict.get("detection_index", -1)),
		}
		_input_device.update_pointer(hand_index, pointer_pos, is_pressed, payload)

	_input_device.release_missing(active_pointer_ids)

func _map_capture_to_screen(capture_pos: Vector2, capture_width: int, capture_height: int) -> Vector2:
	if _overlay != null:
		return _overlay.map_capture_to_overlay(capture_pos)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if capture_width <= 0 or capture_height <= 0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO

	return Vector2(
		capture_pos.x * viewport_size.x / float(capture_width),
		capture_pos.y * viewport_size.y / float(capture_height)
	)

func _use_spaceship_mode() -> bool:
	return _overlay != null and _overlay.overlay_mode == HandOverlay.OverlayMode.SPACESHIP
