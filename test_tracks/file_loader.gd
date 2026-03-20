@tool
class_name FileLoader extends Node


@export var button_scene : PackedScene
@export var save_loc : StringName = "user://save_game.dat"
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
		var file = FileAccess.open(save_loc, FileAccess.READ)
		buttons = file.get_var()
		file.close()
	for child in track.get_children().filter(func(child:Node): return child is Guitar_button):
		track.remove_child(child)
		
	for data in buttons:
		var button_timestamp = data[0]
		var track_num = data[1]
		var button_instance:Guitar_button = button_scene.instantiate()
		print(button_timestamp * track_speed)
		button_instance.progress = button_timestamp * track_speed
		button_instance.material = track_materials[track_num+2]
		button_instance.get_node("Body").position.x = track_num
		track.add_child(button_instance)
