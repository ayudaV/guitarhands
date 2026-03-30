@tool
class_name TrackFollower extends PathFollow3D

@export var is_playing := false
@export var track_speed := 0.0
@export var music : AudioStreamPlayer
@export var mode := "guitar"
@export var hitbox_scene : PackedScene
@export var spaceship_scene : PackedScene
@export var shapes_scene : PackedScene
@export var mi : MeshInstance3D
@onready var camera = $Camera3D
var guitar_hitbox : Node3D
var spaceship : CharacterBody3D
var shapes : Control

func _ready() -> void:
	guitar_hitbox = hitbox_scene.instantiate()
	spaceship = spaceship_scene.instantiate()
	shapes = shapes_scene.instantiate()

func _physics_process(delta: float) -> void:
	if is_playing:
		progress = music.get_playback_position() * track_speed
	
	if not Engine.is_editor_hint():
		if Input.is_action_just_pressed("Guitar"):
			clear()
			mode = "guitar"
			add_child(guitar_hitbox)
		elif Input.is_action_just_pressed("Spaceship"):
			clear()
			mode = "spaceship"
			add_child(spaceship)
		elif Input.is_action_just_pressed("Shapes"):
			clear()
			mode = "shapes"
			add_child(shapes)

func clear():
	match mode:
		"guitar": remove_child(guitar_hitbox)
		"spaceship": remove_child(spaceship)
		"shapes": remove_child(shapes)

func _on_hurtbox_body_entered(body: Node3D) -> void:
	Globals.current_score -= 1
	body.queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos : Vector2 = event.position
		var rayStart : Vector3 = camera.project_ray_origin(mouse_pos)
		var ray_end : Vector3 = rayStart + camera.project_ray_normal(mouse_pos) * 10
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(rayStart, ray_end))
		if result:
			#mi.global_position = result.position
			Globals.aim_position[event.device] = result.position
			#print(result.position)
