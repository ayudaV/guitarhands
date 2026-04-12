class_name GuitarSlider extends PathFollow3D

@export var timestamp : float
@export var start_x: float
@export var end_x: float
@export var time_delta: float = 1.0
@export var track_speed := 2.0

@onready var slider_path: Path3D = $Path3D

const _BASE_LENGTH_METERS := 5.0
const _LANE_DELTA_1_LEFT := preload("res://resources/guitar_sliders_paths/0-5-1-L.tres")
const _LANE_DELTA_2_LEFT := preload("res://resources/guitar_sliders_paths/0-5-2-L.tres")

func _ready() -> void:
	# Root PathFollow3D position on the track timeline.
	progress = timestamp * track_speed
	# Move slider start lane.
	slider_path.position.x = start_x
	slider_path.curve = _build_curve_for_lanes(start_x, end_x, maxf(time_delta * track_speed, 0.2))

func _build_curve_for_lanes(lane_start: float, lane_end: float, target_length: float) -> Curve3D:
	var lane_delta := int(round(lane_end - lane_start))
	if lane_delta == 0:
		return _build_linear_curve(target_length)

	var use_abs_delta := mini(absi(lane_delta), 2)
	var source_curve: Curve3D = _LANE_DELTA_1_LEFT if use_abs_delta == 1 else _LANE_DELTA_2_LEFT
	var mirror_for_right := lane_delta > 0
	return _clone_scaled_curve(source_curve, target_length / _BASE_LENGTH_METERS, mirror_for_right)

func _build_linear_curve(target_length: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 0, 0))
	curve.add_point(Vector3(0, 0, target_length))
	return curve

func _clone_scaled_curve(source: Curve3D, z_scale: float, mirror_x: bool) -> Curve3D:
	var curve := Curve3D.new()
	var x_sign := -1.0 if mirror_x else 1.0
	for i in source.get_point_count():
		var p := source.get_point_position(i)
		var in_h := source.get_point_in(i)
		var out_h := source.get_point_out(i)

		p.x *= x_sign
		in_h.x *= x_sign
		out_h.x *= x_sign

		p.z *= z_scale
		in_h.z *= z_scale
		out_h.z *= z_scale

		curve.add_point(p, in_h, out_h)
	return curve
