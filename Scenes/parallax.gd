extends ParallaxBackground

@export_range(-2000.0, 2000.0, 1.0)
var scroll_speed: float = -200.0



func _process(delta: float) -> void:
	if scroll_speed == 0.0:
		return

	scroll_offset.x += scroll_speed * delta
