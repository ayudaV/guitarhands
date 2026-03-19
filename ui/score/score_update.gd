extends RichTextLabel

func _init() -> void:
	Globals.score_updated.connect(update_score)
	
func update_score():
	text = str(Globals.current_score)
