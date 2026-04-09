extends Line2D

@export var path: Path2D

func _ready() -> void:
	refresh_points()

func refresh_points() -> void:
	var points = path.curve.get_baked_points()
	self.points = points
