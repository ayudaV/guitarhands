class_name GuitarButton extends PathFollow3D
@export var material:Material

func _init(pos_x:float) -> void:
	position.x = pos_x
	
func _ready() -> void:
	if material != null:
		$"Body/Base".material_override = material
