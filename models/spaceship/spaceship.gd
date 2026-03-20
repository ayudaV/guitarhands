extends CharacterBody3D
@export var enable := true
@export var tracked_hands: int = 1
@export var side_speed: float = 3.0
@export var max_rotation_rad_for_input: float = 0.8
@export var max_mesh_incline_deg: float = 25.0
@export var mesh_incline_lerp_speed: float = 8.0

@onready var ship_mesh: Node3D = $spaceship
var turn_rotation := 0.0
var normalized_turn: float = 0.0

func _process(delta: float) -> void:
	if enable:
		turn_rotation = _get_turn_rotation()


func _physics_process(delta: float) -> void:
	if enable:
		if max_rotation_rad_for_input > 0.0:
			normalized_turn = clamp(turn_rotation / max_rotation_rad_for_input, -1.0, 1.0)
		else:
			normalized_turn = 0.0

		var lateral_dir: Vector3 = global_transform.basis.x
		lateral_dir.y = 0.0
		if lateral_dir.length() > 0.0:
			lateral_dir = lateral_dir.normalized()

		global_position += lateral_dir * normalized_turn * side_speed * delta

		position.x = clamp(position.x, -2.0, 2.0)
		position.z = 0.0

		var target_incline_rad: float = deg_to_rad(max_mesh_incline_deg) * normalized_turn
		ship_mesh.rotation.z = lerp(ship_mesh.rotation.z, target_incline_rad, clamp(delta * mesh_incline_lerp_speed, 0.0, 1.0))

func _get_turn_rotation() -> float:
	var rotations: Array = WebcamSocket.get_thumb_pinky_rotations(tracked_hands)
	if rotations.is_empty():
		return 0.0

	var first = rotations[0]
	if typeof(first) != TYPE_DICTIONARY:
		return 0.0

	var first_dict: Dictionary = first
	return float(first_dict.get("rotation_rad", 0.0))
