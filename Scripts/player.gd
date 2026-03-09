extends CharacterBody2D

# Player body is stationary; world/camera movement is handled externally
# (e.g. in tvMain). This script is kept minimal for future extension.

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO
