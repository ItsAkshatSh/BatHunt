extends Node2D

@export var scroll_speed: float = 300.0
@export var min_world_x: float = -400.0
@export var max_world_x: float = 400.0

@onready var world_root: Node2D = $"WorldRoot"
@onready var start_button_root: Control = $"UI/StartButtonRoot"

func _ready() -> void:
	# Start with the game paused; only the start UI should run.
	get_tree().paused = true

	if start_button_root:
		# Allow start button script to keep processing while the tree is paused.
		start_button_root.process_mode = Node.PROCESS_MODE_ALWAYS

		if start_button_root.has_signal("start_pressed"):
			start_button_root.start_pressed.connect(_on_start_pressed)

func _process(delta: float) -> void:
	if world_root == null:
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
	# Unpause the game and let everything else run normally.
	get_tree().paused = false

