class_name GuitarButton extends PathFollow3D

func init_data(_progress:float, pos_x:float, material:Material) -> void:
	progress = _progress
	$Body.position.x = pos_x
	$"Body/Base".material_override = material
