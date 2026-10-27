extends Camera2D

const COMBAT_ZOOM = 0.75

func _ready() -> void:
	position = ArenaNavigation.WORLD_SIZE / 2.0
	zoom = Vector2.ONE * COMBAT_ZOOM
	position_smoothing_enabled = false
	make_current()
	force_update_scroll()
