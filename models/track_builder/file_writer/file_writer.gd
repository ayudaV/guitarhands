class_name FileWriter extends Node
enum RecordMode {
	KEEP,
	APPEND,
	OVERWRITE
}
@export var music : AudioStreamPlayer
@export var save_loc : StringName = "user://save_game.tres"
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

func _process(delta: float) -> void:
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
		
		guitar_buttons.sort_custom(func(a: GuitarButtonData, b: GuitarButtonData): return a.timestamp > b.timestamp)
		guitar_sliders.sort_custom(func(a: GuitarSliderData, b: GuitarSliderData): return a.timestamp > b.timestamp)
		shape_buttons.sort_custom(func(a: ShapeButtonData, b: ShapeButtonData): return a.timestamp > b.timestamp)
		switchs.sort_custom(func(a: SwitchData, b: SwitchData): return a.timestamp > b.timestamp)

	
	elif  record_mode == RecordMode.OVERWRITE:
		guitar_buttons = new_guitar_buttons
		guitar_sliders = new_guitar_sliders
		shape_buttons = new_shape_buttons
		switchs = new_switchs

	var data = GenericResource.new()
	data.music = music.stream
	data.bpm = bpm
	data.speed_multiplier = speed_multiplier
	data.guitar_buttons = guitar_buttons
	data.shape_buttons = shape_buttons
	data.guitar_sliders = guitar_sliders
	data.switchs = switchs
	var result = ResourceSaver.save(data, save_loc)
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
