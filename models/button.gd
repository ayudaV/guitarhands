extends CharacterBody3D
class_name Guitar_button

@export var _velocity = Vector3(10, 0, 0)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	velocity = _velocity
	move_and_slide()
