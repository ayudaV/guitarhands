extends Node3D

@export var button:PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	var button:Guitar_button = button.instantiate()
	button.change_material(get_parent().track_material)
	add_child(button)
	$Timer.start(randi_range(1,6) * 0.5)
