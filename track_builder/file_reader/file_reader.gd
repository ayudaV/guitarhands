class_name FileReader extends Node

@export var track_name : String
@export var track_title : String
@export var track: Path3D
@export var music: AudioStreamPlayer
@export var track_follower: TrackFollower
@export var shape_root: Node
@export var switch_root: Node
var track_speed: float = 0.0

var _guitar_button_scene: PackedScene = preload("res://models/button/Button.tscn")
var _guitar_slider_scene: PackedScene = preload("res://models/slider/slider.tscn")
var _shape_button_scene: PackedScene = preload("res://models/shape_slider/shape_slider.tscn")
var _switch_scene: PackedScene = preload("res://models/switch/Switch.tscn")
const _SPAWNED_GROUP := "loaded_track_spawned"
const _TRACKS_DIR := "user://tracks"
const _DATA_FILE_NAME := "data.json"

func _ready() -> void:
	reload_track()

func reload_track() -> void:
	_clear_spawned_nodes()
	music.stop()
	track_follower.configure_transport(track_speed, false)

	var save_loc := _get_save_loc()

	if not FileAccess.file_exists(save_loc):
		push_warning("FileReader: save file not found at %s" % save_loc)
		return

	var file := FileAccess.open(save_loc, FileAccess.READ)
	if file == null:
		push_warning("FileReader: failed to open save file at %s" % save_loc)
		return
	var parse := JSON.new()
	var parse_result := parse.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not (parse.data is Dictionary):
		push_warning("FileReader: invalid JSON in save file %s" % save_loc)
		return

	var data: Dictionary = parse.data
	track_title = String(data.get("title", track_title if not track_title.is_empty() else track_name))
	var bpm := _to_float(data.get("bpm", 120.0))
	var speed_multiplier := _to_float(data.get("speed_multiplier", 1.0))
	track_speed = _to_float(data.get("track_speed", bpm / 60.0 * speed_multiplier))

	var music_path := String(data.get("music_path", ""))
	var loaded_music := _load_audio_stream(music_path)
	music.stream = loaded_music

	track_follower.configure_transport(track_speed, false)
	_spawn_guitar_buttons(data.get("guitar_buttons", []))
	_spawn_spaceship_buttons(data.get("spaceship_buttons", []))
	_spawn_guitar_sliders(data.get("guitar_sliders", []))
	_spawn_shape_buttons(data.get("shape_buttons", []))
	_spawn_switchs(data.get("switchs", []))

func _get_save_loc() -> String:
	return "%s/%s/%s" % [_TRACKS_DIR, track_name, _DATA_FILE_NAME]

func _load_audio_stream(path: String) -> AudioStream:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return null

	if normalized_path.get_extension().to_lower() == "wav" and FileAccess.file_exists(normalized_path):
		return AudioStreamWAV.load_from_file(normalized_path)

	var loaded_resource := load(normalized_path)
	if loaded_resource is AudioStream:
		return loaded_resource as AudioStream

	return null

func _spawn_guitar_buttons(items: Array) -> void:
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict: Dictionary = item
		var button = _guitar_button_scene.instantiate() as GuitarButton
		button.timestamp = _to_float(item_dict.get("timestamp", 0.0))
		button.pos_x = _to_float(item_dict.get("pos_x", 0.0))
		var material_path := String(item_dict.get("material_path", ""))
		if not material_path.is_empty():
			var loaded_material := load(material_path)
			if loaded_material is Material:
				button.material = loaded_material as Material
		button.track_speed = track_speed
		button.add_to_group(_SPAWNED_GROUP)
		track.add_child(button)

func _spawn_spaceship_buttons(items: Array) -> void:
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict: Dictionary = item
		var button = _guitar_button_scene.instantiate() as GuitarButton
		button.timestamp = _to_float(item_dict.get("timestamp", 0.0))
		button.pos_x = _to_float(item_dict.get("pos_x", 0.0))
		var material_path := String(item_dict.get("material_path", ""))
		if not material_path.is_empty():
			var loaded_material := load(material_path)
			if loaded_material is Material:
				button.material = loaded_material as Material
		button.track_speed = track_speed
		button.add_to_group(_SPAWNED_GROUP)
		track.add_child(button)

func _spawn_guitar_sliders(items: Array) -> void:
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict: Dictionary = item
		var slider = _guitar_slider_scene.instantiate() as GuitarSlider
		slider.progress = _to_float(item_dict.get("timestamp", 0.0)) * track_speed
		slider.add_to_group(_SPAWNED_GROUP)
		track.add_child(slider)

func _spawn_shape_buttons(items: Array) -> void:
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict: Dictionary = item
		var shape_button = _shape_button_scene.instantiate() as ShapesButton
		shape_button.music = music
		shape_button.spawn_timestamp = _to_float(item_dict.get("spawn_timestamp", _to_float(item_dict.get("timestamp", 0.0)) - 0.8))
		shape_button.timestamp = _to_float(item_dict.get("timestamp", 0.0))
		shape_button.time_delta = _to_float(item_dict.get("time_delta", 0.0))
		# Convert path points array to Curve2D
		var path_curve := Curve2D.new()
		var path_points = item_dict.get("path_points", [])
		if path_points is Array:
			for point in path_points:
				if point is Array and point.size() >= 2:
					path_curve.add_point(Vector2(_to_float(point[0]), _to_float(point[1])))
		shape_button.set_path(path_curve)
		shape_button.add_to_group(_SPAWNED_GROUP)
		shape_root.add_child(shape_button)

func _spawn_switchs(items: Array) -> void:
	for item in items:
		if not (item is Dictionary):
			continue
		var item_dict: Dictionary = item
		var switch_node = _switch_scene.instantiate() as Switch
		switch_node.wait_time = max(0.001, _to_float(item_dict.get("timestamp", 0.0)))
		switch_node.switch_to = _to_int(item_dict.get("switch_to", 0))
		switch_node.timeout.connect(_on_switch_timeout.bind(switch_node.switch_to))
		switch_node.add_to_group(_SPAWNED_GROUP)
		switch_root.add_child(switch_node)

func _on_switch_timeout(switch_to: int) -> void:
	Globals.switch_mode(switch_to)

func _clear_spawned_nodes() -> void:
	for node in get_tree().get_nodes_in_group(_SPAWNED_GROUP):
		if is_instance_valid(node):
			node.queue_free()

func _to_float(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String:
		return float(value)
	return 0.0

func _to_int(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		return int(value)
	return 0
