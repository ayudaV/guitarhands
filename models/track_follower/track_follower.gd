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

func configure_transport(source_track_speed: float, source_is_playing: bool) -> void:
	track_speed = source_track_speed
	is_playing = source_is_playing

func switch(switch_to : Globals.Mode):
	clear()
	mode = switch_to
	match mode:
		Globals.Mode.GUITAR: add_child(guitar_hitbox)
		Globals.Mode.SPACESHIP: add_child(spaceship)
		Globals.Mode.SHAPES: add_child(shapes)
	
func clear():
	match mode:
		Globals.Mode.GUITAR: if guitar_hitbox.is_inside_tree(): remove_child(guitar_hitbox)
		Globals.Mode.SPACESHIP: if spaceship.is_inside_tree(): remove_child(spaceship)
		Globals.Mode.SHAPES: if shapes.is_inside_tree(): remove_child(shapes)

func _on_hurtbox_body_entered(body: Node3D) -> void:
	Globals.current_score -= 1
	body.queue_free()
