class_name FileReader extends Node

@export var save_loc: StringName = "user://ado_show.tres"
@export var auto_play: bool = true

@export var track: Path3D
@export var music: AudioStreamPlayer
@export var track_follower: TrackFollower
@export var shape_root: Node

var track_speed: float = 0.0

var _guitar_button_scene: PackedScene = preload("res://models/button/Button.tscn")
var _guitar_slider_scene: PackedScene = preload("res://models/slider/slider.tscn")
var _shape_button_scene: PackedScene = preload("res://models/shape_slider/shape_slider.tscn")
var _switch_scene: PackedScene = preload("res://models/switch/Switch.tscn")
var _switch_nodes: Array[Switch] = []
var _playback_started: bool = false
const _SPAWNED_GROUP := "loaded_track_spawned"

func _ready() -> void:
	reload_track()
	if auto_play:
		start_playback()

func reload_track() -> void:
	_clear_spawned_nodes()
	_switch_nodes.clear()
	_playback_started = false
	if music != null:
		music.stop()
	if track_follower != null:
		track_follower.is_playing = false

	if not FileAccess.file_exists(save_loc):
		push_warning("FileReader: save file not found at %s" % String(save_loc))
		return

	var loaded := ResourceLoader.load(String(save_loc), "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is GenericResource):
		push_warning("FileReader: failed to load GenericResource from %s" % String(save_loc))
		return

	var data: GenericResource = loaded as GenericResource
	track_speed = data.bpm / 60.0 * data.speed_multiplier

	if music != null:
		music.stream = data.music

	if track_follower != null:
		track_follower.track_speed = track_speed
		track_follower.music = music

	_spawn_guitar_buttons(data.guitar_buttons)
	_spawn_guitar_sliders(data.guitar_sliders)
	_spawn_shape_buttons(data.shape_buttons)
	_spawn_switchs(data.switchs)

func start_playback() -> void:
	if _playback_started:
		return
	_playback_started = true

	if music != null:
		music.play()
	if track_follower != null:
		track_follower.is_playing = true

	for switch_node in _switch_nodes:
		if is_instance_valid(switch_node):
			switch_node.start()

func _spawn_guitar_buttons(items: Array[GuitarButtonData]) -> void:
	if track == null:
		push_warning("FileReader: track not set, cannot spawn guitar buttons")
		return

	for item in items:
		if item == null:
			continue
		var button = _guitar_button_scene.instantiate() as GuitarButton
		button.timestamp = item.timestamp
		button.pos_x = item.pos_x
		button.material = item.material
		button.track_speed = track_speed
		button.add_to_group(_SPAWNED_GROUP)
		track.add_child(button)

func _spawn_guitar_sliders(items: Array[GuitarSliderData]) -> void:
	if track == null:
		push_warning("FileReader: track not set, cannot spawn guitar sliders")
		return

	for item in items:
		if item == null:
			continue
		var slider = _guitar_slider_scene.instantiate() as GuitarSlider
		slider.progress = item.timestamp * track_speed
		slider.add_to_group(_SPAWNED_GROUP)
		track.add_child(slider)

func _spawn_shape_buttons(items: Array[ShapeButtonData]) -> void:
	if shape_root == null:
		push_warning("FileReader: shape_root not set, cannot spawn shape buttons")
		return

	for item in items:
		if item == null:
			continue
		var shape_button = _shape_button_scene.instantiate() as ShapesButton
		shape_button.timestamp = item.timestamp
		shape_button.time_delta = item.time_delta
		shape_button.add_to_group(_SPAWNED_GROUP)
		shape_root.add_child(shape_button)

func _spawn_switchs(items: Array[SwitchData]) -> void:
	for item in items:
		if item == null:
			continue
		var switch_node = _switch_scene.instantiate() as Switch
		switch_node.wait_time = max(0.001, item.timestamp)
		switch_node.switch_to = item.switch_to
		switch_node.timeout.connect(_on_switch_timeout.bind(switch_node.switch_to))
		switch_node.add_to_group(_SPAWNED_GROUP)
		add_child(switch_node)
		_switch_nodes.append(switch_node)

func _on_switch_timeout(switch_to: int) -> void:
	Globals.switch_mode(switch_to)

func _clear_spawned_nodes() -> void:
	for node in get_tree().get_nodes_in_group(_SPAWNED_GROUP):
		if is_instance_valid(node):
			node.queue_free()
