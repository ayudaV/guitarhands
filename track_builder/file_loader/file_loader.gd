@tool
class_name FileLoader extends Node

@export var track_name : String
@export var track_title : String
@export var music_path : String
@export var bpm : float = 120.0
@export var speed_multiplier : float = 1.0
@export var use_beat_snap := true
@export var beat_snap_divisor := 4
@export var track_speed := 0.0

var track_data: Dictionary = {}

var guitar_buttons_data: Array[Dictionary] = []
var spaceship_buttons_data: Array[Dictionary] = []
var spaceship_paths_data: Array[Dictionary] = []
var guitar_sliders_data: Array[Dictionary] = []
var shape_buttons_data: Array[Dictionary] = []
var switchs_data: Array[Dictionary] = []

func load_track(new_track_name: String) -> bool:
	track_name = new_track_name.strip_edges()
	if track_name.is_empty():
		return false

	var save_loc := _get_save_loc()
	if not FileAccess.file_exists(save_loc) and FileAccess.file_exists(_get_legacy_save_loc()):
		save_loc = _get_legacy_save_loc()
	if not FileAccess.file_exists(save_loc):
		return false

	var file := FileAccess.open(save_loc, FileAccess.READ)
	if file == null:
		push_warning("FileLoader: failed to open save file at %s" % String(save_loc))
		return false

	var parse := JSON.new()
	var parse_result := parse.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not (parse.data is Dictionary):
		push_warning("FileLoader: invalid JSON in %s" % String(save_loc))
		return false

	track_data = parse.data
	var data: Dictionary = parse.data
	track_title = String(data.get("title", track_title))
	music_path = String(data.get("music_path", music_path))
	bpm = _to_float(data.get("bpm", bpm))
	speed_multiplier = _to_float(data.get("speed_multiplier", speed_multiplier))
	use_beat_snap = bool(data.get("use_beat_snap", use_beat_snap))
	beat_snap_divisor = max(1, _to_int(data.get("beat_snap_divisor", beat_snap_divisor)))
	track_speed = _to_float(data.get("track_speed", bpm / 60.0 * speed_multiplier))
	guitar_buttons_data = _load_dictionary_list(data.get("guitar_buttons", []))
	spaceship_buttons_data = _load_dictionary_list(data.get("spaceship_buttons", []))
	spaceship_paths_data = _load_dictionary_list(data.get("spaceship_paths", []))
	guitar_sliders_data = _load_dictionary_list(data.get("guitar_sliders", []))
	shape_buttons_data = _load_dictionary_list(data.get("shape_buttons", []))
	switchs_data = _load_dictionary_list(data.get("switchs", []))
	return true

func _get_save_loc() -> String:
	return "user://tracks/%s/data.json" % track_name

func _get_legacy_save_loc() -> String:
	return "user://tracks/%s/game_data.json" % track_name

func _load_dictionary_list(raw_items: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not (raw_items is Array):
		return items

	for raw_item in raw_items:
		if raw_item is Dictionary:
			items.append(raw_item)

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
