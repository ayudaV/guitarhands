class_name Switch extends Timer
@export var switch_to : Globals.Mode

func _init(timestamp: float, switch_to:Globals.Mode) -> void:
	if timestamp == 0.0:
		timestamp = 0.001
	wait_time = timestamp
	switch_to = switch_to

func _on_timeout() -> void:
	Globals.switch_mode(switch_to)
