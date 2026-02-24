extends RichTextLabel

func _process(delta: float) -> void:
	text = str(Globals.current_score)
