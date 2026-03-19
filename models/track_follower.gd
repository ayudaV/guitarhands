extends PathFollow3D

@export var is_playing := false
@export var bpm := 120
func _process(delta: float) -> void:
	if is_playing:
		progress += bpm/60 * delta



func _on_hurtbox_body_entered(body: Node3D) -> void:
	Globals.current_score -= 1
