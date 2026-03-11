extends Node2D

@export var bat_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_bats: int = 8
@export var hide_y: float = 600.0
@export var spawn_margin: float = 120.0

var bats: Array[Bat] = []
var spawn_timer: float = 0.0


func _process(delta: float) -> void:
	if bat_scene == null:
		return

	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_try_spawn_bat()

	_cleanup_bats()


func _try_spawn_bat() -> void:
	if bats.size() >= max_bats:
		return

	var viewport := get_viewport().get_visible_rect()

	var min_x := viewport.position.x - spawn_margin
	var max_x := viewport.position.x + viewport.size.x + spawn_margin

	var spawn_y := randf_range(hide_y + 20, hide_y + 120)
	var spawn_x := randf_range(min_x, max_x)

	var bat: Bat = bat_scene.instantiate()

	add_child(bat)
	bat.global_position = Vector2(spawn_x, spawn_y)

	bats.append(bat)


func _cleanup_bats() -> void:
	for i in range(bats.size() - 1, -1, -1):

		var bat := bats[i]

		if bat == null or not is_instance_valid(bat):
			bats.remove_at(i)
			continue

		if bat.returning and bat.global_position.y > hide_y:
			bat.queue_free()
			bats.remove_at(i)
