extends Label

@onready var start_button_root = $"../StartButtonRoot"

func _ready() -> void:
	if start_button_root:
		start_button_root.start_pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.finished.connect(_on_fade_finished)

func _on_fade_finished() -> void:
	hide()
