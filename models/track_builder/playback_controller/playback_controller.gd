class_name PlaybackController extends Control

@export var play := false
@export var pause := false
@export var reset := false
@export var track_follower : TrackFollower
@export var music : AudioStreamPlayer
@onready var progress := $MarginContainer/ProgressBar

func _ready() -> void:
	progress.max_value = music.stream.get_length() 
	
func _process(delta: float) -> void:
	if play:
		music.play()
		track_follower.is_playing = true
		play = false
	if pause:
		music.stream_paused = true
		track_follower.is_playing = false
		pause = false
	if reset:
		music.stream_paused = true
		track_follower.is_playing = false
		pause = false
	if not Engine.is_editor_hint():
		if Input.is_action_just_pressed("Play"):
			play = true
	
	progress.value = music.get_playback_position()
		
