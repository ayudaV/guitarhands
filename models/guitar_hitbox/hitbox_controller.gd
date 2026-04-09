extends Area3D

@export var device := -1
@export var pointer_id := -1

func _target_pointer_id() -> int:
	if pointer_id >= 0:
		return int(pointer_id)
	if device >= 0:
		return int(max(0, device - 1))
	return -1

func _input(event: InputEvent) -> void:
	var target_id: int = _target_pointer_id()
	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if target_id >= 0 and drag_event.index != target_id:
			return
		position.x = clampf(6 * drag_event.position.x / 1920 - 3, -2, 2)
		position.y = 0
		position.z = 0
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if target_id >= 0 and touch_event.index != target_id:
			return
		if touch_event.pressed:
			_button_press()
		else:
			$MeshInstance3D.mesh.material.emission_energy_multiplier = 1.5
			
func _button_press():
	var buttons:Array[Node3D] = get_overlapping_bodies().filter(func(node:Node3D): return node.is_in_group("Button"))
	match len(buttons):
		0: error_click()
		_: remove_button(buttons[0].get_parent())
	$MeshInstance3D.mesh.material.emission_energy_multiplier = 3.5
func error_click():
	pass
	
func remove_button(button:GuitarButton):
	Globals.add_score(1)
	button.queue_free()
	$GPUParticles3D.emitting = true
	$Click.play()
