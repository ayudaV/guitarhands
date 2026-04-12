class_name ShapesButton extends Path2D

@export var music: AudioStreamPlayer
@export var spawn_timestamp := 0.0
@export var time_delta := 1.0
@export var moving := false
@export var timestamp : float
@export var start_window := 0.2
@export var max_focus_scale := 1.0
@onready var path_follow = $PathFollow2D
@onready var shape_body: StaticBody2D = $PathFollow2D/ShapeButton
@onready var button_circle: TextureRect = $PathFollow2D/ShapeButton/ButtonCircle
@onready var timer_circle: TextureRect = $PathFollow2D/TimerCircle
@onready var line: Line2D = $Line2D
var enable = true
var _spawned := false
var _started := false
var _completed := false
var _is_pressing := false

func _ready() -> void:
	# If curve not set yet (no set_path call), configure default
	if curve.get_point_count() == 0:
		_configure_default_path()
	path_follow.progress_ratio = 0.0
	shape_body.visible = false
	timer_circle.visible = false
	line.visible = false
	timer_circle.scale = Vector2.ONE * max_focus_scale
	
func _process(delta: float) -> void:
	if not enable or music == null:
		return

	var song_time := music.get_playback_position()

	if not _spawned and song_time >= spawn_timestamp:
		_spawned = true
		shape_body.visible = true
		timer_circle.visible = true
		line.visible = true

	if not _spawned:
		return

	if not _started:
		_update_focus(song_time)
		if song_time >= timestamp:
			_start_auto_slide()
		return

	if moving:
		path_follow.progress_ratio += delta / max(time_delta, 0.001)
		if path_follow.progress_ratio >= 1.0:
			_complete_slide()


func _start_auto_slide() -> void:
	if _started or _completed:
		return
	_started = true
	moving = true
	timer_circle.visible = false
			
func start_slide_interaction() -> void:
	if not enable or _completed or not _spawned:
		return
	_is_pressing = true
	$PathFollow2D/Release.play()

func break_slide_interaction() -> void:
	_is_pressing = false

func _complete_slide() -> void:
	if _completed:
		return
	_completed = true
	moving = false
	Globals.add_score(1)
	_break_slide(true, _is_pressing)

func _break_slide(play_effect: bool, play_sound: bool = true) -> void:
	if not enable:
		return
	enable = false
	moving = false
	_is_pressing = false
	shape_body.queue_free()
	timer_circle.visible = false
	if play_effect:
		$PathFollow2D/GPUParticles.emitting = true
	if play_sound:
		$PathFollow2D/Release.play()
	else:
		queue_free()

func _update_focus(song_time: float) -> void:
	# Focus animation: scales from max_focus_scale (2.0) to 1.0 from spawn_timestamp to timestamp
	var denom = max(timestamp - spawn_timestamp, 0.001)
	var progress := clampf((song_time - spawn_timestamp) / denom, 0.0, 1.0)
	var scale_amount := lerpf(max_focus_scale, 0.25, progress)
	timer_circle.scale = Vector2.ONE * scale_amount

func set_path(path_curve: Curve2D) -> void:
	"""Set the path for this shape slider from a Curve2D."""
	curve = path_curve
	var line := $Line2D
	if line != null and line.has_method("refresh_points"):
		line.refresh_points()

func _configure_default_path() -> void:
	"""Configure a default path (used if no path is set)."""
	curve.clear_points()
	# Default to main lane path
	curve.add_point(Vector2(960.0 - 300.0, 540.0 - 100.0))
	curve.add_point(Vector2(960.0 + 300.0, 540.0 - 100.0))
	var line := $Line2D
	if line != null and line.has_method("refresh_points"):
		line.refresh_points()
	
func _on_release_finished() -> void:
	queue_free()
