extends Node2D

# Gun follows cursor with yaw (left/right) and pitch (up/down) position offset.
# Shot goes to cursor position; emit shot_at(target) for damage/hit effects.
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

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

	# Shot goes to cursor: emit so damage/hit can be applied at this position.
	var target: Vector2 = get_global_mouse_position()
	shot_at.emit(target)

	# Optionally apply damage at that position (hit_radius > 0).
	if hit_radius > 0.0:
		_apply_damage_at_position(target)

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
