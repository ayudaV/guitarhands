class_name TrackCreatePanel extends PanelContainer

@export var file_loader: FileLoader
@export var file_writer: FileWriter
@export var file_reader: FileReader
@export var playback_controller: PlaybackController

@onready var track_name_edit: LineEdit = $MarginContainer/VBoxContainer/TrackNameRow/TrackNameEdit
@onready var track_title_edit: LineEdit = $MarginContainer/VBoxContainer/TrackTitleRow/TrackTitleEdit
@onready var bpm_spin_box: SpinBox = $MarginContainer/VBoxContainer/BpmRow/BpmSpinBox
@onready var speed_multiplier_spin_box: SpinBox = $MarginContainer/VBoxContainer/SpeedMultiplierRow/SpeedMultiplierSpinBox
@onready var snap_enabled_check_box: CheckBox = $MarginContainer/VBoxContainer/TimingSnapRow/SnapEnabledCheckBox
@onready var snap_divisor_spin_box: SpinBox = $MarginContainer/VBoxContainer/TimingSnapRow/SnapDivisorSpinBox
@onready var track_speed_edit: LineEdit = $MarginContainer/VBoxContainer/TrackSpeedRow/TrackSpeedEdit
@onready var music_path_edit: LineEdit = $MarginContainer/VBoxContainer/MusicRow/MusicPathEdit
@onready var browse_button: Button = $MarginContainer/VBoxContainer/MusicRow/BrowseButton
@onready var save_button: Button = $MarginContainer/VBoxContainer/ActionsRow/SaveButton
@onready var load_button: Button = $MarginContainer/VBoxContainer/ActionsRow/LoadButton
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ActionsRow/ResetButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var file_dialog: FileDialog = $FileDialog

func _ready() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	file_dialog.file_selected.connect(_on_music_file_selected)
	bpm_spin_box.value_changed.connect(_on_metadata_changed)
	speed_multiplier_spin_box.value_changed.connect(_on_metadata_changed)
	snap_enabled_check_box.toggled.connect(_on_snap_changed)
	snap_divisor_spin_box.value_changed.connect(_on_snap_divisor_changed)

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.wav ; WAV Audio"])
	music_path_edit.editable = false
	track_speed_edit.editable = false
	track_speed_edit.context_menu_enabled = false
	bpm_spin_box.min_value = 1
	bpm_spin_box.max_value = 999
	bpm_spin_box.step = 1
	speed_multiplier_spin_box.min_value = 0.01
	speed_multiplier_spin_box.max_value = 100.0
	speed_multiplier_spin_box.step = 0.01
	snap_divisor_spin_box.min_value = 1
	snap_divisor_spin_box.max_value = 32
	snap_divisor_spin_box.step = 1
	_sync_fields_from_loader()
	_update_track_speed_display()

func _sync_fields_from_loader() -> void:
	if not file_loader.track_name.is_empty():
		track_name_edit.text = file_loader.track_name
	if not file_loader.track_title.is_empty():
		track_title_edit.text = file_loader.track_title
	elif track_title_edit.text.is_empty() and not track_name_edit.text.is_empty():
		track_title_edit.text = track_name_edit.text

	bpm_spin_box.value = float(file_loader.bpm)
	speed_multiplier_spin_box.value = float(file_loader.speed_multiplier)
	snap_enabled_check_box.button_pressed = file_loader.use_beat_snap
	snap_divisor_spin_box.value = float(file_loader.beat_snap_divisor)
	snap_divisor_spin_box.editable = file_loader.use_beat_snap
	music_path_edit.text = file_loader.music_path
	_update_track_speed_display()

func _copy_display_to_writer() -> void:
	file_writer.track_name = track_name_edit.text.strip_edges()
	file_writer.track_title = track_title_edit.text.strip_edges()
	if file_writer.track_title.is_empty():
		file_writer.track_title = file_writer.track_name
	file_writer.bpm = int(bpm_spin_box.value)
	file_writer.speed_multiplier = float(speed_multiplier_spin_box.value)
	file_writer.use_beat_snap = snap_enabled_check_box.button_pressed
	file_writer.beat_snap_divisor = int(snap_divisor_spin_box.value)
	file_writer.source_music_path = music_path_edit.text.strip_edges()
	file_writer.prepare_track()

func _compute_track_speed() -> float:
	return float(bpm_spin_box.value) / 60.0 * float(speed_multiplier_spin_box.value)

func _update_track_speed_display() -> void:
	track_speed_edit.text = "%.3f" % _compute_track_speed()

func _reload_runtime_track() -> void:
	file_reader.track_name = track_name_edit.text.strip_edges()
	file_reader.track_title = track_title_edit.text.strip_edges()
	file_reader.reload_track()

func _on_browse_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)

func _on_music_file_selected(path: String) -> void:
	music_path_edit.text = path
	_update_track_speed_display()
	_set_status("Selected WAV file")

func _on_metadata_changed(_value: float) -> void:
	_update_track_speed_display()

func _on_snap_changed(enabled: bool) -> void:
	snap_divisor_spin_box.editable = enabled

func _on_snap_divisor_changed(_value: float) -> void:
	pass

func _on_save_pressed() -> void:
	_copy_display_to_writer()
	file_writer.save_track()
	_reload_runtime_track()
	playback_controller.refresh_transport()
	playback_controller.reset_to_beginning()
	_set_status("Saved track %s" % track_name_edit.text.strip_edges())

func _on_load_pressed() -> void:
	var track_name := track_name_edit.text.strip_edges()
	if track_name.is_empty():
		_set_status("Track folder is required")
		return

	if not file_loader.load_track(track_name):
		_set_status("Track %s was not found" % track_name)
		return

	file_writer.import_track_data(file_loader.track_data)
	_sync_fields_from_loader()
	_reload_runtime_track()
	playback_controller.refresh_transport()
	_set_status("Loaded track %s" % track_name)

func _on_reset_pressed() -> void:
	file_writer.discard_unsaved_changes()
	_reload_runtime_track()
	playback_controller.refresh_transport()
	playback_controller.reset_to_beginning()
	_set_status("Discarded unsaved notes")

func _set_status(message: String) -> void:
	status_label.text = message
