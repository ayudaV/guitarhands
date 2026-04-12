class_name FileWriter extends Node
enum RecordMode {
	KEEP,
	APPEND,
	OVERWRITE
}
@export var music : AudioStreamPlayer
@export var track_name : String
@export var track_title : String
@export_file("*.wav") var source_music_path : String
@export var record_mode: RecordMode = RecordMode.APPEND
@export var bpm := 120
@export var speed_multiplier := 1.0
@export var use_beat_snap := true
@export_range(1, 32, 1) var beat_snap_divisor := 4
@export var track_follower : TrackFollower
@export var current_mode : Globals.Mode

var track_speed := 0.0

@onready var blue_button   : Material = preload("res://resources/materials/blue_button.tres")
@onready var green_button  : Material = preload("res://resources/materials/green_button.tres")
@onready var orange_button : Material = preload("res://resources/materials/orange_button.tres")
@onready var red_button    : Material = preload("res://resources/materials/red_button.tres")
@onready var yellow_button : Material = preload("res://resources/materials/yellow_button.tres")
@onready var purple_button : Material = preload("res://resources/materials/purple_button.tres")

var new_guitar_buttons: Array[GuitarButtonData] = []
var new_spaceship_paths: Array[Dictionary] = []
var new_guitar_sliders: Array[GuitarSliderData] = []
var new_shape_buttons: Array[ShapeButtonData] = []
var new_switchs: Array[SwitchData] = []

var guitar_buttons : Array[GuitarButtonData] = []
var spaceship_paths : Array[Dictionary] = []
var guitar_sliders: Array[GuitarSliderData] = []
var shape_buttons: Array[ShapeButtonData] = []
var switchs: Array[SwitchData] = []

var timer := 0.0
var _main_shape_slide_start_time := -1.0
var _secondary_shape_slide_start_time := -1.0
var _spaceship_button_placing := false
var _spaceship_path_start_time := -1.0
var _spaceship_path_start_x := 0.0

# Guitar slider tracking per lane
var _guitar_slide_start_times := {
	"MRTrack": -1.0,
	"RTrack": -1.0,
	"MainTrack": -1.0,
	"LTrack": -1.0,
	"MLTrack": -1.0,
}
var _guitar_slide_start_raw_times := {
	"MRTrack": -1.0,
	"RTrack": -1.0,
	"MainTrack": -1.0,
	"LTrack": -1.0,
	"MLTrack": -1.0,
}

const _TRACKS_DIR := "user://tracks"
const _DATA_FILE_NAME := "data.json"
const _LEGACY_DATA_FILE_NAME := "game_data.json"
const _MUSIC_FILE_NAME := "music.wav"
const _SHAPE_MIN_DURATION := 0.05
const _SHAPE_FOCUS_DURATION := 0.8
const _SPACESHIP_BUTTONS_PER_BEAT := 2.0
const _TIME_EPSILON := 0.000001
# Default shape paths
const _SHAPE_PATH_MAIN := [[960.0 - 300.0, 540.0 - 100.0], [960.0 + 300.0, 540.0 - 100.0]]
const _SHAPE_PATH_SECONDARY := [[960.0 + 300.0, 540.0 + 100.0], [960.0 - 300.0, 540.0 + 100.0]]

func _ready() -> void:
	_prepare_track_storage()
	if record_mode == RecordMode.APPEND:
		_load_existing_track_for_append()
	_sync_music_stream()
	_sync_track_speed()

func prepare_track() -> void:
	_prepare_track_storage()
	_sync_music_stream()
	_sync_track_speed()

func save_track() -> void:
	_save()

func discard_unsaved_changes() -> void:
	new_guitar_buttons.clear()
	new_spaceship_paths.clear()
	new_guitar_sliders.clear()
	new_shape_buttons.clear()
	new_switchs.clear()
	_main_shape_slide_start_time = -1.0
	_secondary_shape_slide_start_time = -1.0
	_spaceship_button_placing = false
	_spaceship_path_start_time = -1.0
	_spaceship_path_start_x = 0.0
	# Reset all guitar slider start times
	for key in _guitar_slide_start_times:
		_guitar_slide_start_times[key] = -1.0
	for key in _guitar_slide_start_raw_times:
		_guitar_slide_start_raw_times[key] = -1.0

func import_track_data(data: Dictionary) -> void:
	track_name = String(data.get("track_name", track_name)).strip_edges()
	track_title = String(data.get("title", track_title)).strip_edges()
	bpm = max(1, _to_int(data.get("bpm", bpm)))
	speed_multiplier = _to_float(data.get("speed_multiplier", speed_multiplier))
	source_music_path = String(data.get("music_path", source_music_path)).strip_edges()
	guitar_buttons = _deserialize_guitar_buttons(data.get("guitar_buttons", []))
	spaceship_paths = _deserialize_spaceship_paths(data.get("spaceship_paths", []), data.get("spaceship_buttons", []))
	guitar_sliders = _deserialize_guitar_sliders(data.get("guitar_sliders", []))
	shape_buttons = _deserialize_shape_buttons(data.get("shape_buttons", []))
	switchs = _deserialize_switches(data.get("switchs", []))
	use_beat_snap = bool(data.get("use_beat_snap", use_beat_snap))
	beat_snap_divisor = max(1, _to_int(data.get("beat_snap_divisor", beat_snap_divisor)))
	new_guitar_buttons.clear()
	new_spaceship_paths.clear()
	new_guitar_sliders.clear()
	new_shape_buttons.clear()
	new_switchs.clear()
	_sync_track_speed()
	_prepare_track_storage()
	_sync_music_stream()

func _prepare_track_storage() -> void:
	if track_name.is_empty():
		return

	if track_title.is_empty():
		track_title = track_name

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_get_track_dir()))
	var music_path := _ensure_local_music_copy()
	if not FileAccess.file_exists(_get_save_loc()):
		_write_initial_data_file(music_path)

func _sync_music_stream() -> void:
	var local_music_path := _get_music_loc()
	if FileAccess.file_exists(local_music_path):
		var loaded_local_music := _load_audio_stream(local_music_path)
		if loaded_local_music != null:
			music.stream = loaded_local_music
			return

	var fallback_music_path := _normalize_music_source_path(source_music_path)
	if fallback_music_path.is_empty():
		return

	var loaded_fallback_music := _load_audio_stream(fallback_music_path)
	if loaded_fallback_music != null:
		music.stream = loaded_fallback_music

func _sync_track_speed() -> void:
	track_speed = float(bpm) / 60.0 * float(speed_multiplier)

func _get_seconds_per_beat() -> float:
	return 60.0 / max(float(bpm), 0.001)

func _seconds_to_beats(seconds: float) -> float:
	return seconds / _get_seconds_per_beat()

func _beats_to_seconds(beats: float) -> float:
	return beats * _get_seconds_per_beat()

func _snap_time_seconds(seconds: float) -> float:
	if not use_beat_snap:
		return snapped(seconds, 0.001)
	var divisor = max(1, beat_snap_divisor)
	var beat_step := 1.0 / float(divisor)
	var snapped_beats = snapped(_seconds_to_beats(seconds), beat_step)
	return _beats_to_seconds(snapped_beats)

func _get_track_dir() -> String:
	return "%s/%s" % [_TRACKS_DIR, track_name]

func _get_save_loc() -> String:
	return "%s/%s/%s" % [_TRACKS_DIR, track_name, _DATA_FILE_NAME]

func _get_legacy_save_loc() -> String:
	return "%s/%s/%s" % [_TRACKS_DIR, track_name, _LEGACY_DATA_FILE_NAME]

func _get_music_loc() -> String:
	return "%s/%s/%s" % [_TRACKS_DIR, track_name, _MUSIC_FILE_NAME]

func _normalize_music_source_path(path: String) -> String:
	return path.strip_edges()

func _ensure_local_music_copy() -> String:
	var destination_path := _get_music_loc()
	if FileAccess.file_exists(destination_path):
		return destination_path

	var source_path := _normalize_music_source_path(source_music_path)
	if source_path.is_empty():
		return ""
	if not FileAccess.file_exists(source_path):
		push_warning("FileWriter: source music file not found at %s" % source_path)
		return ""

	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		push_warning("FileWriter: failed to open source music file at %s" % source_path)
		return ""

	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		source_file.close()
		push_warning("FileWriter: failed to create copied music file at %s" % destination_path)
		return ""

	destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	source_file.close()
	destination_file.close()
	return destination_path

func _write_initial_data_file(music_path: String) -> void:
	var file := FileAccess.open(_get_save_loc(), FileAccess.WRITE)
	if file == null:
		push_warning("FileWriter: failed to create save file at %s" % _get_save_loc())
		return

	file.store_string(JSON.stringify(_build_save_payload([], [], [], [], [], music_path), "\t"))
	file.close()

func _process(delta: float) -> void:
	timer = music.get_playback_position()
	var snapped_time = _snap_time_seconds(timer)

	if Input.is_action_just_pressed("SpaceshipBPlace") and Globals.current_mode == Globals.Mode.SPACESHIP and _is_music_advancing():
		if _spaceship_button_placing:
			_stop_spaceship_button_placement(snapped_time)
		else:
			_start_spaceship_button_placement(snapped_time)

	if _spaceship_button_placing and Globals.current_mode != Globals.Mode.SPACESHIP:
		_stop_spaceship_button_placement(snapped_time)
	
	# Handle guitar lanes: click = button, hold >= 1 beat = slider.
	_handle_guitar_slider_input("MRTrack", 2, orange_button, timer, snapped_time)
	_handle_guitar_slider_input("RTrack", 1, blue_button, timer, snapped_time)
	_handle_guitar_slider_input("MainTrack", 0, yellow_button, timer, snapped_time)
	_handle_guitar_slider_input("LTrack", -1, red_button, timer, snapped_time)
	_handle_guitar_slider_input("MLTrack", -2, green_button, timer, snapped_time)
		
	if Input.is_action_just_pressed("Guitar"):
		new_switchs.append(_new_switch_data(snapped_time, Globals.Mode.GUITAR))
		Globals.switch_mode(Globals.Mode.GUITAR)
		current_mode = Globals.Mode.GUITAR
	if Input.is_action_just_pressed("Spaceship"):
		new_switchs.append(_new_switch_data(snapped_time, Globals.Mode.SPACESHIP))
		Globals.switch_mode(Globals.Mode.SPACESHIP)
	if Input.is_action_just_pressed("Shapes"):
		new_switchs.append(_new_switch_data(snapped_time, Globals.Mode.SHAPES))
		Globals.switch_mode(Globals.Mode.SHAPES)

	if Input.is_action_pressed("MainShapeSlide"):
		if _main_shape_slide_start_time < 0.0:
			_main_shape_slide_start_time = snapped_time
	if Input.is_action_just_released("MainShapeSlide"):
		var main_end = snapped_time
		var main_start = _main_shape_slide_start_time if _main_shape_slide_start_time >= 0.0 else snapped_time
		var main_duration = max(0.0, main_end - main_start)
		new_shape_buttons.append(_new_shape_button_data(main_start, main_duration, _SHAPE_PATH_MAIN))
		_main_shape_slide_start_time = -1.0
	if Input.is_action_pressed("SecondaryShapeSlide"):
		if _secondary_shape_slide_start_time < 0.0:
			_secondary_shape_slide_start_time = snapped_time
	if Input.is_action_just_released("SecondaryShapeSlide"):
		var secondary_end = snapped_time
		var secondary_start = _secondary_shape_slide_start_time if _secondary_shape_slide_start_time >= 0.0 else snapped_time
		var secondary_duration = max(0.0, secondary_end - secondary_start)
		new_shape_buttons.append(_new_shape_button_data(secondary_start, secondary_duration, _SHAPE_PATH_SECONDARY))
		_secondary_shape_slide_start_time = -1.0
		
	if Input.is_action_just_pressed("Quit"):
		if _spaceship_button_placing:
			_stop_spaceship_button_placement(snapped_time)
		_save()

func _start_spaceship_button_placement(current_time: float) -> void:
	if Globals.current_mode != Globals.Mode.SPACESHIP:
		return
	if not _is_music_advancing():
		return

	_spaceship_button_placing = true
	_spaceship_path_start_time = current_time
	_spaceship_path_start_x = _get_current_spaceship_x()

func _stop_spaceship_button_placement(current_time: float) -> void:
	if not _spaceship_button_placing:
		return
	_spaceship_button_placing = false
	var start_time := _spaceship_path_start_time if _spaceship_path_start_time >= 0.0 else current_time
	var end_time = max(start_time, current_time)
	new_spaceship_paths.append(_new_spaceship_path_data(start_time, end_time, _spaceship_path_start_x, _get_current_spaceship_x()))
	_spaceship_path_start_time = -1.0
	_spaceship_path_start_x = 0.0

func _handle_guitar_slider_input(action_name: String, pos_x: float, material: Material, raw_time: float, snapped_time: float) -> void:
	"""Short hold -> button, hold >= 1 beat -> slider."""
	var key = action_name
	
	# On press, record the start time
	if Input.is_action_just_pressed(action_name):
		if _guitar_slide_start_times[key] < 0.0:
			_guitar_slide_start_times[key] = snapped_time
			_guitar_slide_start_raw_times[key] = raw_time
	
	# On release, decide between button and slider.
	if Input.is_action_just_released(action_name):
		if _guitar_slide_start_times[key] >= 0.0:
			var start_time = _guitar_slide_start_times[key]
			var raw_start_time = _guitar_slide_start_raw_times[key]
			var end_time = snapped_time
			var held_seconds = max(0.0, raw_time - raw_start_time)
			var held_beats = _seconds_to_beats(held_seconds)
			if held_beats >= 1.0:
				new_guitar_sliders.append(_new_guitar_slider_data(start_time, end_time, pos_x, pos_x))
			else:
				new_guitar_buttons.append(_new_guitar_button_data(start_time, pos_x, material))
			_guitar_slide_start_times[key] = -1.0
			_guitar_slide_start_raw_times[key] = -1.0

func _get_current_spaceship_x() -> float:
	if track_follower == null or track_follower.spaceship == null:
		return 0.0
	return clampf(track_follower.spaceship.position.x, -2.0, 2.0)

func _get_spaceship_buttons_per_beat() -> float:
	return max(1.0, _SPACESHIP_BUTTONS_PER_BEAT)

func _is_music_advancing() -> bool:
	return music.playing and not music.stream_paused
		
func _save():
	print("saving file")
	_sync_track_speed()

	if record_mode == RecordMode.KEEP:
		return
	if record_mode == RecordMode.APPEND:
		guitar_buttons += new_guitar_buttons
		spaceship_paths += new_spaceship_paths
		guitar_sliders += new_guitar_sliders
		shape_buttons += new_shape_buttons
		switchs += new_switchs
		
		guitar_buttons.sort_custom(func(a: GuitarButtonData, b: GuitarButtonData): return a.timestamp < b.timestamp)
		spaceship_paths.sort_custom(func(a: Dictionary, b: Dictionary): return _to_float(a.get("beat", 0.0)) < _to_float(b.get("beat", 0.0)))
		guitar_sliders.sort_custom(func(a: GuitarSliderData, b: GuitarSliderData): return a.timestamp < b.timestamp)
		shape_buttons.sort_custom(func(a: ShapeButtonData, b: ShapeButtonData): return a.timestamp < b.timestamp)
		switchs.sort_custom(func(a: SwitchData, b: SwitchData): return a.timestamp < b.timestamp)

	
	elif  record_mode == RecordMode.OVERWRITE:
		guitar_buttons = new_guitar_buttons.duplicate()
		spaceship_paths = new_spaceship_paths.duplicate(true)
		guitar_sliders = new_guitar_sliders.duplicate()
		shape_buttons = new_shape_buttons.duplicate()
		switchs = new_switchs.duplicate()

	_prepare_track_storage()
	var data := _build_save_payload(guitar_buttons, spaceship_paths, guitar_sliders, shape_buttons, switchs)
	var file := FileAccess.open(_get_save_loc(), FileAccess.WRITE)
	if file == null:
		push_warning("FileWriter: failed to open save path %s" % _get_save_loc())
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	discard_unsaved_changes()
	print("Game Saved!")
		



func _on_music_finished() -> void:
	_save()

func _new_guitar_button_data(timestamp: float, pos_x: float, material: Material) -> GuitarButtonData:
	var data := GuitarButtonData.new()
	data.timestamp = timestamp
	data.pos_x = pos_x
	data.material = material
	return data

func _new_guitar_slider_data(start_timestamp: float, end_timestamp: float, start_x: float, end_x: float) -> GuitarSliderData:
	var data := GuitarSliderData.new()
	data.timestamp = start_timestamp
	data.start_x = start_x
	data.end_x = end_x
	data.time_delta = max(0.05, end_timestamp - start_timestamp)
	return data

func _new_spaceship_path_data(start_timestamp: float, end_timestamp: float, start_x: float, end_x: float) -> Dictionary:
	var duration_seconds = max(0.0, end_timestamp - start_timestamp)
	var duration_beats := _seconds_to_beats(duration_seconds)
	var subdivides = max(1, int(round(duration_beats * _get_spaceship_buttons_per_beat())))
	if duration_seconds > _TIME_EPSILON:
		subdivides = max(2, subdivides)
	var clamped_start_x := clampf(start_x, -2.0, 2.0)
	var clamped_end_x := clampf(end_x, -2.0, 2.0)
	var travel := absf(clamped_end_x - clamped_start_x)
	var arc_strength := clampf(0.08 + travel * 0.18, 0.05, 0.45)
	var arc_direction := -signf(clamped_end_x - clamped_start_x)
	if is_zero_approx(arc_direction):
		arc_direction = 1.0 if int(floor(start_timestamp * 10.0)) % 2 == 0 else -1.0

	return {
		"beat": _seconds_to_beats(start_timestamp),
		"duration_beats": duration_beats,
		"start_x": clamped_start_x,
		"end_x": clamped_end_x,
		"subdivides": subdivides,
		"arc_direction": arc_direction,
		"arc_strength": arc_strength,
		"material_path": purple_button.resource_path,
	}

func _new_shape_button_data(timestamp: float, time_delta: float, path_points: Array) -> ShapeButtonData:
	var data := ShapeButtonData.new()
	data.timestamp = timestamp
	data.spawn_timestamp = max(0.0, timestamp - _SHAPE_FOCUS_DURATION)
	data.time_delta = max(_SHAPE_MIN_DURATION, time_delta)
	data.path_points = path_points
	return data

func _new_switch_data(timestamp: float, switch_to: int) -> SwitchData:
	var data := SwitchData.new()
	data.timestamp = timestamp
	data.switch_to = switch_to
	return data

func _build_save_payload(
	items_guitar_buttons: Array[GuitarButtonData],
	items_spaceship_paths: Array[Dictionary],
	items_guitar_sliders: Array[GuitarSliderData],
	items_shape_buttons: Array[ShapeButtonData],
	items_switchs: Array[SwitchData],
	music_path_override: String = ""
) -> Dictionary:
	var music_path := music_path_override
	if music_path.is_empty():
		music_path = _get_music_loc()
	if music_path.is_empty() and music.stream != null:
		music_path = music.stream.resource_path
	if music_path.is_empty():
		music_path = _normalize_music_source_path(source_music_path)

	return {
		"format_version": 2,
		"track_name": track_name,
		"title": track_title,
		"music_path": music_path,
		"bpm": float(bpm),
		"speed_multiplier": float(speed_multiplier),
		"timing_unit": "beats",
		"use_beat_snap": use_beat_snap,
		"beat_snap_divisor": beat_snap_divisor,
		"track_speed": float(track_speed),
		"guitar_buttons": _serialize_guitar_buttons(items_guitar_buttons),
		"spaceship_buttons": [],
		"spaceship_paths": _serialize_spaceship_paths(items_spaceship_paths),
		"guitar_sliders": _serialize_guitar_sliders(items_guitar_sliders),
		"shape_buttons": _serialize_shape_buttons(items_shape_buttons),
		"switchs": _serialize_switches(items_switchs),
	}

func _serialize_spaceship_paths(items: Array[Dictionary]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item.is_empty():
			continue
		serialized.append({
			"beat": _to_float(item.get("beat", 0.0)),
			"duration_beats": max(0.0, _to_float(item.get("duration_beats", 0.0))),
			"start_x": clampf(_to_float(item.get("start_x", 0.0)), -2.0, 2.0),
			"end_x": clampf(_to_float(item.get("end_x", 0.0)), -2.0, 2.0),
			"subdivides": max(1, _to_int(item.get("subdivides", 1))),
			"arc_direction": _to_float(item.get("arc_direction", 1.0)),
			"arc_strength": clampf(_to_float(item.get("arc_strength", 0.12)), 0.0, 1.0),
			"material_path": String(item.get("material_path", "")),
		})
	return serialized

func _serialize_guitar_buttons(items: Array[GuitarButtonData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		var material_path := ""
		if item.material != null:
			material_path = item.material.resource_path
		serialized.append({
			"beat": _seconds_to_beats(item.timestamp),
			"pos_x": item.pos_x,
			"material_path": material_path,
		})
	return serialized

func _serialize_guitar_sliders(items: Array[GuitarSliderData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		serialized.append({
			"beat": _seconds_to_beats(item.timestamp),
			"start_x": item.start_x,
			"end_x": item.end_x,
			"duration_beats": _seconds_to_beats(item.time_delta),
		})
	return serialized

func _serialize_shape_buttons(items: Array[ShapeButtonData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		serialized.append({
			"spawn_beat": _seconds_to_beats(item.spawn_timestamp),
			"beat": _seconds_to_beats(item.timestamp),
			"duration_beats": _seconds_to_beats(item.time_delta),
			"path_points": item.path_points,
		})
	return serialized

func _serialize_switches(items: Array[SwitchData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		serialized.append({
			"beat": _seconds_to_beats(item.timestamp),
			"switch_to": item.switch_to,
		})
	return serialized

func _dict_time_to_seconds(item_dict: Dictionary, beat_key: String, seconds_key: String = "timestamp") -> float:
	if item_dict.has(beat_key):
		return _beats_to_seconds(_to_float(item_dict.get(beat_key, 0.0)))
	return _to_float(item_dict.get(seconds_key, 0.0))

func _dict_duration_to_seconds(item_dict: Dictionary, beat_key: String, seconds_key: String = "time_delta") -> float:
	if item_dict.has(beat_key):
		return _beats_to_seconds(_to_float(item_dict.get(beat_key, 0.0)))
	return _to_float(item_dict.get(seconds_key, 0.0))

func _load_existing_track_for_append() -> void:
	var save_path := _get_save_loc()
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(_get_legacy_save_loc()):
		save_path = _get_legacy_save_loc()

	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("FileWriter: failed to open save file at %s" % save_path)
		return

	var parse := JSON.new()
	var parse_result := parse.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not (parse.data is Dictionary):
		push_warning("FileWriter: invalid JSON in %s" % save_path)
		return

	import_track_data(parse.data)

func _load_audio_stream(path: String) -> AudioStream:
	var normalized_path := _normalize_music_source_path(path)
	if normalized_path.is_empty():
		return null

	var extension := normalized_path.get_extension().to_lower()
	if extension == "wav" and FileAccess.file_exists(normalized_path):
		return AudioStreamWAV.load_from_file(normalized_path)

	var loaded_resource := load(normalized_path)
	if loaded_resource is AudioStream:
		return loaded_resource as AudioStream

	return null

func _deserialize_guitar_buttons(raw_items: Variant) -> Array[GuitarButtonData]:
	var items: Array[GuitarButtonData] = []
	if not (raw_items is Array):
		return items

	for raw_item in raw_items:
		if not (raw_item is Dictionary):
			continue
		var item_dict: Dictionary = raw_item
		var data := GuitarButtonData.new()
		data.timestamp = _dict_time_to_seconds(item_dict, "beat", "timestamp")
		data.pos_x = _to_float(item_dict.get("pos_x", 0.0))
		var material_path := String(item_dict.get("material_path", ""))
		if not material_path.is_empty():
			var loaded_material := load(material_path)
			if loaded_material is Material:
				data.material = loaded_material as Material
		items.append(data)

	return items

func _deserialize_guitar_sliders(raw_items: Variant) -> Array[GuitarSliderData]:
	var items: Array[GuitarSliderData] = []
	if not (raw_items is Array):
		return items

	for raw_item in raw_items:
		if not (raw_item is Dictionary):
			continue
		var item_dict: Dictionary = raw_item
		var data := GuitarSliderData.new()
		data.timestamp = _dict_time_to_seconds(item_dict, "beat", "timestamp")
		data.start_x = _to_float(item_dict.get("start_x", 0.0))
		data.end_x = _to_float(item_dict.get("end_x", data.start_x))
		data.time_delta = max(0.05, _dict_duration_to_seconds(item_dict, "duration_beats", "time_delta"))
		items.append(data)

	return items

func _deserialize_spaceship_paths(raw_paths: Variant, raw_legacy_buttons: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if raw_paths is Array:
		for raw_item in raw_paths:
			if not (raw_item is Dictionary):
				continue
			var item_dict: Dictionary = raw_item
			items.append({
				"beat": _to_float(item_dict.get("beat", 0.0)),
				"duration_beats": max(0.0, _to_float(item_dict.get("duration_beats", 0.0))),
				"start_x": clampf(_to_float(item_dict.get("start_x", 0.0)), -2.0, 2.0),
				"end_x": clampf(_to_float(item_dict.get("end_x", item_dict.get("start_x", 0.0))), -2.0, 2.0),
				"subdivides": max(1, _to_int(item_dict.get("subdivides", 1))),
				"arc_direction": _to_float(item_dict.get("arc_direction", 1.0)),
				"arc_strength": clampf(_to_float(item_dict.get("arc_strength", 0.12)), 0.0, 1.0),
				"material_path": String(item_dict.get("material_path", purple_button.resource_path)),
			})

	if not items.is_empty():
		return items

	# Legacy conversion: each button becomes a one-point path segment.
	if raw_legacy_buttons is Array:
		for raw_item in raw_legacy_buttons:
			if not (raw_item is Dictionary):
				continue
			var item_dict: Dictionary = raw_item
			var beat := _to_float(item_dict.get("beat", _seconds_to_beats(_to_float(item_dict.get("timestamp", 0.0)))))
			var pos_x := clampf(_to_float(item_dict.get("pos_x", 0.0)), -2.0, 2.0)
			items.append({
				"beat": beat,
				"duration_beats": 0.0,
				"start_x": pos_x,
				"end_x": pos_x,
				"subdivides": 1,
				"arc_direction": 1.0,
				"arc_strength": 0.0,
				"material_path": String(item_dict.get("material_path", purple_button.resource_path)),
			})

	return items

func _deserialize_shape_buttons(raw_items: Variant) -> Array[ShapeButtonData]:
	var items: Array[ShapeButtonData] = []
	if not (raw_items is Array):
		return items

	for raw_item in raw_items:
		if not (raw_item is Dictionary):
			continue
		var item_dict: Dictionary = raw_item
		var data := ShapeButtonData.new()
		data.timestamp = _dict_time_to_seconds(item_dict, "beat", "timestamp")
		if item_dict.has("spawn_beat"):
			data.spawn_timestamp = _beats_to_seconds(_to_float(item_dict.get("spawn_beat", 0.0)))
		else:
			data.spawn_timestamp = _to_float(item_dict.get("spawn_timestamp", data.timestamp - _SHAPE_FOCUS_DURATION))
		data.time_delta = max(_SHAPE_MIN_DURATION, _dict_duration_to_seconds(item_dict, "duration_beats", "time_delta"))
		# Handle old lane-based data for backward compatibility
		var raw_path = item_dict.get("path_points")
		if raw_path is Array:
			data.path_points = raw_path
		else:
			# Fall back to default paths if lane data exists
			var lane = _to_int(item_dict.get("lane", 0))
			data.path_points = _SHAPE_PATH_MAIN if lane == 0 else _SHAPE_PATH_SECONDARY
		items.append(data)

	return items

func _deserialize_switches(raw_items: Variant) -> Array[SwitchData]:
	var items: Array[SwitchData] = []
	if not (raw_items is Array):
		return items

	for raw_item in raw_items:
		if not (raw_item is Dictionary):
			continue
		var item_dict: Dictionary = raw_item
		var data := SwitchData.new()
		data.timestamp = _dict_time_to_seconds(item_dict, "beat", "timestamp")
		data.switch_to = _to_int(item_dict.get("switch_to", 0))
		items.append(data)

	return items

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
