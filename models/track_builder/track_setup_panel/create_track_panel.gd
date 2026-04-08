class_name TrackCreatePanel extends PanelContainer

@export var file_writer_path: NodePath
@export var file_reader_path: NodePath
@export var playback_controller_path: NodePath

@onready var track_name_edit: LineEdit = $MarginContainer/VBoxContainer/TrackNameRow/TrackNameEdit
@onready var track_title_edit: LineEdit = $MarginContainer/VBoxContainer/TrackTitleRow/TrackTitleEdit
@onready var bpm_spin_box: SpinBox = $MarginContainer/VBoxContainer/BpmRow/BpmSpinBox
@onready var music_path_edit: LineEdit = $MarginContainer/VBoxContainer/MusicRow/MusicPathEdit
@onready var browse_button: Button = $MarginContainer/VBoxContainer/MusicRow/BrowseButton
@onready var create_button: Button = $MarginContainer/VBoxContainer/ActionsRow/CreateButton
@onready var load_button: Button = $MarginContainer/VBoxContainer/ActionsRow/LoadButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var file_dialog: FileDialog = $FileDialog

var _file_writer: FileWriter
var _file_reader: FileReader
var _playback_controller: PlaybackController

func _ready() -> void:
	_file_writer = get_node_or_null(file_writer_path) as FileWriter
	_file_reader = get_node_or_null(file_reader_path) as FileReader
	_playback_controller = get_node_or_null(playback_controller_path) as PlaybackController

	browse_button.pressed.connect(_on_browse_pressed)
	create_button.pressed.connect(_on_create_pressed)
	load_button.pressed.connect(_on_load_pressed)
	file_dialog.file_selected.connect(_on_music_file_selected)

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.wav ; WAV Audio"])
	music_path_edit.editable = false
	bpm_spin_box.min_value = 1
	bpm_spin_box.max_value = 999
	bpm_spin_box.step = 1
	_sync_fields_from_writer()

func _sync_fields_from_writer() -> void:
	if _file_writer != null:
		if not _file_writer.track_name.is_empty():
			track_name_edit.text = _file_writer.track_name
		if not _file_writer.track_title.is_empty():
			track_title_edit.text = _file_writer.track_title
		elif track_title_edit.text.is_empty() and not track_name_edit.text.is_empty():
			track_title_edit.text = track_name_edit.text
		bpm_spin_box.value = float(_file_writer.bpm)
		if not _file_writer.source_music_path.is_empty():
			music_path_edit.text = _file_writer.source_music_path

	if track_title_edit.text.is_empty() and not track_name_edit.text.is_empty():
		track_title_edit.text = track_name_edit.text

func _bind_runtime_nodes() -> bool:
	if _playback_controller == null:
		_set_status("Unable to create playback controller")
		return false

	var track_follower := get_node_or_null("../../Track/TrackFollower") as TrackFollower
	var switch_root := get_node_or_null("../../SwitchRoot")
	var controller_music := _playback_controller.music

	_playback_controller.track_follower = track_follower
	_playback_controller.switch_root = switch_root

	if _file_writer != null:
		_file_writer.music = controller_music
		_file_writer.track_follower = track_follower

	if _file_reader != null:
		_file_reader.music = controller_music
		_file_reader.track_follower = track_follower
		_file_reader.switch_root = switch_root

	return true

func _on_browse_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)

func _on_music_file_selected(path: String) -> void:
	music_path_edit.text = path
	_set_status("Selected WAV file")

func _on_create_pressed() -> void:
	var track_name := track_name_edit.text.strip_edges()
	if track_name.is_empty():
		_set_status("Track name is required")
		return

	var track_title := track_title_edit.text.strip_edges()
	if track_title.is_empty():
		track_title = track_name

	var music_path := music_path_edit.text.strip_edges()
	if music_path.is_empty():
		_set_status("Pick a WAV file first")
		return

	if not _bind_runtime_nodes():
		return

	if _file_writer != null:
		_file_writer.configure_new_track(track_name, track_title, int(bpm_spin_box.value), _file_writer.speed_multiplier, music_path)
	if _file_reader != null:
		_file_reader.track_name = track_name
		_file_reader.track_title = track_title
		_file_reader.reload_track()
	if _playback_controller != null:
		_playback_controller.start_playback()

	_set_status("Created track %s" % track_name)

func _on_load_pressed() -> void:
	var track_name := track_name_edit.text.strip_edges()
	if track_name.is_empty():
		_set_status("Track name is required")
		return

	if not _bind_runtime_nodes():
		return

	if _file_writer == null or not _file_writer.load_existing_track(track_name):
		_set_status("Track %s was not found" % track_name)
		return

	track_title_edit.text = _file_writer.track_title if not _file_writer.track_title.is_empty() else track_name
	bpm_spin_box.value = float(_file_writer.bpm)
	if not _file_writer.source_music_path.is_empty():
		music_path_edit.text = _file_writer.source_music_path
	if _file_reader != null:
		_file_reader.track_name = track_name
		_file_reader.track_title = track_title_edit.text.strip_edges()
		_file_reader.reload_track()
	if _playback_controller != null:
		_playback_controller.start_playback()

	_set_status("Loaded track %s" % track_name)

func _set_status(message: String) -> void:
	status_label.text = message
