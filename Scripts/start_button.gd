extends Control

signal start_pressed

@onready var start_button: TextureButton = $StartButton
@onready var label: Label = $StartButton/Label
@onready var hover_sound: AudioStreamPlayer = $HoverSound

func _ready() -> void:
	# If you want this control to render behind Node2Ds, just set z_index low
	self.z_index = -1

	# Connect button signals
	if start_button:
		start_button.mouse_entered.connect(_on_start_button_mouse_entered)
		start_button.mouse_exited.connect(_on_start_button_mouse_exited)
		start_button.pressed.connect(_on_start_button_pressed)

	if label:
		label.add_theme_color_override("font_color", Color.WHITE)

func _on_start_button_mouse_entered() -> void:
	if label:
		label.add_theme_color_override("font_color", Color.BLACK)

	if hover_sound and hover_sound.stream:
		hover_sound.play()

func _on_start_button_mouse_exited() -> void:
	if label:
		label.add_theme_color_override("font_color", Color.WHITE)

func _on_start_button_pressed() -> void:
	# Fade this whole control out, then notify listeners to start the game.
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.finished.connect(_on_fade_finished)

func _on_fade_finished() -> void:
	hide()
	start_pressed.emit()
