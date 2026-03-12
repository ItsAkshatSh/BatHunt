extends Node2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var shot_sound: AudioStreamPlayer2D = $ShotSound
@onready var push_sound: AudioStreamPlayer2D = $PushSound
@onready var shell1_sound: AudioStreamPlayer2D = $Shell1Sound
@onready var shell2_sound: AudioStreamPlayer2D = $Shell2Sound
@onready var pull_sound: AudioStreamPlayer2D = $PullSound

var _base_position: Vector2 = Vector2(42, 127)

@export var yaw_range: float = 80.0
@export var pitch_range: float = 40.0
@export var aim_strength: float = 0.5
@export var hit_radius: float = 32.0

var _can_shoot: bool = true

signal shot_at(target_global_position: Vector2)

func _ready() -> void:
	if _sprite != null:
		_sprite.animation_finished.connect(_on_animation_finished)
	if shot_sound:
		shot_sound.volume_db = -6

func _get_scaled_mouse_pos() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()

func _process(_delta: float) -> void:
	_update_aim_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_shoot()

func _update_aim_position() -> void:
	var mouse: Vector2 = _get_scaled_mouse_pos()
	var origin: Vector2 = global_position
	var delta: Vector2 = mouse - origin

	var yaw_offset: float = clampf(delta.x * aim_strength, -yaw_range, yaw_range)
	var pitch_offset: float = clampf(delta.y * aim_strength, -pitch_range, pitch_range)

	position = _base_position + Vector2(yaw_offset, pitch_offset)

func _try_shoot() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(&"shoot"):
		return
	if not _can_shoot:
		return

	_can_shoot = false
	_sprite.play(&"shoot")

	if shot_sound:
		shot_sound.play()

	var target: Vector2 = _get_scaled_mouse_pos()
	shot_at.emit(target)
	_apply_damage_at_position(target)

	var tween := create_tween()
	tween.tween_callback(func():
		if push_sound: push_sound.play()
	).set_delay(0.15)
	tween.tween_callback(func():
		if shell1_sound: shell1_sound.play()
	).set_delay(0.25)
	tween.tween_callback(func():
		if shell2_sound: shell2_sound.play()
	).set_delay(0.30)
	tween.tween_callback(func():
		if pull_sound: pull_sound.play()
	).set_delay(0.45)

func _on_animation_finished() -> void:
	if _sprite == null:
		return
	if _sprite.animation == &"shoot":
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"idle"):
			_sprite.play(&"idle")
			_can_shoot = true

func _apply_damage_at_position(target: Vector2) -> void:
	for bat in get_tree().get_nodes_in_group("bats"):
		if not bat is Node2D:
			continue
		if bat._state != bat.State.FLYING and bat._state != bat.State.DAMAGED:
			continue

		var bat_node := bat as Node2D
		var dist = target.distance_to(bat_node.global_position)
		print("mouse target: ", target, " | bat global_pos: ", bat_node.global_position, " | dist: ", dist, " | hit_radius: ", hit_radius)

		if dist <= hit_radius:
			if bat.has_method("take_damage"):
				bat.take_damage()
			break
