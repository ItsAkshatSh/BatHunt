extends Node2D

@export var scroll_speed: float = 300.0
@export var min_world_x: float = -300.0
@export var max_world_x: float = 0.0

@onready var world_root: Node2D = $"WorldRoot"
@onready var start_button_root: Control = $"UI/StartButtonRoot"

var _game_started: bool = false

func _ready() -> void:
	_game_started = false

	# Set custom crosshair cursor
	var crosshair: Texture2D = load("res://Assets/tile_0065.png")
	if crosshair:
		Input.set_custom_mouse_cursor(crosshair)

	if start_button_root and start_button_root.has_signal("start_pressed"):
		start_button_root.start_pressed.connect(_on_start_pressed)

func _process(delta: float) -> void:
	if world_root == null:
		return

	if not _game_started:
		return

	var direction: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	if direction == 0.0:
		return

	world_root.position.x -= direction * scroll_speed * delta
	world_root.position.x = clampf(world_root.position.x, min_world_x, max_world_x)

func _on_start_pressed() -> void:
	_game_started = true
