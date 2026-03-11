class_name Bat
extends CharacterBody2D

@export var speed: float = 120.0
@export var wobble_strength: float = 20.0
@export var wobble_speed: float = 3.0
@export var max_health: int = 3

var _time: float = 0.0
var returning: bool = false
var _health: int

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_health = max_health
	velocity = Vector2(randf_range(-60.0, 60.0), -speed)
	
	if _sprite and _sprite.sprite_frames:
		if _sprite.sprite_frames.has_animation(&"movement"):
			_sprite.play(&"movement")


func _physics_process(delta: float) -> void:
	_time += delta
	
	velocity.x += sin(_time * wobble_speed) * wobble_strength * delta
	velocity.x = clampf(velocity.x, -speed, speed)
	
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		var collider = collision.get_collider()
		
		if collider and collider.name == "top":
			returning = true
			var angle = randf_range(deg_to_rad(200), deg_to_rad(340))
			velocity = Vector2(cos(angle), sin(angle)) * speed
	
	if _sprite:
		_sprite.flip_h = velocity.x < 0


func take_damage() -> void:
	_health -= 1
	
	if _health <= 0:
		_die()
	else:
		_play_damage()


func _play_damage() -> void:
	if _sprite and _sprite.sprite_frames:
		if _sprite.sprite_frames.has_animation(&"damage"):
			_sprite.play(&"damage")
			await _sprite.animation_finished
			
			if _sprite.sprite_frames.has_animation(&"movement"):
				_sprite.play(&"movement")


func _die() -> void:
	set_physics_process(false)
	
	if _sprite and _sprite.sprite_frames:
		if _sprite.sprite_frames.has_animation(&"death"):
			_sprite.play(&"death")
			await _sprite.animation_finished
	
	queue_free()


func hit() -> void:
	take_damage()
