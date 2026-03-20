extends Node
signal score_updated
@export var current_score := 0.0
@export var high_score := 10000.0

func add_score(points:int):
	current_score += points
	if current_score > high_score:
		high_score = current_score
	score_updated.emit()
