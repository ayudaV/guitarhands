@tool 
extends Path3D

@export var distance_between_rings := 8
@export var is_dirty = false

func _ready() -> void:
	is_dirty = true

func _process(delta: float) -> void:
	if is_dirty:
		_update_multimesh()
		is_dirty = false
		
func _update_multimesh():
	var path_length = curve.get_baked_length()
	var count = floor(path_length / distance_between_rings)
	
	var mm:MultiMesh = $Rings.multimesh
	mm.instance_count = count
	var offset = distance_between_rings/2.0
	
	for i in range(0, count):
		var curve_distance = offset + distance_between_rings * i
		var position = curve.sample_baked(curve_distance, true)
		
		var basis = Basis()
		var up = curve.sample_baked_up_vector(curve_distance, true)
		var forward = position.direction_to(curve.sample_baked(curve_distance + 0.1, true))

		basis.y = up
		basis.x = forward.cross(up).normalized()
		basis.z = -forward
		var transform = Transform3D(basis, position)
		mm.set_instance_transform(i, transform)



func _on_curve_changed() -> void:
	is_dirty = true
