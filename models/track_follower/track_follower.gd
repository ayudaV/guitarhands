@tool
class_name TrackFollower extends PathFollow3D

@export var is_playing := false
@export var track_speed := 2.0
@export var music : AudioStreamPlayer
@export var mode : Globals.Mode
@export var hitbox_scene : PackedScene
@export var spaceship_scene : PackedScene
@export var shapes_scene : PackedScene

@onready var camera = $Camera3D
var guitar_hitbox : Node3D
var spaceship : CharacterBody3D
var shapes : Control

func _ready() -> void:
	guitar_hitbox = hitbox_scene.instantiate()
	spaceship = spaceship_scene.instantiate()
	shapes = shapes_scene.instantiate()
	Globals.mode_changed.connect(switch)

func _physics_process(delta: float) -> void:
	if is_playing:
		progress = music.get_playback_position() * track_speed
	
func switch(switch_to : Globals.Mode):
	clear()
	mode = switch_to
	match mode:
		Globals.Mode.GUITAR: add_child(guitar_hitbox)
		Globals.Mode.SPACESHIP: add_child(spaceship)
		Globals.Mode.SHAPES: add_child(shapes)
	
func clear():
	match mode:
		Globals.Mode.GUITAR: remove_child(guitar_hitbox)
		Globals.Mode.SPACESHIP: remove_child(spaceship)
		Globals.Mode.SHAPES: remove_child(shapes)

func _on_hurtbox_body_entered(body: Node3D) -> void:
	Globals.current_score -= 1
	body.queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		var mouse_pos : Vector2 = drag_event.position
		var rayStart : Vector3 = camera.project_ray_origin(mouse_pos)
		var ray_end : Vector3 = rayStart + camera.project_ray_normal(mouse_pos) * 10
		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(rayStart, ray_end))
		if result:
			Globals.aim_position[drag_event.index] = result.position
			Globals.aim_position[drag_event.index + 1] = result.position
			#print(result.position)
