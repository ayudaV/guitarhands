extends Area2D
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
		position = drag_event.position
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if target_id >= 0 and touch_event.index != target_id:
			return
		collision_mask = 1 if touch_event.pressed else 0



func miss_click():
	print("missclick")


func _on_body_exited(body: Node2D) -> void:
	body.get_parent().get_parent().remove()


func _on_body_entered(body: Node2D) -> void:
	body.get_parent().get_parent().moving = true
	$Click.play()
