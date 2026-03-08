extends ParallaxBackground

@export_range(-2000.0, 2000.0, 1.0)
var scroll_speed: float = -200.0

func _ready() -> void:
	_configure_layers_for_native_resolution()

func _configure_layers_for_native_resolution() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var viewport_size: Vector2 = viewport.get_visible_rect().size

	for child in get_children():
		if not (child is ParallaxLayer):
			continue

		var layer := child as ParallaxLayer

		for layer_child in layer.get_children():
			if not (layer_child is Sprite2D):
				continue

			var sprite := layer_child as Sprite2D
			if sprite.texture == null:
				continue

			var tex_size: Vector2 = sprite.texture.get_size()
			if tex_size.x <= 0.0 or tex_size.y <= 0.0:
				continue

			# Scale sprite up in integer steps so it at least covers the viewport
			# height while keeping pixel art crisp.
			var ideal_scale: float = (viewport_size.y / tex_size.y) * 1.5
			var scale_factor: float = ceil(ideal_scale)
			if scale_factor < 1.0:
				scale_factor = 1.0

			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.position = viewport_size / 2.0

			# Mirror exactly one drawn texture width to keep the loop seamless.
			var visible_width: float = tex_size.x * scale_factor
			layer.motion_mirroring.x = visible_width

func _process(delta: float) -> void:
	if scroll_speed == 0.0:
		return

	scroll_offset.x += scroll_speed * delta
