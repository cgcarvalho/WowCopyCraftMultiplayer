class_name ArenaPreview
extends Control

var arena_id = "forest"
var floor_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = ArenaCatalog.definition(arena_id).floor
	if path != "" and ResourceLoader.exists(path):
		floor_texture = load(path)
	resized.connect(queue_redraw)
	queue_redraw()

func project(point: Vector2) -> Vector2:
	return Vector2(10, 10) + (point - ArenaNavigation.BOUNDS.position) / ArenaNavigation.BOUNDS.size * (size - Vector2(20, 20))

func _draw() -> void:
	var data = ArenaCatalog.definition(arena_id)
	draw_rect(Rect2(Vector2.ZERO, size), data.outside)
	var rect = Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_rect(rect, data.color)
	if floor_texture != null:
		draw_texture_rect(floor_texture, rect, false, Color(0.65, 0.7, 0.75))
	draw_rect(rect, data.rim, false, 1)
	for point in data.obstacles:
		draw_circle(project(point), 8, Color("29422f") if arena_id == "forest" else Color("c0b89e"))
	for point in data.spawns:
		draw_circle(project(point), 3, Color("78e6cb"))
	draw_circle(project(data.boss), 5, Color("e3a2ff"))
