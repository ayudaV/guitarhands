class_name GuitarButton extends PathFollow3D
@export var timestamp : float
@export var pos_x: float
@export var material: Material
@export var track_speed := 2

func _init(timestamp: float, pos_x: float, material: Material) -> void:
	timestamp = timestamp
	pos_x = pos_x
	material = material
	
func _ready() -> void:
	progress = timestamp * track_speed
	$Body.position.x = pos_x
	$"Body/Base".material_override = material
