extends CharacterBody2D

enum State { SLEEPING, FLYING, DAMAGED, DEAD }

@export var fly_speed: float = 150.0
@export var direction_change_interval: float = 0.8

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _state: State = State.SLEEPING
var _dir_timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _health: int = 1

func _ready() -> void:
	add_to_group("bats")
	_set_state(State.SLEEPING)

func _physics_process(delta: float) -> void:
	match _state:
		State.FLYING:
			_process_flying(delta)

func _process_flying(delta: float) -> void:
	_dir_timer -= delta
	if _dir_timer <= 0.0:
		_pick_new_direction()
		_dir_timer = direction_change_interval

	var collision = move_and_collide(_velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider == null:
			return
		match collider.name:
			"top":
				queue_free()
			"left", "right":
				_velocity.x = -_velocity.x

	if _sprite:
		_sprite.flip_h = _velocity.x < 0

func _pick_new_direction() -> void:
	var angle = randf_range(deg_to_rad(220), deg_to_rad(320))
	_velocity = Vector2(cos(angle), sin(angle)) * fly_speed

func wake_up(health: int) -> void:
	_health = health
	_set_state(State.FLYING)

func _set_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.SLEEPING:
			set_collision_layer_value(1, false)
			if _sprite and _sprite.sprite_frames:
				if _sprite.sprite_frames.has_animation(&"sleep"):
					_sprite.play(&"sleep")
		State.FLYING:
			set_collision_layer_value(1, true)
			_pick_new_direction()
			_dir_timer = direction_change_interval
			if _sprite and _sprite.sprite_frames:
				if _sprite.sprite_frames.has_animation(&"fly"):
					_sprite.play(&"fly")
		State.DAMAGED:
			if _sprite and _sprite.sprite_frames:
				if _sprite.sprite_frames.has_animation(&"damage"):
					_sprite.play(&"damage")
		State.DEAD:
			set_collision_layer_value(1, false)
			if _sprite and _sprite.sprite_frames:
				if _sprite.sprite_frames.has_animation(&"die"):
					_sprite.play(&"die")

func take_damage() -> void:
	if _state != State.FLYING and _state != State.DAMAGED:
		return

	_health -= 1

	if _health <= 0:
		_set_state(State.DEAD)
		if _sprite:
			await _sprite.animation_finished
		queue_free()
	else:
		_set_state(State.DAMAGED)
		if _sprite:
			await _sprite.animation_finished
		if _state != State.DEAD:
			_set_state(State.FLYING)

func hit() -> void:
	take_damage()
