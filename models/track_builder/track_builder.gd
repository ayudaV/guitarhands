extends Node3D
@export var speed_multiplier := 1.0
@export var bpm := 120
var track_speed := 0.0

func _ready() -> void:
	track_speed = bpm/60.0 * speed_multiplier
	$Track/TrackFollower.track_speed = track_speed
	#$FileLoader.track_speed = track_speed
	#$FileWriter.track_speed = track_speed
