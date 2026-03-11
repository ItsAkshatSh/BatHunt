extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Example for your ColorRect node
	$ColorRect.position = Vector2(0, 0)  # top-left corner in world space
	$ColorRect.rect_size = Vector2(800, 600)  # full screen size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
