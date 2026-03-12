# tv_main.gd
extends Node2D

@export var scroll_speed: float = 300.0
@export var min_world_x: float = -300.0
@export var max_world_x: float = 0.0
@export var bat_scene: PackedScene

const WAVE_CONFIG = [
	{"max_active": 4, "health": 1, "wake_interval": 6.0},
	{"max_active": 5, "health": 1, "wake_interval": 6.0},
	{"max_active": 8, "health": 2, "wake_interval": 6.0},
	{"max_active": 10, "health": 2, "wake_interval": 6.0},
]

const BETWEEN_WAVE_DELAY: float = 3.0

@onready var world_root: Node2D = $"WorldRoot"
@onready var start_button_root: Control = $"UI/StartButtonRoot"

var _game_started: bool = false
var _wake_timer: float = 0.0
var _current_wave: int = 0
var _woken_count: int = 0
var _total_bats: int = 0
var _between_waves: bool = false
var _between_wave_timer: float = 0.0

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

	# Between waves cooldown
	if _between_waves:
		_between_wave_timer -= delta
		if _between_wave_timer <= 0.0:
			_between_waves = false
			_start_wave(_current_wave)
		return

	var config = WAVE_CONFIG[_current_wave]

	# Check wave complete — all bats woken and none active
	if _woken_count >= _total_bats:
		var active = get_tree().get_nodes_in_group("bats").filter(
			func(b): return b._state == b.State.FLYING or b._state == b.State.DAMAGED
		)
		if active.is_empty():
			_on_wave_complete()
			return

	# Wake bats on interval
	_wake_timer -= delta
	if _wake_timer <= 0.0:
		_wake_timer = config["wake_interval"]
		_try_wake_bat(config)

func _start_wave(wave_index: int) -> void:
	_woken_count = 0
	_wake_timer = 0.0

	var all_bats = get_tree().get_nodes_in_group("bats")
	_total_bats = all_bats.size()

	for bat in all_bats:
		if bat.has_method("reset"):
			bat.reset(WAVE_CONFIG[wave_index]["health"])

func _try_wake_bat(config: Dictionary) -> void:
	var active = get_tree().get_nodes_in_group("bats").filter(
		func(b): return b._state == b.State.FLYING or b._state == b.State.DAMAGED
	)
	if active.size() >= config["max_active"]:
		return

	var sleeping = get_tree().get_nodes_in_group("bats").filter(
		func(b): return b._state == b.State.SLEEPING
	)
	if sleeping.is_empty():
		return

	var bat = sleeping[randi() % sleeping.size()]
	var spawn_pos: Vector2 = bat.global_position

	bat.wake_up(config["health"])
	_woken_count += 1

	if bat_scene == null:
		return

	var replacement = bat_scene.instantiate()
	replacement.global_position = spawn_pos
	replacement.modulate.a = 0.0
	bat.get_parent().add_child(replacement)

	var tween = create_tween()
	tween.tween_property(replacement, "modulate:a", 1.0, 1.2)

func _on_wave_complete() -> void:
	_current_wave = (_current_wave + 1) % WAVE_CONFIG.size()
	_between_waves = true
	_between_wave_timer = BETWEEN_WAVE_DELAY

func _on_start_pressed() -> void:
	_game_started = true
	_start_wave(_current_wave)
