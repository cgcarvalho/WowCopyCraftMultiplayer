extends Node2D

@export_enum("forest", "ruins", "glacier") var arena_id = "forest"
var floor_texture: Texture2D
const TREE = preload("res://Art/Decorations/Trees/Tree1.png")
const ROCK = preload("res://Art/Decorations/Rocks/Rock3.png")

func _ready() -> void:
	set_meta("arena_id", arena_id)
	var data = ArenaCatalog.definition(arena_id)
	if data.floor != "" and ResourceLoader.exists(data.floor):
		floor_texture = load(data.floor)
	if arena_id == "forest":
		for point in data.obstacles:
			add_tree(point)
		for point in [Vector2(200, 95), Vector2(515, 75), Vector2(950, 85), Vector2(1440, 110), Vector2(260, 790), Vector2(730, 795), Vector2(1410, 790)]:
			add_tree(point)
	else:
		for point in data.obstacles:
			add_rock(point, 2.8, Color("c3c0b1"))
	for point in [Vector2(80, 90), Vector2(390, 95), Vector2(1460, 90), Vector2(110, 730), Vector2(530, 740), Vector2(1370, 740)]:
		add_rock(point, 1.0 if arena_id == "forest" else 1.8, Color("a0cbd2") if arena_id == "glacier" else Color.WHITE)
	queue_redraw()

func add_tree(point: Vector2) -> void:
	var sprite = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.set_animation_speed("default", 6)
	for index in 5:
		var texture = AtlasTexture.new()
		texture.atlas = TREE
		texture.region = Rect2(32 + index * 192, 48, 128, 192)
		frames.add_frame("default", texture)
	sprite.sprite_frames = frames
	# The trunk base is 74px below the center of the original cell.
	sprite.position = point + Vector2(0, -74)
	sprite.modulate = Color("b6c5ad")
	add_child(sprite)
	sprite.play("default")

func add_rock(point: Vector2, factor: float, tint: Color) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = ROCK
	sprite.position = point + Vector2(0, -12 * factor)
	sprite.scale = Vector2.ONE * factor
	sprite.modulate = tint
	add_child(sprite)

func panel(rect: Rect2, color: Color, border: Color, width: int, radius: int) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _draw() -> void:
	var data = ArenaCatalog.definition(arena_id)
	var field = ArenaNavigation.BOUNDS
	if arena_id == "forest":
		panel(field.grow(12), Color(0.23, 0.28, 0.15, 0.45), Color(0.65, 0.63, 0.38, 0.6), 3, 28)
		panel(field, Color(0.27, 0.36, 0.20, 0.48), Color.TRANSPARENT, 0, 24)
		var path = PackedVector2Array([Vector2(100, 400), Vector2(430, 380), Vector2(780, 410), Vector2(1100, 375), Vector2(1430, 400)])
		draw_polyline(path, Color(0.52, 0.46, 0.29, 0.12), 90, true)
	else:
		draw_rect(Rect2(-1024, -1024, 3584, 2912), data.outside)
		panel(field.grow(24), Color("17242a"), data.rim, 6, 28)
		draw_rect(field, data.color)
		if floor_texture != null:
			var cell = 512.0
			var tint = Color(0.68, 0.78, 0.84) if arena_id == "glacier" else Color(0.82, 0.86, 0.88)
			for row in ceili(field.size.y / cell):
				for column in ceili(field.size.x / cell):
					var position_in_field = Vector2(column, row) * cell
					var size_in_field = Vector2.ONE * cell
					size_in_field.x = minf(cell, field.size.x - position_in_field.x)
					size_in_field.y = minf(cell, field.size.y - position_in_field.y)
					var source = Rect2(Vector2.ZERO, floor_texture.get_size() * size_in_field / cell)
					draw_texture_rect_region(floor_texture, Rect2(field.position + position_in_field, size_in_field), source, tint)
		panel(field, Color(0, 0, 0, 0.08), Color(data.rim, 0.6), 2, 0)
		# Walkways stay outside the combat boundary.
		for x in range(65, 1460, 74):
			draw_rect(Rect2(x, 92, 62, 16), Color(data.rim, 0.25))
			draw_rect(Rect2(x, 687, 62, 16), Color(data.rim, 0.25))
	for point in data.obstacles:
		draw_set_transform(point + Vector2(0, 12), 0, Vector2(1, 0.55))
		draw_circle(Vector2.ZERO, ArenaNavigation.COLLISION_RADIUS, Color(0.03, 0.05, 0.04, 0.3))
		draw_set_transform(Vector2.ZERO)
