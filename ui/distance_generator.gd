extends VBoxContainer

@export var side:String
# Create a new InputEventKey
@onready var _LTrack = InputEventAction.new()
@onready var _MLTrack = InputEventAction.new()
@onready var _MRTrack = InputEventAction.new()
@onready var _RTrack = InputEventAction.new()

func _ready() -> void:
	# Configure the event
	_LTrack.action = "LTrack"  
	_MLTrack.action = "MLTrack"  
	_MRTrack.action = "MRTrack"  
	_RTrack.action = "RTrack"  
	
func _process(delta: float) -> void:
	
	if Input.is_action_just_pressed("Calibrate"):
		$Index.min_value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "INDEX_FINGER_TIP", side)
		$Middle.min_value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "MIDDLE_FINGER_TIP", side)
		$Ring.min_value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "RING_FINGER_TIP", side)
		$Pinky.min_value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "PINKY_TIP", side)

	if Input.is_action_just_released("Calibrate"):
		$Index.max_value = 0.9/WebcamSocket.get_landmark_distance("THUMB_TIP", "INDEX_FINGER_TIP", side)
		$Middle.max_value = 0.9/WebcamSocket.get_landmark_distance("THUMB_TIP", "MIDDLE_FINGER_TIP", side)
		$Ring.max_value = 0.9/WebcamSocket.get_landmark_distance("THUMB_TIP", "RING_FINGER_TIP", side)
		$Pinky.max_value = 0.8/WebcamSocket.get_landmark_distance("THUMB_TIP", "PINKY_TIP", side)

	$Index.value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "INDEX_FINGER_TIP", side)
	$Middle.value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "MIDDLE_FINGER_TIP", side)
	$Ring.value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "RING_FINGER_TIP", side)
	$Pinky.value = 1/WebcamSocket.get_landmark_distance("THUMB_TIP", "PINKY_TIP", side)

	if side == "RIGHT":
		if $Index.value >= $Index.max_value and not _LTrack.pressed: 
			_LTrack.pressed = true # Simulate a key press
			get_tree().root.push_input(_LTrack) # Push the event to the Viewport
			print(_LTrack)
		elif $Index.value < $Index.max_value and _LTrack.pressed:
			_LTrack.pressed = false
			get_tree().root.push_input(_LTrack)

		if $Middle.value >= $Middle.max_value and not _MLTrack.pressed: 
			_MLTrack.pressed = true 
			get_tree().root.push_input(_MLTrack)
		elif $Middle.value < $Middle.max_value and _MLTrack.pressed:
			_MLTrack.pressed = false
			get_tree().root.push_input(_MLTrack)

		if $Ring.value >= $Ring.max_value and not _MRTrack.pressed: 
			_MRTrack.pressed = true 
			get_tree().root.push_input(_MRTrack)
		elif $Ring.value < $Ring.max_value and _MRTrack.pressed:
			_MRTrack.pressed = false
			get_tree().root.push_input(_MRTrack)

		if $Pinky.value >= $Pinky.max_value and not _RTrack.pressed: 
			_RTrack.pressed = true 
			get_tree().root.push_input(_RTrack)
		elif $Pinky.value < $Pinky.max_value and _RTrack.pressed:
			_RTrack.pressed = false
			get_tree().root.push_input(_RTrack)
			
	elif side == "LEFT":
		if $Index.value >= $Index.max_value and not _RTrack.pressed: 
			_RTrack.pressed = false
			get_tree().root.push_input(_RTrack)
		elif $Index.value < $Index.max_value and _RTrack.pressed:
			_RTrack.pressed = false
			get_tree().root.push_input(_RTrack)

		if $Middle.value >= $Middle.max_value and not _MRTrack.pressed: 
			_MRTrack.pressed = true 
			get_tree().root.push_input(_MRTrack)
		elif $Middle.value < $Middle.max_value and _MRTrack.pressed:
			_MRTrack.pressed = false
			get_tree().root.push_input(_MRTrack)

		if $Ring.value >= $Ring.max_value and not _MLTrack.pressed: 
			_MLTrack.pressed = true
			get_tree().root.push_input(_MLTrack) 
		elif $Ring.value < $Ring.max_value and _MLTrack.pressed:
			_MLTrack.pressed = false
			get_tree().root.push_input(_MLTrack)

		if $Pinky.value >= $Pinky.max_value and not _RTrack.pressed: 
			_RTrack.pressed = true 
			get_tree().root.push_input(_RTrack) 
		elif $Pinky.value < $Pinky.max_value and _RTrack.pressed:
			_RTrack.pressed = true
			get_tree().root.push_input(_RTrack) 
