# tv_main.gd
extends Node2D

@export var scroll_speed: float = 300.0
@export var min_world_x: float = -300.0
@export var max_world_x: float = 0.0
@export var zoom_duration: float = 1.5
@export var zoom_target: Vector2 = Vector2(1.8, 1.8)
@export var zoom_position_target: Vector2 = Vector2(0.0, 0.0)
@export var crt_size_after_zoom: Vector2 = Vector2(1152.0, 648.0)
@export var crt_position_after_zoom: Vector2 = Vector2(0.0, 0.0)

# Scoring
@export var points_per_kill: int = 100
@export var points_per_wave: int = 500
@export var points_lost_escape: int = 50
@export var score_label_position: Vector2 = Vector2(20.0, 20.0)
@export var score_label_size: Vector2 = Vector2(184.0, 31.0)
@export var wave_label_size: Vector2 = Vector2(240.0, 240.0)
@export var wave_label_position: Vector2 = Vector2(-80.0, 0.0)

const WAVE_CONFIG = [
	{"max_active": 4, "health": 1, "wake_interval": 6.0},
	{"max_active": 5, "health": 1, "wake_interval": 6.0},
	{"max_active": 8, "health": 2, "wake_interval": 6.0},
	{"max_active": 10, "health": 2, "wake_interval": 6.0},
]

const BETWEEN_WAVE_DELAY: float = 3.0
const BETWEEN_BATCH_DELAY: float = 2.0

@onready var world_root: Node2D = $"WorldRoot"
@onready var start_button_root: Control = $"UI/StartButtonRoot"
@onready var player: Node2D = $"UI/Player"
@onready var crt_overlay: ColorRect = $"UI/CRTOverlay"
@onready var score_label: Label = $"UI/ScoreLabel"
@onready var wave_label: Label = $"UI/WaveLabel"
@onready var wave_banner_label: Label = $"UI/WaveBannerLabel"
@onready var popup_label: Label = $"UI/PopupLabel"
@onready var game_over_root: Control = $"UI/GameOverRoot"
@onready var game_over_score_label: Label = $"UI/GameOverRoot/ScoreLabel"
@onready var game_over_continue_button: BaseButton = $"UI/GameOverRoot/Buttons/ContinueButton"
@onready var game_over_home_button: BaseButton = $"UI/GameOverRoot/Buttons/HomeButton"

var _game_started: bool = false
var _game_over: bool = false
var _current_wave: int = 0
var _between_waves: bool = false
var _between_wave_timer: float = 0.0
var _between_batch: bool = false
var _between_batch_timer: float = 0.0
var _remaining_pool: Array = []
var _active_batch: Array = []
var _wake_timer: float = 0.0
var _batch_sleeping: Array = []
var _batch_size: int = 0
var _batch_cleared_count: int = 0
var _score: int = 0
var _wave_banner_showing: bool = false

func _ready() -> void:
	_game_started = false
	_game_over = false
	var crosshair: Texture2D = load("res://Assets/tile_0065.png")
	if crosshair:
		Input.set_custom_mouse_cursor(crosshair)
	if start_button_root and start_button_root.has_signal("start_pressed"):
		start_button_root.start_pressed.connect(_on_start_pressed)
	if score_label:
		score_label.visible = false
		_apply_score_label_layout()
	if wave_label:
		wave_label.visible = false
	if wave_banner_label:
		wave_banner_label.visible = false
	if popup_label:
		popup_label.visible = false
	if game_over_root:
		game_over_root.visible = false
	if game_over_continue_button:
		game_over_continue_button.pressed.connect(_on_game_over_continue_pressed)
	if game_over_home_button:
		game_over_home_button.pressed.connect(_on_game_over_home_pressed)

func _process(delta: float) -> void:
	if world_root == null or _game_over or not _game_started:
		return

	# World scrolling
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
			_begin_wave_with_banner(_current_wave)
		return

	# Wave banner phase: keep bats sleeping until banner ends
	if _wave_banner_showing:
		return

	# Between batch cooldown
	if _between_batch:
		_between_batch_timer -= delta
		if _between_batch_timer <= 0.0:
			_between_batch = false
			_spawn_next_batch()
		return

	# Wake sleeping bats one by one on interval
	if not _batch_sleeping.is_empty():
		_wake_timer -= delta
		if _wake_timer <= 0.0:
			_wake_timer = WAVE_CONFIG[_current_wave]["wake_interval"]
			var bat = _batch_sleeping.pop_front()
			if is_instance_valid(bat):
				bat.wake_up(WAVE_CONFIG[_current_wave]["health"])

func _get_wave_bats(wave_index: int) -> Array:
	return get_tree().get_nodes_in_group("bats").filter(
		func(b): return b.wave_number == wave_index + 1
	)

func _start_wave(wave_index: int) -> void:
	var config = WAVE_CONFIG[wave_index]
	var all_wave_bats = _get_wave_bats(wave_index)
	all_wave_bats.shuffle()
	_remaining_pool = all_wave_bats.slice(0, config["max_active"])
	_active_batch.clear()
	_batch_sleeping.clear()
	_batch_size = 0
	_batch_cleared_count = 0

	for bat in _remaining_pool:
		bat.modulate.a = 0.0
		bat.reset(config["health"])

	_update_wave_label()
	print("Wave ", wave_index + 1, " started with ", _remaining_pool.size(), " bats in pool")
	_spawn_next_batch()

func _begin_wave_with_banner(wave_index: int) -> void:
	if wave_banner_label == null:
		_start_wave(wave_index)
		return

	_wave_banner_showing = true
	wave_banner_label.visible = true
	wave_banner_label.modulate.a = 0.0
	wave_banner_label.text = "WAVE %d" % (wave_index + 1)
	wave_banner_label.offset_left = wave_label_position.x - wave_label_size.x / 2.0
	wave_banner_label.offset_top = wave_label_position.y - wave_label_size.y / 2.0
	wave_banner_label.offset_right = wave_label_position.x + wave_label_size.x / 2.0
	wave_banner_label.offset_bottom = wave_label_position.y + wave_label_size.y / 2.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(wave_banner_label, "modulate:a", 1.0, 0.35)
	tween.tween_interval(1.0)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(wave_banner_label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func():
		if wave_banner_label:
			wave_banner_label.visible = false
		_wave_banner_showing = false
		_start_wave(wave_index)
	)

func _spawn_next_batch() -> void:
	if _remaining_pool.is_empty():
		return

	var config = WAVE_CONFIG[_current_wave]
	var batch_size = min(config["max_active"], _remaining_pool.size())

	_active_batch = _remaining_pool.slice(0, batch_size)
	_remaining_pool = _remaining_pool.slice(batch_size)

	_batch_size = batch_size
	_batch_cleared_count = 0
	_batch_sleeping = _active_batch.duplicate()
	_wake_timer = 0.0

	print("Spawning batch of ", batch_size, " | pool remaining: ", _remaining_pool.size())

	for bat in _active_batch:
		bat.modulate.a = 0.0
		bat.reset(config["health"])
		if bat.bat_removed.is_connected(_on_bat_removed):
			bat.bat_removed.disconnect(_on_bat_removed)
		bat.bat_removed.connect(_on_bat_removed)
		var tween = create_tween()
		tween.tween_property(bat, "modulate:a", 1.0, 1.2)

func _on_bat_removed(was_killed: bool, bat_position: Vector2) -> void:
	_batch_cleared_count += 1

	if was_killed:
		_add_score(points_per_kill, "+" + str(points_per_kill), bat_position)
	else:
		_add_score(-points_lost_escape, "-" + str(points_lost_escape), bat_position)

	print("Bat removed: ", _batch_cleared_count, " / ", _batch_size, " | pool remaining: ", _remaining_pool.size())

	if _batch_cleared_count >= _batch_size:
		print("Batch complete")
		_active_batch.clear()
		_batch_sleeping.clear()
		if _remaining_pool.is_empty():
			print("Wave ", _current_wave + 1, " complete!")
			_on_wave_complete()
		else:
			_between_batch = true
			_between_batch_timer = BETWEEN_BATCH_DELAY

func _on_wave_complete() -> void:
	_add_score(points_per_wave, "WAVE BONUS +" + str(points_per_wave), Vector2.ZERO)
	_current_wave += 1
	if _current_wave >= WAVE_CONFIG.size():
		_show_game_over()
	else:
		_between_waves = true
		_between_wave_timer = BETWEEN_WAVE_DELAY

func _add_score(amount: int, popup_text: String, world_position: Vector2) -> void:
	_score += amount
	_score = max(_score, 0)
	_update_score_label()
	_show_popup(popup_text, world_position)

func _update_score_label() -> void:
	if score_label:
		score_label.text = "SCORE: " + str(_score)

func _apply_score_label_layout() -> void:
	if score_label == null:
		return
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.offset_right = -score_label_position.x
	score_label.offset_left = -score_label_position.x - score_label_size.x
	score_label.offset_top = score_label_position.y
	score_label.offset_bottom = score_label_position.y + score_label_size.y

func _update_wave_label() -> void:
	if wave_label:
		wave_label.text = "WAVE " + str(_current_wave + 1)

func _show_popup(text: String, world_position: Vector2) -> void:
	if popup_label == null:
		return
	popup_label.text = text
	popup_label.modulate.a = 1.0
	popup_label.visible = true

	if world_position != Vector2.ZERO:
		# Convert world position to screen position
		var camera: Camera2D = player.get_node_or_null("Camera2D")
		if camera == null:
			camera = _find_camera(player)
		if camera:
			var viewport_size = get_viewport().get_visible_rect().size
			var cam_zoom = camera.zoom
			var cam_offset = camera.global_position
			var screen_pos = (world_position - cam_offset) * cam_zoom + viewport_size * 0.5
			popup_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			popup_label.offset_left = screen_pos.x - 40.0
			popup_label.offset_top = screen_pos.y - 20.0
			popup_label.offset_right = screen_pos.x + 40.0
			popup_label.offset_bottom = screen_pos.y + 10.0
			popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		popup_label.set_anchors_preset(Control.PRESET_CENTER)
		popup_label.offset_left = -120.0
		popup_label.offset_top = -15.0
		popup_label.offset_right = 120.0
		popup_label.offset_bottom = 15.0
		popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tween = create_tween()
	tween.tween_property(popup_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): popup_label.visible = false)

func _show_score_label_with_fade() -> void:
	if score_label == null:
		return
	_apply_score_label_layout()
	score_label.visible = true
	score_label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(score_label, "modulate:a", 1.0, 0.4)


func _show_game_over() -> void:
	_game_over = true
	_game_started = false
	if start_button_root:
		start_button_root.visible = false
	if wave_label:
		wave_label.visible = false
	if popup_label:
		popup_label.visible = false
	if game_over_root:
		game_over_root.visible = true
		if game_over_score_label:
			game_over_score_label.text = "FINAL SCORE: " + str(_score)


func _on_game_over_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/tvMain.tscn")


func _on_game_over_continue_pressed() -> void:
	# Placeholder for infinite mode; user will implement.
	print("Continue (infinite mode) pressed")

func _on_start_pressed() -> void:
	_score = 0
	_update_score_label()
	if wave_label:
		wave_label.visible = true

	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera == null:
		camera = _find_camera(player)

	if camera:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "zoom", zoom_target, zoom_duration)
		tween.parallel().tween_property(camera, "position", zoom_position_target, zoom_duration)

		if crt_overlay:
			tween.parallel().tween_property(crt_overlay, "size", crt_size_after_zoom, zoom_duration)
			tween.parallel().tween_property(crt_overlay, "position", crt_position_after_zoom, zoom_duration)

		tween.tween_callback(func():
			_game_started = true
			_show_score_label_with_fade()
			_begin_wave_with_banner(_current_wave)
		)
	else:
		_game_started = true
		_show_score_label_with_fade()
		_begin_wave_with_banner(_current_wave)

func _find_camera(node: Node) -> Camera2D:
	for child in node.get_children():
		if child is Camera2D:
			return child
		var found = _find_camera(child)
		if found:
			return found
	return null
