extends PathFollow3D
class_name Guitar_button
@export var material:Material

func _ready() -> void:
	if material != null:
		$"Body/Base".material_override = material
