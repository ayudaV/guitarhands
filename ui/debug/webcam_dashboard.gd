extends Control
class_name WebcamDashboard

@export var max_webcams_to_scan: int = 10
@export var tracked_hands: int = 2
@export var default_webcam_index: int = 0
@export var show_landmarks_default: bool = false

@onready var _camera_view: TextureRect = %CameraView
#@onready var _overlay: HandOverlay = %HandOverlay
@onready var _webcam_list: OptionButton = %WebcamList
@onready var _show_landmarks_toggle: CheckBox = %ShowLandmarks
@onready var _fit_mode_selector: OptionButton = %FitMode
@onready var _latency_all: Label = %LatencyAll
@onready var _latency_capture: Label = %LatencyCapture
@onready var _latency_mediapipe: Label = %LatencyMediapipe

func _ready() -> void:
	_show_landmarks_toggle.button_pressed = show_landmarks_default

	_fit_mode_selector.clear()
	_fit_mode_selector.add_item("Stretch", HandOverlay.CaptureFitMode.STRETCH)
	_fit_mode_selector.add_item("Cut To Fit", HandOverlay.CaptureFitMode.CUT_TO_FIT)
	_fit_mode_selector.select(0)
	_fit_mode_selector.item_selected.connect(_on_fit_mode_selected)

	_webcam_list.clear()
	var available_webcams: Array = WebcamSocket.get_available_webcams(max_webcams_to_scan)
	for camera_index in available_webcams:
		_webcam_list.add_item("Webcam %d" % int(camera_index), int(camera_index))

	if _webcam_list.item_count > 0:
		var selected := 0
		for i in range(_webcam_list.item_count):
			if _webcam_list.get_item_id(i) == default_webcam_index:
				selected = i
				break
		_webcam_list.select(selected)
		WebcamSocket.set_webcam(_webcam_list.get_item_id(selected))

	_webcam_list.item_selected.connect(_on_webcam_selected)

func _process(delta: float) -> void:
	var texture: ImageTexture = WebcamSocket.get_image_texture(_show_landmarks_toggle.button_pressed)
	if texture != null:
		_camera_view.texture = texture

	#var resolution: Vector2 = WebcamSocket.get_capture_resolution()
	#var capture_width: int = max(1, int(resolution.x))
	#var capture_height: int = max(1, int(resolution.y))
	#var tips: Array = WebcamSocket.get_thumb_index_tips(tracked_hands)
	#_overlay.update_hands(tips, capture_width, capture_height)

	_latency_all.text = "Latency All: %.2f ms" % WebcamSocket.get_latency("all")
	_latency_capture.text = "Capture: %.2f ms" % WebcamSocket.get_latency("image_capture")
	_latency_mediapipe.text = "MediaPipe: %.2f ms" % WebcamSocket.get_latency("mediapipe_process")

func _on_webcam_selected(item_index: int) -> void:
	var camera_index := _webcam_list.get_item_id(item_index)
	WebcamSocket.set_webcam(camera_index)

func _on_fit_mode_selected(item_index: int) -> void:
	var fit_mode_id := _fit_mode_selector.get_item_id(item_index)
	#_overlay.fit_mode = fit_mode_id
