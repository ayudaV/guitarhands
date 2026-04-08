@tool
class_name FileLoader extends Node


@export var button_scene : PackedScene
@export var save_loc : StringName = "user://save_game.json"
@export var track_materials : Array[Material]
@export var is_dirty := false
@export var track : Path3D
@export var track_speed := 0.0

var buttons : Array[Array] = []
func _ready() -> void:
	_load()
	
		
func _process(delta: float) -> void:
	if is_dirty:
		_ready()
	is_dirty = false

func _load():
	if FileAccess.file_exists(save_loc):
		var file := FileAccess.open(save_loc, FileAccess.READ)
		if file == null:
			push_warning("FileLoader: failed to open save file at %s" % String(save_loc))
			return
		var parse := JSON.new()
		var parse_result := parse.parse(file.get_as_text())
		file.close()
		if parse_result != OK:
			push_warning("FileLoader: invalid JSON in %s" % String(save_loc))
			return

		buttons.clear()
		if parse.data is Dictionary:
			for button in (parse.data as Dictionary).get("guitar_buttons", []):
				if button is Dictionary:
					var button_dict: Dictionary = button
					buttons.append([
						_to_float(button_dict.get("timestamp", 0.0)),
						_to_int(button_dict.get("pos_x", 0)),
					])
		elif parse.data is Array:
			for data in parse.data:
				if data is Array and data.size() >= 2:
					buttons.append(data)
	if track == null:
		push_warning("FileLoader: track is not assigned")
		return

	for child in track.get_children().filter(func(child:Node): return child is GuitarButton):
		track.remove_child(child)
		
	for data in buttons:
		var button_timestamp = data[0]
		var track_num = data[1]
		var button_instance:GuitarButton = button_scene.instantiate()
		button_instance.timestamp = _to_float(button_timestamp)
		button_instance.track_speed = track_speed
		button_instance.pos_x = _to_float(track_num)
		if track_materials.is_empty():
			push_warning("FileLoader: track_materials is empty")
			continue
		button_instance.material = track_materials[clamp(_to_int(track_num) + 2, 0, track_materials.size() - 1)]
		track.add_child(button_instance)

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
