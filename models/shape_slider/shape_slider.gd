class_name ShapesButton extends Path2D

@export var time_delta := 1.0
@export var moving := false
@onready var path_follow = $PathFollow2D
var enable = true

func _process(delta: float) -> void:
	if moving:
		path_follow.progress_ratio += delta * 1 / time_delta
		$PathFollow2D/ShapeButton/CollisionShape2D.shape.radius = 100
		if path_follow.progress_ratio >= 1 and enable:
			remove()
			
func remove():
	if enable:
		enable = false
		$PathFollow2D/ShapeButton/GPUParticles.emitting = true
		$PathFollow2D/ShapeButton/Release.play()
		$PathFollow2D/ShapeButton/TextureRect.visible = false
	
func _on_release_finished() -> void:
	queue_free()
