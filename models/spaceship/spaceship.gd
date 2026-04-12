extends CharacterBody3D
@export var enable := true
@export var tracked_hands: int = 1
@export var min_follow_speed: float = 0.8
@export var max_follow_speed: float = 7.0
@export var max_rotation_rad_for_input: float = 0.8
@export var movement_x_min: float = -2.0
@export var movement_x_max: float = 2.0
@export var max_mesh_incline_deg: float = 25.0
@export var mesh_incline_lerp_speed: float = 8.0

@onready var ship_mesh: Node3D = $spaceship
@onready var hit_particles: GPUParticles3D = $GPUParticles3D
@onready var hit_sound: AudioStreamPlayer = $Click
var turn_rotation := 0.0
var normalized_turn: float = 0.0
var _target_x: float = 0.0

func _process(delta: float) -> void:
	if enable:
		turn_rotation = _get_turn_rotation()
		_target_x = _get_target_x_from_hand()

func sync_to_hand_position() -> void:
	if not enable:
		return
	_target_x = _get_target_x_from_hand()
	position.x = clampf(_target_x, movement_x_min, movement_x_max)


func _physics_process(delta: float) -> void:
	if enable:
		if max_rotation_rad_for_input > 0.0:
			normalized_turn = clamp(turn_rotation / max_rotation_rad_for_input, -1.0, 1.0)
		else:
			normalized_turn = 0.0

		var to_target: float = _target_x - position.x
		var target_direction: float = signf(to_target)
		var directional_rotation: float = target_direction * normalized_turn
		var throttle: float = clampf(directional_rotation, 0.0, 1.0)
		var follow_speed: float = lerpf(min_follow_speed, max_follow_speed, throttle)
		position.x = move_toward(position.x, _target_x, follow_speed * delta)
		position.x = clamp(position.x, movement_x_min, movement_x_max)
		position.z = 0.0

		var target_incline_rad: float = deg_to_rad(max_mesh_incline_deg) * normalized_turn
		ship_mesh.rotation.z = lerp(ship_mesh.rotation.z, target_incline_rad, clamp(delta * mesh_incline_lerp_speed, 0.0, 1.0))

func _get_turn_rotation() -> float:
	var rotations: Array = WebcamSocket.get_thumb_pinky_rotations(tracked_hands)
	if not rotations.is_empty():
		var first = rotations[0]
		if typeof(first) == TYPE_DICTIONARY:
			var first_dict: Dictionary = first
			return float(first_dict.get("rotation_rad", 0.0))

	# Fallback: derive rotation directly from thumb->pinky vector.
	var tips: Array = WebcamSocket.get_thumb_pinky_tips(tracked_hands)
	if tips.is_empty():
		return 0.0
	var first_tip = tips[0]
	if typeof(first_tip) != TYPE_DICTIONARY:
		return 0.0

	var hand_dict: Dictionary = first_tip
	var thumb: Dictionary = hand_dict.get("thumb", Dictionary())
	var pinky: Dictionary = hand_dict.get("pinky", Dictionary())
	if typeof(thumb) != TYPE_DICTIONARY or typeof(pinky) != TYPE_DICTIONARY:
		return 0.0

	var thumb_pos := Vector2(float(thumb.get("x", 0.0)), float(thumb.get("y", 0.0)))
	var pinky_pos := Vector2(float(pinky.get("x", 0.0)), float(pinky.get("y", 0.0)))
	var delta := pinky_pos - thumb_pos
	if delta.length_squared() <= 0.000001:
		return 0.0
	return -atan2(delta.y, delta.x)

func _get_target_x_from_hand() -> float:
	var tips: Array = WebcamSocket.get_thumb_pinky_tips(tracked_hands)
	if tips.is_empty():
		return position.x

	var first = tips[0]
	if typeof(first) != TYPE_DICTIONARY:
		return position.x

	var hand_dict: Dictionary = first
	var thumb: Dictionary = hand_dict.get("thumb", Dictionary())
	var pinky: Dictionary = hand_dict.get("pinky", Dictionary())
	if typeof(thumb) != TYPE_DICTIONARY or typeof(pinky) != TYPE_DICTIONARY:
		return position.x

	var resolution: Vector2 = WebcamSocket.get_capture_resolution()
	var capture_width: float = max(1.0, resolution.x)
	var capture_mid_x: float = (float(thumb.get("x", 0.0)) + float(pinky.get("x", 0.0))) * 0.5
	var normalized_x: float = clampf(capture_mid_x / capture_width, 0.0, 1.0)
	return lerpf(movement_x_min, movement_x_max, normalized_x)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == null or not body.is_in_group("Button"):
		return

	Globals.add_score(1)
	body.get_parent().queue_free()
	hit_particles.emitting = true
	hit_sound.play()
