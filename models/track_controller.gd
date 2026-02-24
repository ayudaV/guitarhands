extends Node3D
@export_range(0,3) var track_id:int
@export var key:String

var bodies = []

var dict = {"LTrack": KEY_H, "MLTrack":KEY_U, "MRTrack":KEY_I, "RTrack": KEY_L}

func _input(event: InputEvent) -> void:
	print(event)
	if event.is_action_pressed(key):
		if len(bodies) > 0:
			var body:CharacterBody3D = bodies[0]
			var hit_dist = abs(body.global_position.x - $Hitbox.global_position.x)
			if hit_dist < 0.5: Globals.current_score += 100
			else: Globals.current_score += 70
			body.queue_free()
		else:
			Globals.current_score -= 50


func _on_hurt_box_body_entered(body: Node3D) -> void:
	Globals.current_score -= 50
	body.queue_free()


func _on_hitbox_body_entered(body: Node3D) -> void:
	bodies.append(body)


func _on_hitbox_body_exited(body: Node3D) -> void:
	bodies.erase(body)
