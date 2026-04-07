extends Node
signal score_updated
signal mode_changed

@export var current_score := 0.0
@export var high_score := 10000.0
@export var aim_position : Dictionary
@export var current_mode : Mode
enum Mode {
	GUITAR,
	SPACESHIP,
	SHAPES
}
func switch_mode(new_mode: Mode):
	#if new_mode != current_mode:
	current_mode = new_mode
	mode_changed.emit(new_mode)
	
func add_score(points:int):
	current_score += points
	if current_score > high_score:
		high_score = current_score
	score_updated.emit()
