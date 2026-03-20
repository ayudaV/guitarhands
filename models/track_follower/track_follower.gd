@tool
class_name TrackFollower extends PathFollow3D

@export var is_playing := false
@export var track_speed := 0.0
@export var music : AudioStreamPlayer
@export var mode := "guitar"
@export var hitbox_scene : PackedScene
@export var spaceship_scene : PackedScene
@export var shapes_scene : PackedScene
var guitar_hitbox : Node3D
var spaceship : CharacterBody3D
var shapes : Control

func _ready() -> void:
	guitar_hitbox = hitbox_scene.instantiate()
	spaceship = spaceship_scene.instantiate()
	#shapes = shapes_scene.instantiate()

func _physics_process(delta: float) -> void:
	if is_playing:
		progress = music.get_playback_position() * track_speed
	
	if not Engine.is_editor_hint():
		if Input.is_action_just_pressed("Guitar"):
			mode = "guitar"
			add_child(guitar_hitbox)
			remove_child(spaceship)
			#remove_child(shapes)
		elif Input.is_action_just_pressed("Spaceship"):
			mode = "spaceship"
			add_child(spaceship)
			remove_child(guitar_hitbox)
			#remove_child(shapes)
		elif Input.is_action_just_pressed("Shapes"):
			mode = "shapes"
			#add_child(shapes)
			remove_child(spaceship)
			remove_child(guitar_hitbox)


func _on_hurtbox_body_entered(body: Node3D) -> void:
	Globals.current_score -= 1
	body.queue_free()
