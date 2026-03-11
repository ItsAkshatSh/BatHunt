extends Node2D

# Gun follows cursor with yaw (left/right) and pitch (up/down) position offset.
# Shot goes to cursor position; emit shot_at(target) for damage/hit effects.

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# Sound players
@onready var shot_sound: AudioStreamPlayer2D = $ShotSound
@onready var push_sound: AudioStreamPlayer2D = $PushSound
@onready var shell1_sound: AudioStreamPlayer2D = $Shell1Sound
@onready var shell2_sound: AudioStreamPlayer2D = $Shell2Sound
@onready var pull_sound: AudioStreamPlayer2D = $PullSound

# Base position when cursor is at center of screen (relative to player).
var _base_position: Vector2 = Vector2(42, 127)

# How far the gun can shift toward the cursor (yaw = horizontal, pitch = vertical).
@export var yaw_range: float = 80.0
@export var pitch_range: float = 40.0

# 0 = no follow, 1 = gun at cursor (clamped by range). Tune for feel.
@export var aim_strength: float = 0.5

# If set, shot_at will also try to damage/hit nodes at the target (radius in pixels).
@export var hit_radius: float = 0.0

signal shot_at(target_global_position: Vector2)

func _ready() -> void:
	if _sprite != null:
		_sprite.animation_finished.connect(_on_animation_finished)

	# Lower shotgun volume slightly
	if shot_sound:
		shot_sound.volume_db = -6


func _process(_delta: float) -> void:
	_update_aim_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_shoot()


func _update_aim_position() -> void:
	var mouse: Vector2 = get_global_mouse_position()
	var origin: Vector2 = global_position

	# Offset from "center" aim: cursor relative to gun origin.
	var delta: Vector2 = mouse - origin

	# Yaw: gun moves left/right with cursor (no vertical in yaw).
	var yaw_offset: float = delta.x * aim_strength
	yaw_offset = clampf(yaw_offset, -yaw_range, yaw_range)

	# Pitch: gun moves up/down with cursor.
	var pitch_offset: float = delta.y * aim_strength
	pitch_offset = clampf(pitch_offset, -pitch_range, pitch_range)

	position = _base_position + Vector2(yaw_offset, pitch_offset)


func _try_shoot() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(&"shoot"):
		return

	# Don't start shoot again while already shooting.
	if _sprite.animation == &"shoot":
		return

	_sprite.play(&"shoot")

	# Play shotgun blast
	if shot_sound:
		shot_sound.play()

	# Shot goes to cursor
	var target: Vector2 = get_global_mouse_position()
	shot_at.emit(target)

	# Optional damage
	if hit_radius > 0.0:
		_apply_damage_at_position(target)

	# Pump shotgun sound sequence
	var tween := create_tween()

	tween.tween_callback(func():
		if push_sound:
			push_sound.play()
	).set_delay(0.15)

	tween.tween_callback(func():
		if shell1_sound:
			shell1_sound.play()
	).set_delay(0.25)

	tween.tween_callback(func():
		if shell2_sound:
			shell2_sound.play()
	).set_delay(0.30)

	tween.tween_callback(func():
		if pull_sound:
			pull_sound.play()
	).set_delay(0.45)


func _on_animation_finished() -> void:
	if _sprite == null:
		return
	if _sprite.animation == &"shoot":
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"idle"):
			_sprite.play(&"idle")


func _apply_damage_at_position(target: Vector2) -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = hit_radius

	params.shape = circle
	params.transform = Transform2D(0.0, target)
	params.exclude = [get_parent().get_rid()]

	var results: Array[Dictionary] = space.intersect_shape(params)

	for result in results:
		var collider: Object = result.collider

		if collider is Node2D and collider.has_method("take_damage"):
			(collider as Node2D).take_damage()
		elif collider is Node2D and collider.has_method("hit"):
			(collider as Node2D).hit()
