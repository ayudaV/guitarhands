extends Area3D

@export var track_name : StringName

func _button_press():
	var buttons:Array[Node3D] = get_overlapping_bodies().filter(func(node:Node3D): return node.is_in_group("Button"))
	match len(buttons):
		0: error_click()
		_: remove_button(buttons[0].get_parent())
		
func error_click():
	pass
	
func remove_button(button:Guitar_button):
	print("delete")
	Globals.add_score(1)
	button.queue_free()
	$GPUParticles3D.emitting = true
