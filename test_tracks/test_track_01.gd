@tool
extends Node3D

@export var speed_multiplier := 1.0
@export var bpm := 120
@export var play := false
@export var pause := false
@export var reset := false
var track_speed := 0.0

func _ready() -> void:
	track_speed = bpm/60.0 * speed_multiplier
	$Track/TrackFollower.track_speed = track_speed
	$FileLoader.track_speed = track_speed
	$FileWriter.track_speed = track_speed

func _process(delta: float) -> void:
	if play:
		$Music.play()
		$Track/TrackFollower.is_playing = true
		play = false
	if pause:
		$Music.stream_paused = true
		$Track/TrackFollower.is_playing = false
		pause = false
	if reset:
		$Music.stream_paused = true
		$Track/TrackFollower.is_playing = false
		pause = false
	if not Engine.is_editor_hint():
		if Input.is_action_just_pressed("Play"):
			play = true
		
