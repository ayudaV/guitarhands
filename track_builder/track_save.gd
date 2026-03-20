extends Node
@export var timer := 0.0
@export var save_loc : StringName = "user://save_game.dat"
@export var record_mode: String = "overwrite"
@export var track_speed := 1.0
var bpm := 132
var new_buttons: Array[Array] = []
var buttons : Array[Array] = []

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
		new_buttons.sort_custom(func(a, b): return a[0] > b[0])
	elif  record_mode == "overwrite":
		buttons = new_buttons
	var file = FileAccess.open(save_loc, FileAccess.WRITE)
	file.store_var(buttons.duplicate())
	file.close()

func _on_music_finished() -> void:
	print("saving file")
	_save()
