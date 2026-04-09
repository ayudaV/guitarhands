class_name PlaybackController extends Control

@export var track_follower : TrackFollower
@export var music : AudioStreamPlayer
@export var switch_root: Node

@onready var progress: HSlider = $MarginContainer/VBoxContainer/ProgressBar
@onready var play_button: Button = $MarginContainer/VBoxContainer/Buttons/PlayButton
@onready var pause_button: Button = $MarginContainer/VBoxContainer/Buttons/PauseButton

var _syncing_progress_from_music: bool = false
var _cached_stream: AudioStream = null

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	progress.value_changed.connect(_on_seek_value_changed)
	_refresh_duration()
	_update_buttons()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("Play"):
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	toggle_play_pause()
	get_viewport().set_input_as_handled()

func refresh_transport() -> void:
	_refresh_duration()
	_update_buttons()

func _process(delta: float) -> void:
	if music.stream != _cached_stream:
		_refresh_duration()

	if _is_music_advancing():
		_syncing_progress_from_music = true
		progress.value = music.get_playback_position()
		_syncing_progress_from_music = false
		
func start_playback() -> void:
	if music.stream == null:
		_update_buttons()
		return

	var seek_time := clampf(float(progress.value), 0.0, music.stream.get_length())
	music.stream_paused = false
	music.play(seek_time)

	track_follower.configure_transport(track_follower.track_speed, true)

	if switch_root != null:
		for switch_node in switch_root.get_children():
			if is_instance_valid(switch_node) and switch_node.has_method("start"):
				switch_node.start()

	_update_buttons()

func pause_playback() -> void:
	music.stream_paused = true
	track_follower.configure_transport(track_follower.track_speed, false)
	_update_buttons()

func reset_to_beginning() -> void:
	if music.stream == null:
		_syncing_progress_from_music = true
		progress.value = 0.0
		_syncing_progress_from_music = false
		track_follower.progress = 0.0
		track_follower.configure_transport(track_follower.track_speed, false)
		_update_buttons()
		return

	music.stop()
	music.play(0.0)
	music.stream_paused = true
	_syncing_progress_from_music = true
	progress.value = 0.0
	_syncing_progress_from_music = false
	track_follower.progress = 0.0
	track_follower.configure_transport(track_follower.track_speed, false)
	_update_buttons()

func toggle_play_pause() -> void:
	if _is_music_advancing():
		pause_playback()
	else:
		start_playback()

func reset() -> void:
	reset_to_beginning()

func _on_play_pressed() -> void:
	start_playback()

func _on_pause_pressed() -> void:
	pause_playback()


func _on_seek_value_changed(_value: float) -> void:
	if not _syncing_progress_from_music:
		_seek_to_progress_value()

func _seek_to_progress_value() -> void:
	if music.stream == null:
		return

	var seek_time := clampf(float(progress.value), 0.0, music.stream.get_length())
	var resume_playing := _is_music_advancing()
	music.stop()
	music.play(seek_time)
	music.stream_paused = not resume_playing

	track_follower.configure_transport(track_follower.track_speed, resume_playing)
	track_follower.progress = seek_time * track_follower.track_speed

	_update_buttons()

func _refresh_duration() -> void:
	if music.stream != null:
		_cached_stream = music.stream
		progress.min_value = 0.0
		progress.max_value = maxf(music.stream.get_length(), 0.01)
		progress.step = 0.01
		_syncing_progress_from_music = true
		progress.value = clampf(music.get_playback_position(), 0.0, progress.max_value)
		_syncing_progress_from_music = false
	else:
		_cached_stream = null
		progress.min_value = 0.0
		progress.max_value = 1.0
		progress.step = 0.01
		_syncing_progress_from_music = true
		progress.value = 0.0
		_syncing_progress_from_music = false

func _is_music_advancing() -> bool:
	return music.playing and not music.stream_paused

func _update_buttons() -> void:
	var can_play := music.stream != null
	play_button.disabled = not can_play
	pause_button.disabled = not can_play or not _is_music_advancing()

func _on_progress_bar_drag_ended(value_changed: bool) -> void:
	pass

func _on_progress_bar_drag_started() -> void:
	pass
