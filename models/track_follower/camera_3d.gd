extends Camera3D

@export var mi : MeshInstance3D

func _physics_process(delta: float) -> void:
	var mousePos := get_viewport().get_mouse_position()

	var rayStart :Vector3= project_ray_origin(mousePos)
	var direction :Vector3= project_ray_normal(mousePos)

	var plane_normal := -global_transform.basis.z.normalized()
	var plane := Plane(plane_normal, plane_normal.dot(mi.global_position))

	var intersection = plane.intersects_ray(rayStart,direction)

	if intersection:
		mi.global_position = intersection
