extends Control

@onready var start_button: TextureButton = $StartButton
@onready var label: Label = $StartButton/Label
@onready var hover_sound: AudioStreamPlayer = $HoverSound

func _ready() -> void:
	if start_button:
		start_button.mouse_entered.connect(_on_start_button_mouse_entered)
		start_button.mouse_exited.connect(_on_start_button_mouse_exited)

	# Ensure initial (non-hovered) state uses black text.
	if label:
		label.add_theme_color_override("font_color", Color.BLACK)

func _on_start_button_mouse_entered() -> void:
	if label:
		label.add_theme_color_override("font_color", Color.WHITE)

	if hover_sound and hover_sound.stream:
		hover_sound.play()

func _on_start_button_mouse_exited() -> void:
	if label:
		label.add_theme_color_override("font_color", Color.BLACK)

