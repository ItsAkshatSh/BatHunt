extends CanvasLayer

# The node of your player
@export var player: Node2D

func _ready() -> void:
	update_layer()

func update_layer() -> void:
	if player:
		self.layer = player.z_index - 1
