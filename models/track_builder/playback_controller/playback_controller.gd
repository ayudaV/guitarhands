class_name PlaybackController extends Control

@export var play := false
@export var pause := false
@export var track_follower : TrackFollower
@export var music : AudioStreamPlayer
@export var switch_root: Node

@onready var progress := $MarginContainer/ProgressBar
var _playback_started: bool = false

func _ready() -> void:
	if music != null and music.stream != null:
		progress.max_value = music.stream.get_length()
	else:
		progress.max_value = 1.0
		progress.value = 0.0
	
func _process(delta: float) -> void:
	if play: start_playback()
	if pause: reset()
	
	if music != null:
		progress.value = music.get_playback_position()
		
func start_playback() -> void:
	if music == null or music.stream == null:
		_playback_started = false
		play = false
		return
	if _playback_started:
		return
	_playback_started = true

	if music != null:
		music.play()
	if track_follower != null:
		track_follower.is_playing = true
	if switch_root != null:
		for switch_node in switch_root.get_children():
			if is_instance_valid(switch_node):
				switch_node.start()

func reset():
	if music != null:
		music.stream_paused = true
		music.stop()
	if track_follower != null:
		track_follower.is_playing = false
	_playback_started = false
	play = false
	pause = false
