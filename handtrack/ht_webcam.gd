extends TextureRect
class_name HandTrackWebcam

func _process(delta: float) -> void:
	var img_texture:ImageTexture = WebcamSocket.get_handtracked_image()
	if img_texture != null:
		texture = img_texture
