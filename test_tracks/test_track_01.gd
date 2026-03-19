extends Node3D

var timer := 0.0
var bpm := 132
@export var button_scene : PackedScene
@export var save_loc : StringName
@export var track_materials : Array[Material]
@export var record_mode: String = "keep"

var buttons : Array[Array] = []
var new_buttons: Array[Array] = []
func _ready() -> void:
	_load()
	for data in buttons:
		var pos = data[0]
		var track_num = data[1]
		var button_instance:Guitar_button = button_scene.instantiate()
		button_instance.progress = pos
		#var track_num = randi_range(-2, 2)
		button_instance.material = track_materials[track_num]
		button_instance.get_node("Body").position.x = track_num
		$Track.add_child(button_instance)

func _process(delta: float) -> void:
	timer += delta
	if Input.is_action_just_pressed("MRTrack"):
		new_buttons.append([snapped(timer * (bpm/60), 0.1), 2])
	if Input.is_action_just_pressed("RTrack"):
		new_buttons.append([snapped(timer * (bpm/60), 0.1), 1])
	if Input.is_action_just_pressed("MainTrack"):
		new_buttons.append([snapped(timer * (bpm/60), 0.1), 0])
	if Input.is_action_just_pressed("LTrack"):
		new_buttons.append([snapped(timer * (bpm/60), 0.1), -1])
	if Input.is_action_just_pressed("MLTrack"):
		new_buttons.append([snapped(timer * (bpm/60), 0.1), -2])

func _save():
	if record_mode == "append":
		buttons += new_buttons
		buttons.sort_custom(func(a, b): return a[0] > b[0])
	elif  record_mode == "overwrite":
		buttons = new_buttons
	var file = FileAccess.open(save_loc, FileAccess.WRITE)
	file.store_var(buttons.duplicate())
	file.close()
	
func _load():
	if FileAccess.file_exists(save_loc):
		var file = FileAccess.open(save_loc, FileAccess.READ)
		buttons = file.get_var()
		file.close()

func _on_music_finished() -> void:
	print("saving file")
	_save()
