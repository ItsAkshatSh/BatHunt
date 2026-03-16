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

# Game Over Layout
@export var game_over_title_position: Vector2 = Vector2(0.0, -100.0)
@export var game_over_score_position: Vector2 = Vector2(0.0, -40.0)
@export var go_home_button_position: Vector2 = Vector2(-100.0, 40.0)
@export var continue_button_position: Vector2 = Vector2(100.0, 40.0)
@export var infinite_label_position: Vector2 = Vector2(100.0, 75.0)

const WAVE_CONFIG = [
	{"max_active": 4, "health": 1, "wake_interval": 6.0},
	{"max_active": 5, "health": 1, "wake_interval": 6.0},
	{"max_active": 8, "health": 2, "wake_interval": 6.0},
	{"max_active": 10, "health": 2, "wake_interval": 6.0},
]

const BETWEEN_WAVE_DELAY: float = 3.0
const BETWEEN_BATCH_DELAY: float = 2.0
const FONT_PATH: String = "res://Assets/Bongo-8 Mono.ttf"
const MIN_BATCH_SIZE: int = 4

@onready var world_root: Node2D = $"WorldRoot"
@onready var start_button_root: Control = $"UI/StartButtonRoot"
@onready var player: Node2D = $"UI/Player"
@onready var crt_overlay: ColorRect = $"UI/CRTOverlay"
@onready var score_label: Label = $"UI/ScoreLabel"
@onready var wave_label: Label = $"UI/WaveLabel"
@onready var wave_banner_label: Label = $"UI/WaveBannerLabel"
@onready var popup_label: Label = $"UI/PopupLabel"
@onready var ui: CanvasLayer = $"UI"

var _game_started: bool = false
var _current_wave: int = 0
var _display_wave_number: int = 0
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
var _total_waves: int = 4
var _infinite_mode: bool = false
var _launching_wave: bool = false

var _game_over_overlay: ColorRect = null
var _game_over_container: Control = null
var _fade_overlay: ColorRect = null
var _menu_music: AudioStreamPlayer = null
var _wave_sound: AudioStreamPlayer = null

# Controls Screen
var _controls_overlay: ColorRect = null
var _controls_page1: Control = null
var _controls_page2: Control = null
var _controls_next_btn: TextureButton = null
var _controls_sliding: bool = false

# Bat Duplication
var _original_bats_node: Node = null
var _infinite_bats_template: Node = null
var _current_bats_duplicate: Node = null

func _ready() -> void:
	_game_started = false
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
	_build_fade_overlay()
	_build_game_over_screen()
	_build_controls_screen()
	_start_menu_music()
	_cache_original_bats()

# Bat Duplication
func _cache_original_bats() -> void:
	var bats = get_node_or_null("WorldRoot/Main/Bat")
	if bats:
		_original_bats_node = bats
	else:
		push_error("Could not find Bat node at WorldRoot/Main/Bat")

	var bats_inf = get_node_or_null("WorldRoot/Main/Bat_Infinite")
	if bats_inf:
		_infinite_bats_template = bats_inf
		for pos_node in _infinite_bats_template.get_children():
			for bat in pos_node.get_children():
				bat.modulate.a = 0.0
	else:
		push_error("Could not find Bat_Infinite node at WorldRoot/Main/Bat_Infinite")

func _launch_infinite_wave() -> void:
	if _launching_wave:
		return
	_launching_wave = true
	var random_config_index = randi() % WAVE_CONFIG.size()
	_current_wave = random_config_index
	_display_wave_number += 1
	await _respawn_bats(random_config_index)
	_launching_wave = false
	_begin_wave_with_banner(_current_wave)

func _respawn_bats(wave_config_index: int) -> void:
	if _infinite_bats_template == null:
		push_error("Missing _infinite_bats_template")
		return

	if _current_bats_duplicate and is_instance_valid(_current_bats_duplicate):
		_current_bats_duplicate.queue_free()
		await get_tree().process_frame

	var new_bats_root = Node2D.new()
	new_bats_root.name = "BatsDuplicate"

	for pos_node in _infinite_bats_template.get_children():
		var new_pos = Node2D.new()
		new_pos.name = pos_node.name
		new_pos.position = pos_node.position
		new_bats_root.add_child(new_pos)

		for bat in pos_node.get_children():
			var bat_packed = load(bat.scene_file_path)
			if bat_packed == null:
				continue
			var new_bat = bat_packed.instantiate()
			new_bat.name = bat.name
			new_bat.position = bat.position
			new_bat.modulate.a = 0.0
			new_bat.wave_number = bat.wave_number
			new_pos.add_child(new_bat)

	_infinite_bats_template.get_parent().add_child(new_bats_root)
	new_bats_root.global_position = _infinite_bats_template.global_position
	_current_bats_duplicate = new_bats_root

	await get_tree().process_frame
	await get_tree().process_frame

# Fade Overlay
func _build_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 100
	ui.add_child(_fade_overlay)

# Menu Music
func _start_menu_music() -> void:
	_menu_music = AudioStreamPlayer.new()
	add_child(_menu_music)
	await get_tree().process_frame
	var music = load("res://Assets/Music/Menu.ogg")
	if music:
		_menu_music.stream = music
		_menu_music.volume_db = 0.0
		_menu_music.play()

	_wave_sound = AudioStreamPlayer.new()
	add_child(_wave_sound)
	var wsound = load("res://Assets/Music/wave.wav")
	if wsound:
		_wave_sound.stream = wsound
		_wave_sound.volume_db = 0.0

# Controls Screen
func _build_controls_screen() -> void:
	_controls_overlay = ColorRect.new()
	_controls_overlay.color = Color(0.0, 0.0, 0.0, 0.85)
	_controls_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_overlay.visible = false
	_controls_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(_controls_overlay)

	var viewport_size = Vector2(1152.0, 648.0)

	_controls_page1 = _build_controls_page(
		"HOW TO MOVE",
		[
			{"image": "res://Assets/Key hints/keyboard_a.png", "text": "Move left"},
			{"image": "res://Assets/Key hints/keyboard_d.png", "text": "Move right"},
		],
		viewport_size
	)
	_controls_overlay.add_child(_controls_page1)

	_controls_page2 = _build_controls_page(
		"HOW TO HUNT",
		[
			{"image": "res://Assets/Key hints/mouse_horizontal.png", "text": "Move mouse to aim"},
			{"image": "res://Assets/Key hints/mouse_left.png", "text": "Left click to shoot"},
		],
		viewport_size
	)
	_controls_page2.position.y = viewport_size.y
	_controls_overlay.add_child(_controls_page2)

	_controls_next_btn = _make_button("NEXT", Vector2(0.0, 120.0))
	_controls_overlay.add_child(_controls_next_btn)
	_controls_next_btn.pressed.connect(_on_controls_next_pressed)

func _build_controls_page(title_text: String, hints: Array, viewport_size: Vector2) -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bongo_font = _try_load_font()

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if bongo_font:
		title.add_theme_font_override("font", bongo_font)
	title.add_theme_font_size_override("font_size", 28)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -300.0
	title.offset_right = 300.0
	title.offset_top = -120.0
	title.offset_bottom = -70.0
	page.add_child(title)

	var hint_container := HBoxContainer.new()
	hint_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_container.add_theme_constant_override("separation", 60)
	hint_container.set_anchors_preset(Control.PRESET_CENTER)
	hint_container.offset_left = -300.0
	hint_container.offset_right = 300.0
	hint_container.offset_top = -50.0
	hint_container.offset_bottom = 80.0
	page.add_child(hint_container)

	for hint in hints:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 12)
		hint_container.add_child(vbox)

		var img := TextureRect.new()
		img.texture = load(hint["image"])
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(80.0, 80.0)
		vbox.add_child(img)

		var lbl := Label.new()
		lbl.text = hint["text"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if bongo_font:
			lbl.add_theme_font_override("font", bongo_font)
		lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(lbl)

	return page

func _show_controls_screen() -> void:
	if _controls_overlay == null:
		_begin_game_after_controls()
		return

	var viewport_size = get_viewport().get_visible_rect().size
	_controls_page1.position.y = 0.0
	_controls_page2.position.y = viewport_size.y

	var lbl = _controls_next_btn.get_child(0) as Label
	if lbl:
		lbl.text = "NEXT"

	_controls_overlay.modulate.a = 0.0
	_controls_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(_controls_overlay, "modulate:a", 1.0, 0.4)

func _on_controls_next_pressed() -> void:
	if _controls_sliding:
		return
	var lbl = _controls_next_btn.get_child(0) as Label
	if lbl and lbl.text == "NEXT":
		_slide_to_page2()
	else:
		_on_controls_done()

func _slide_to_page2() -> void:
	if _controls_sliding:
		return
	_controls_sliding = true

	var viewport_size = get_viewport().get_visible_rect().size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_controls_page1, "position:y", -viewport_size.y, 0.5)
	tween.parallel().tween_property(_controls_page2, "position:y", 0.0, 0.5)
	tween.tween_callback(func():
		_controls_sliding = false
		var btn_lbl = _controls_next_btn.get_child(0) as Label
		if btn_lbl:
			btn_lbl.text = "GO HUNT"
	)

func _on_controls_done() -> void:
	# Menu Music Fade
	if _menu_music and _menu_music.playing:
		var music_tween = create_tween()
		music_tween.tween_property(_menu_music, "volume_db", -80.0, 1.0)
		music_tween.tween_callback(func(): _menu_music.stop())

	var tween = create_tween()
	tween.tween_property(_controls_overlay, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		_controls_overlay.visible = false
		_begin_game_after_controls()
		_start_game_music()
	)

func _start_game_music() -> void:
	var game_music = AudioStreamPlayer.new()
	add_child(game_music)
	var stream = load("res://Assets/Music/cave_music.ogg")
	if stream and stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if stream:
		game_music.stream = stream
		game_music.volume_db = -80.0
		game_music.play()
		var tween = create_tween()
		tween.tween_property(game_music, "volume_db", 0.0, 1.5)

func _begin_game_after_controls() -> void:
	_game_started = true
	_show_score_label_with_fade()
	_begin_wave_with_banner(_current_wave)

# Game Over Screen
func _build_game_over_screen() -> void:
	_game_over_overlay = ColorRect.new()
	_game_over_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.visible = false
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(_game_over_overlay)

	_game_over_container = Control.new()
	_game_over_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_container.visible = false
	_game_over_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_game_over_container)

	var bongo_font = _try_load_font()

	var title_label := Label.new()
	title_label.text = "GAME OVER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if bongo_font:
		title_label.add_theme_font_override("font", bongo_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.offset_left = game_over_title_position.x - 200.0
	title_label.offset_right = game_over_title_position.x + 200.0
	title_label.offset_top = game_over_title_position.y - 25.0
	title_label.offset_bottom = game_over_title_position.y + 25.0
	_game_over_container.add_child(title_label)

	var final_score_label := Label.new()
	final_score_label.name = "FinalScoreLabel"
	final_score_label.text = "SCORE: 0"
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if bongo_font:
		final_score_label.add_theme_font_override("font", bongo_font)
	final_score_label.add_theme_font_size_override("font_size", 24)
	final_score_label.set_anchors_preset(Control.PRESET_CENTER)
	final_score_label.offset_left = game_over_score_position.x - 200.0
	final_score_label.offset_right = game_over_score_position.x + 200.0
	final_score_label.offset_top = game_over_score_position.y - 20.0
	final_score_label.offset_bottom = game_over_score_position.y + 20.0
	_game_over_container.add_child(final_score_label)

	var home_btn := _make_button("GO HOME", go_home_button_position)
	_game_over_container.add_child(home_btn)
	home_btn.pressed.connect(_on_go_home_pressed)

	var continue_btn := _make_button("CONTINUE", continue_button_position)
	_game_over_container.add_child(continue_btn)
	continue_btn.pressed.connect(_on_continue_pressed)

	var infinite_label := Label.new()
	infinite_label.text = "(Infinite mode)"
	infinite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infinite_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	if bongo_font:
		infinite_label.add_theme_font_override("font", bongo_font)
	infinite_label.add_theme_font_size_override("font_size", 11)
	infinite_label.set_anchors_preset(Control.PRESET_CENTER)
	infinite_label.offset_left = infinite_label_position.x - 100.0
	infinite_label.offset_right = infinite_label_position.x + 100.0
	infinite_label.offset_top = infinite_label_position.y - 10.0
	infinite_label.offset_bottom = infinite_label_position.y + 10.0
	_game_over_container.add_child(infinite_label)

func _make_button(label_text: String, center_position: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load("res://Assets/button_rectangle_depth_flat.png")
	btn.texture_hover = load("res://Assets/button_rectangle_depth_border.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE

	var btn_width: float = 160.0
	var btn_height: float = 50.0
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.offset_left = center_position.x - btn_width / 2.0
	btn.offset_right = center_position.x + btn_width / 2.0
	btn.offset_top = center_position.y - btn_height / 2.0
	btn.offset_bottom = center_position.y + btn_height / 2.0

	var lbl := Label.new()
	lbl.text = label_text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	var bongo_font = _try_load_font()
	if bongo_font:
		lbl.add_theme_font_override("font", bongo_font)
	btn.add_child(lbl)

	var hover_sound := AudioStreamPlayer.new()
	var click_sound = load("res://Assets/click-b.ogg")
	if click_sound:
		hover_sound.stream = click_sound
		hover_sound.volume_db = -6.0
	btn.add_child(hover_sound)
	btn.mouse_entered.connect(func():
		if hover_sound.stream:
			hover_sound.play()
	)

	return btn

func _try_load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	return null

func _show_game_over() -> void:
	_game_started = false

	if _game_over_container:
		var final_score_label = _game_over_container.get_node_or_null("FinalScoreLabel")
		if final_score_label:
			final_score_label.text = "SCORE: " + str(_score)

	if _game_over_overlay:
		_game_over_overlay.modulate.a = 0.0
		_game_over_overlay.visible = true
		var tween = create_tween()
		tween.tween_property(_game_over_overlay, "modulate:a", 1.0, 0.6)
		tween.tween_callback(func():
			if _game_over_container:
				_game_over_container.modulate.a = 0.0
				_game_over_container.visible = true
				var tween2 = create_tween()
				tween2.tween_property(_game_over_container, "modulate:a", 1.0, 0.4)
		)

# Go Home
func _on_go_home_pressed() -> void:
	if _fade_overlay:
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		var tween = create_tween()
		tween.tween_property(_fade_overlay, "color:a", 1.0, 0.8)
		tween.tween_callback(func(): get_tree().reload_current_scene())

# Infinite Mode
func _on_continue_pressed() -> void:
	if _game_over_overlay:
		_game_over_overlay.visible = false
	if _game_over_container:
		_game_over_container.visible = false
	if _original_bats_node:
		_original_bats_node.visible = false
	_infinite_mode = true
	_game_started = true
	_between_waves = false
	_between_batch = false
	_wave_banner_showing = false
	_launching_wave = false
	_launch_infinite_wave()

func _process(delta: float) -> void:
	if world_root == null or not _game_started:
		return

	var direction: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	if direction != 0.0:
		world_root.position.x -= direction * scroll_speed * delta
		world_root.position.x = clampf(world_root.position.x, min_world_x, max_world_x)

	if _between_waves:
		_between_wave_timer -= delta
		if _between_wave_timer <= 0.0:
			_between_waves = false
			if _infinite_mode:
				_launch_infinite_wave()
			else:
				_begin_wave_with_banner(_current_wave)
		return

	if _wave_banner_showing:
		return

	if _between_batch:
		_between_batch_timer -= delta
		if _between_batch_timer <= 0.0:
			_between_batch = false
			_spawn_next_batch()
		return

	if not _batch_sleeping.is_empty():
		_wake_timer -= delta
		if _wake_timer <= 0.0:
			_wake_timer = WAVE_CONFIG[_current_wave]["wake_interval"]
			var bat = _batch_sleeping.pop_front()
			if is_instance_valid(bat):
				bat.wake_up(WAVE_CONFIG[_current_wave]["health"])

func _get_wave_bats(wave_index: int) -> Array:
	if _infinite_mode:
		return get_tree().get_nodes_in_group("bats").filter(
			func(b): return b.wave_number == wave_index + 1
		)
	else:
		return get_tree().get_nodes_in_group("bats").filter(
			func(b): return b.wave_number == wave_index + 1 and _original_bats_node.is_ancestor_of(b)
		)

func _start_wave(wave_index: int) -> void:
	var config = WAVE_CONFIG[wave_index]
	var all_wave_bats = _get_wave_bats(wave_index)
	all_wave_bats.shuffle()

	var seen_positions = {}
	var unique_bats = []
	for bat in all_wave_bats:
		var pos_key = bat.get_parent().name
		if not seen_positions.has(pos_key):
			seen_positions[pos_key] = true
			unique_bats.append(bat)

	var pool_size = max(config["max_active"], MIN_BATCH_SIZE)
	_remaining_pool = unique_bats.slice(0, pool_size)
	_active_batch.clear()
	_batch_sleeping.clear()
	_batch_size = 0
	_batch_cleared_count = 0

	for bat in _remaining_pool:
		bat.modulate.a = 1.0
		bat.visible = true
		bat.reset(config["health"])

	_update_wave_label()
	_spawn_next_batch()

# Wave Banner
func _begin_wave_with_banner(wave_index: int) -> void:
	if wave_banner_label == null:
		_start_wave(wave_index)
		return

	_wave_banner_showing = true
	wave_banner_label.visible = true
	wave_banner_label.modulate.a = 0.0
	wave_banner_label.text = "WAVE %d" % _display_wave_number
	wave_banner_label.offset_left = wave_label_position.x - wave_label_size.x / 2.0
	wave_banner_label.offset_top = wave_label_position.y - wave_label_size.y / 2.0
	wave_banner_label.offset_right = wave_label_position.x + wave_label_size.x / 2.0
	wave_banner_label.offset_bottom = wave_label_position.y + wave_label_size.y / 2.0

	if _wave_sound and _wave_sound.stream:
		_wave_sound.play()

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
	var batch_size = max(min(config["max_active"], _remaining_pool.size()), min(MIN_BATCH_SIZE, _remaining_pool.size()))

	_active_batch = _remaining_pool.slice(0, batch_size)
	_remaining_pool = _remaining_pool.slice(batch_size)

	_batch_size = batch_size
	_batch_cleared_count = 0
	_batch_sleeping = _active_batch.duplicate()
	_wake_timer = 0.0

	for bat in _active_batch:
		bat.modulate.a = 0.0
		bat.visible = true
		bat.reset(WAVE_CONFIG[_current_wave]["health"])
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

	if _batch_cleared_count >= _batch_size:
		_active_batch.clear()
		_batch_sleeping.clear()
		if _remaining_pool.is_empty():
			_on_wave_complete()
		else:
			_between_batch = true
			_between_batch_timer = BETWEEN_BATCH_DELAY

func _on_wave_complete() -> void:
	_add_score(points_per_wave, "WAVE BONUS +" + str(points_per_wave), Vector2.ZERO)

	if _infinite_mode:
		_between_waves = true
		_between_wave_timer = BETWEEN_WAVE_DELAY
		return

	var next_wave = _current_wave + 1
	if next_wave >= _total_waves:
		await get_tree().create_timer(1.8).timeout
		_show_game_over()
		return

	_current_wave = next_wave
	_display_wave_number = next_wave + 1
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
		wave_label.text = "WAVE " + str(_display_wave_number)

func _show_popup(text: String, world_position: Vector2) -> void:
	if popup_label == null:
		return
	popup_label.text = text
	popup_label.modulate.a = 1.0
	popup_label.visible = true

	if world_position != Vector2.ZERO:
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

func _on_start_pressed() -> void:
	_score = 0
	_display_wave_number = 1
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
			_show_controls_screen()
		)
	else:
		_show_controls_screen()

func _find_camera(node: Node) -> Camera2D:
	for child in node.get_children():
		if child is Camera2D:
			return child
		var found = _find_camera(child)
		if found:
			return found
	return null
