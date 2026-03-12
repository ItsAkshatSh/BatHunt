# tv_main.gd
extends Node2D

@export var scroll_speed: float = 300.0
@export var min_world_x: float = -300.0
@export var max_world_x: float = 0.0
@export var bat_scene: PackedScene

# Wave settings: [bats_to_wake, health_per_bat, wake_interval]
const WAVE_CONFIG = [
	{"max_active": 4, "health": 1, "wake_interval": 3.0},  # Wave 1
	{"max_active": 5, "health": 1, "wake_interval": 2.5},  # Wave 2
	{"max_active": 8, "health": 2, "wake_interval": 2.5},  # Wave 3
	{"max_active": 10, "health": 2, "wake_interval": 2.0}, # Wave 4
]

@onready var world_root: Node2D = $"WorldRoot"
@onready var start_button_root: Control = $"UI/StartButtonRoot"

var _game_started: bool = false
var _wake_timer: float = 0.0
var _current_wave: int = 0  # 0-indexed

func _ready() -> void:
	_game_started = false
	var crosshair: Texture2D = load("res://Assets/tile_0065.png")
	if crosshair:
		Input.set_custom_mouse_cursor(crosshair)
	if start_button_root and start_button_root.has_signal("start_pressed"):
		start_button_root.start_pressed.connect(_on_start_pressed)

func _process(delta: float) -> void:
	if world_root == null or not _game_started:
		return

	# Scrolling
	var direction: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	if direction != 0.0:
		world_root.position.x -= direction * scroll_speed * delta
		world_root.position.x = clampf(world_root.position.x, min_world_x, max_world_x)

	# Coordinator
	var config = WAVE_CONFIG[_current_wave]
	_wake_timer -= delta
	if _wake_timer <= 0.0:
		_wake_timer = config["wake_interval"]
		_try_wake_bat(config)

func _try_wake_bat(config: Dictionary) -> void:
	# Count currently flying/damaged bats
	var active = get_tree().get_nodes_in_group("bats").filter(
		func(b): return b._state == b.State.FLYING or b._state == b.State.DAMAGED
	)
	if active.size() >= config["max_active"]:
		return

	# Pick a random sleeping bat
	var sleeping = get_tree().get_nodes_in_group("bats").filter(
		func(b): return b._state == b.State.SLEEPING
	)
	if sleeping.is_empty():
		return

	var bat = sleeping[randi() % sleeping.size()]
	var spawn_pos: Vector2 = bat.global_position

	# Wake it with the wave's health value
	bat.wake_up(config["health"])

	# Spawn faded replacement at same position
	if bat_scene == null:
		return

	var replacement = bat_scene.instantiate()
	replacement.global_position = spawn_pos
	replacement.modulate.a = 0.0
	bat.get_parent().add_child(replacement)

	var tween = create_tween()
	tween.tween_property(replacement, "modulate:a", 1.0, 1.2)

func advance_wave() -> void:
	if _current_wave < WAVE_CONFIG.size() - 1:
		_current_wave += 1

func _on_start_pressed() -> void:
	_game_started = true
