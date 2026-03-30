extends Area3D

@export var device := -1

func _input(event: InputEvent) -> void:
	if event.device == device:
		if event is InputEventMouseMotion:
			position = Globals.aim_position.get(event.device, Vector3.ZERO)
			print(device, position)
		if event is InputEventMouseButton:
			if event.pressed:
				_button_press()

func _button_press():
	var buttons:Array[Node3D] = get_overlapping_bodies().filter(func(node:Node3D): return node.is_in_group("Button"))
	match len(buttons):
		0: error_click()
		_: remove_button(buttons[0].get_parent())
		
func error_click():
	pass
	
func remove_button(button:GuitarButton):
	Globals.add_score(1)
	button.queue_free()
	$GPUParticles3D.emitting = true
	$Click.play()
