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
@export var track_follower : TrackFollower
@export var current_mode : Globals.Mode

@onready var blue_button   : Material = preload("res://resources/materials/blue_button.tres")
@onready var green_button  : Material = preload("res://resources/materials/green_button.tres")
@onready var orange_button : Material = preload("res://resources/materials/orange_button.tres")
@onready var red_button    : Material = preload("res://resources/materials/red_button.tres")
@onready var yellow_button : Material = preload("res://resources/materials/yellow_button.tres")
@onready var purple_button : Material = preload("res://resources/materials/purple_button.tres")

var save_loc : String = "user://tracks/" + track_name + "/game_data.json"

var new_guitar_buttons: Array[GuitarButtonData] = []
var new_guitar_sliders: Array[GuitarSliderData] = []
var new_shape_buttons: Array[ShapeButtonData] = []
var new_switchs: Array[SwitchData] = []

var guitar_buttons : Array[GuitarButtonData] = []
var guitar_sliders: Array[GuitarSliderData] = []
var shape_buttons: Array[ShapeButtonData] = []
var switchs: Array[SwitchData] = []

var timer := 0.0
var main_shape_slide_delta := 0.0
var secondary_shape_slide_delta := 0.0

const _TRACKS_DIR := "user://tracks"
const _DATA_FILE_NAME := "data.json"
const _LEGACY_DATA_FILE_NAME := "game_data.json"
const _MUSIC_FILE_NAME := "music.wav"

func _ready() -> void:
	_prepare_track_storage()
	if record_mode == RecordMode.APPEND:
		_load_existing_track_for_append()
	_sync_music_stream()

func prepare_track() -> void:
	_prepare_track_storage()
	_sync_music_stream()

func configure_new_track(new_track_name: String, new_track_title: String, new_bpm: int, new_speed_multiplier: float, new_music_source_path: String) -> void:
	track_name = new_track_name.strip_edges()
	track_title = new_track_title.strip_edges()
	bpm = max(1, new_bpm)
	speed_multiplier = new_speed_multiplier
	source_music_path = new_music_source_path.strip_edges()
	new_guitar_buttons.clear()
	new_guitar_sliders.clear()
	new_shape_buttons.clear()
	new_switchs.clear()
	guitar_buttons.clear()
	guitar_sliders.clear()
	shape_buttons.clear()
	switchs.clear()
	_prepare_track_storage()
	_sync_music_stream()

func load_existing_track(new_track_name: String) -> bool:
	track_name = new_track_name.strip_edges()
	if track_name.is_empty():
		return false

	var save_path := _get_save_loc()
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(_get_legacy_save_loc()):
		save_path = _get_legacy_save_loc()
	if not FileAccess.file_exists(save_path):
		return false

	new_guitar_buttons.clear()
	new_guitar_sliders.clear()
	new_shape_buttons.clear()
	new_switchs.clear()
	_load_existing_track_for_append()
	_sync_music_stream()
	return FileAccess.file_exists(_get_save_loc()) or FileAccess.file_exists(_get_legacy_save_loc())

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
	if music == null:
		return

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

	file.store_string(JSON.stringify(_build_save_payload([], [], [], [], music_path), "\t"))
	file.close()

func _process(delta: float) -> void:
	if music == null:
		return
	timer = music.get_playback_position()
	var snapped_time = snapped(timer, 0.01)
	
	if Input.is_action_just_pressed("MRTrack"):
		new_guitar_buttons.append(_new_guitar_button_data(snapped_time, 2, orange_button))
	if Input.is_action_just_pressed("RTrack"):
		new_guitar_buttons.append(_new_guitar_button_data(snapped_time, 1, blue_button))
	if Input.is_action_just_pressed("MainTrack"):
		new_guitar_buttons.append(_new_guitar_button_data(snapped_time, 0, yellow_button))
	if Input.is_action_just_pressed("LTrack"):
		new_guitar_buttons.append(_new_guitar_button_data(snapped_time, -1, red_button))
	if Input.is_action_just_pressed("MLTrack"):
		new_guitar_buttons.append(_new_guitar_button_data(snapped_time, -2, green_button))
		
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
		main_shape_slide_delta += delta
	if Input.is_action_just_released("MainShapeSlide"):
		new_shape_buttons.append(_new_shape_button_data(snapped_time, main_shape_slide_delta))
		main_shape_slide_delta = 0.0
	if Input.is_action_pressed("SecondaryShapeSlide"):
		secondary_shape_slide_delta += delta
	if Input.is_action_just_released("SecondaryShapeSlide"):
		new_shape_buttons.append(_new_shape_button_data(snapped_time, secondary_shape_slide_delta))
		secondary_shape_slide_delta = 0.0
		
	if Globals.current_mode == Globals.Mode.SPACESHIP and int(snapped_time*60*8) % bpm == 0:
		new_guitar_buttons.append(_new_guitar_button_data(snapped_time, track_follower.get_node("Spaceship").position.x, purple_button))

	if Input.is_action_just_pressed("Quit"):
		_save()
		
func _save():
	print("saving file")

	if record_mode == RecordMode.KEEP:
		return
	if record_mode == RecordMode.APPEND:
		guitar_buttons += new_guitar_buttons
		guitar_sliders += new_guitar_sliders
		shape_buttons += new_shape_buttons
		switchs += new_switchs
		
		guitar_buttons.sort_custom(func(a: GuitarButtonData, b: GuitarButtonData): return a.timestamp < b.timestamp)
		guitar_sliders.sort_custom(func(a: GuitarSliderData, b: GuitarSliderData): return a.timestamp < b.timestamp)
		shape_buttons.sort_custom(func(a: ShapeButtonData, b: ShapeButtonData): return a.timestamp < b.timestamp)
		switchs.sort_custom(func(a: SwitchData, b: SwitchData): return a.timestamp < b.timestamp)

	
	elif  record_mode == RecordMode.OVERWRITE:
		guitar_buttons = new_guitar_buttons
		guitar_sliders = new_guitar_sliders
		shape_buttons = new_shape_buttons
		switchs = new_switchs

	_prepare_track_storage()
	var data := _build_save_payload(guitar_buttons, guitar_sliders, shape_buttons, switchs)
	var file := FileAccess.open(_get_save_loc(), FileAccess.WRITE)
	if file == null:
		push_warning("FileWriter: failed to open save path %s" % _get_save_loc())
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var result := OK
	print(result)
	if result == OK:
		print("Game Saved!")
		



func _on_music_finished() -> void:
	_save()

func _new_guitar_button_data(timestamp: float, pos_x: float, material: Material) -> GuitarButtonData:
	var data := GuitarButtonData.new()
	data.timestamp = timestamp
	data.pos_x = pos_x
	data.material = material
	return data

func _new_shape_button_data(timestamp: float, time_delta: float) -> ShapeButtonData:
	var data := ShapeButtonData.new()
	data.timestamp = timestamp
	data.time_delta = time_delta
	return data

func _new_switch_data(timestamp: float, switch_to: int) -> SwitchData:
	var data := SwitchData.new()
	data.timestamp = timestamp
	data.switch_to = switch_to
	return data

func _build_save_payload(
	items_guitar_buttons: Array[GuitarButtonData],
	items_guitar_sliders: Array[GuitarSliderData],
	items_shape_buttons: Array[ShapeButtonData],
	items_switchs: Array[SwitchData],
	music_path_override: String = ""
) -> Dictionary:
	var music_path := music_path_override
	if music_path.is_empty():
		music_path = _get_music_loc()
	if music_path.is_empty() and music != null and music.stream != null:
		music_path = music.stream.resource_path
	if music_path.is_empty():
		music_path = _normalize_music_source_path(source_music_path)

	return {
		"format_version": 1,
		"track_name": track_name,
		"title": track_title,
		"music_path": music_path,
		"bpm": float(bpm),
		"speed_multiplier": float(speed_multiplier),
		"guitar_buttons": _serialize_guitar_buttons(items_guitar_buttons),
		"guitar_sliders": _serialize_guitar_sliders(items_guitar_sliders),
		"shape_buttons": _serialize_shape_buttons(items_shape_buttons),
		"switchs": _serialize_switches(items_switchs),
	}

func _serialize_guitar_buttons(items: Array[GuitarButtonData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		var material_path := ""
		if item.material != null:
			material_path = item.material.resource_path
		serialized.append({
			"timestamp": item.timestamp,
			"pos_x": item.pos_x,
			"material_path": material_path,
		})
	return serialized

func _serialize_guitar_sliders(items: Array[GuitarSliderData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		serialized.append({"timestamp": item.timestamp})
	return serialized

func _serialize_shape_buttons(items: Array[ShapeButtonData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		serialized.append({
			"timestamp": item.timestamp,
			"time_delta": item.time_delta,
		})
	return serialized

func _serialize_switches(items: Array[SwitchData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item in items:
		if item == null:
			continue
		serialized.append({
			"timestamp": item.timestamp,
			"switch_to": item.switch_to,
		})
	return serialized

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

	var data: Dictionary = parse.data
	track_title = String(data.get("title", track_title if not track_title.is_empty() else track_name))
	var loaded_music_path := String(data.get("music_path", ""))
	bpm = _to_int(data.get("bpm", bpm))
	speed_multiplier = _to_float(data.get("speed_multiplier", speed_multiplier))

	if music != null and not loaded_music_path.is_empty():
		var loaded_music := _load_audio_stream(loaded_music_path)
		if loaded_music != null:
			music.stream = loaded_music

	guitar_buttons = _deserialize_guitar_buttons(data.get("guitar_buttons", []))
	guitar_sliders = _deserialize_guitar_sliders(data.get("guitar_sliders", []))
	shape_buttons = _deserialize_shape_buttons(data.get("shape_buttons", []))
	switchs = _deserialize_switches(data.get("switchs", []))

	if FileAccess.file_exists(_get_music_loc()) and music != null:
		var local_music := _load_audio_stream(_get_music_loc())
		if local_music != null:
			music.stream = local_music

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
		data.timestamp = _to_float(item_dict.get("timestamp", 0.0))
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
		data.timestamp = _to_float(item_dict.get("timestamp", 0.0))
		items.append(data)

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
		data.timestamp = _to_float(item_dict.get("timestamp", 0.0))
		data.time_delta = _to_float(item_dict.get("time_delta", 0.0))
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
		data.timestamp = _to_float(item_dict.get("timestamp", 0.0))
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
