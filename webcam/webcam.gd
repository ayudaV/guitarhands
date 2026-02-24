extends TextureRect
class_name Webcam
func _process(delta: float) -> void:
	var img_texture:ImageTexture = WebcamSocket.get_image()
	if img_texture != null:
		texture = img_texture
