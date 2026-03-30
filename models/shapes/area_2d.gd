extends Area2D
@export var device := -1

func _input(event: InputEvent) -> void:
	if event.device == device:
		if event is InputEventMouseMotion:
			position = event.position
		if event is InputEventMouseButton:
			if event.pressed:
				collision_mask = 1
			else:
				collision_mask = 0



func miss_click():
	print("missclick")


func _on_body_exited(body: Node2D) -> void:
	body.get_parent().get_parent().remove()


func _on_body_entered(body: Node2D) -> void:
	body.get_parent().get_parent().moving = true
	$Click.play()
