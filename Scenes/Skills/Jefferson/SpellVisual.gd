extends Node2D

var atlas: Texture2D
var display_positions: Dictionary = {}
var animation_time = 0.0
@onready var encounter = get_parent()

func _ready() -> void:
	atlas = load("res://Art/Skills/Jefferson/SpellAtlas.png")

func _process(delta: float) -> void:
	animation_time += delta
	var present: Dictionary = {}
	for projectile in encounter.projectiles:
		var id: int = projectile["id"]
		var target: Vector2 = projectile["position"]
		var current: Vector2 = display_positions.get(id, target)
		present[id] = current.lerp(target, 1.0 - exp(-24 * delta))
	display_positions = present
	queue_redraw()

func sprite(row: int, point: Vector2, size: Vector2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	if atlas == null:
		return
	var cell = Vector2(atlas.get_width() / 4.0, atlas.get_height() / 4.0)
	var frame = int(animation_time * 10) % 4
	draw_set_transform(to_local(point), angle)
	draw_texture_rect_region(atlas, Rect2(-size / 2, size), Rect2(Vector2(frame * cell.x, row * cell.y), cell), tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if encounter.status != "active":
		return
	if encounter.boss.charShield > 0:
		sprite(3, encounter.boss.global_position, Vector2(300, 300), animation_time * 0.4)
	if encounter.danger_visible:
		draw_warning()
	if encounter.visual_remaining > 0:
		var opacity = clampf(encounter.visual_remaining / 0.3, 0, 1)
		var tint = Color(1, 1, 1, opacity)
		match encounter.visual_kind:
			"rupture": sprite(2, encounter.visual_position, Vector2(290, 290), 0, tint)
			"lance":
				var middle = encounter.visual_origin + encounter.visual_direction * encounter.LANCE_LENGTH / 2
				sprite(1, middle, Vector2(encounter.LANCE_LENGTH, 125), encounter.visual_direction.angle(), tint)
			"blink":
				sprite(3, encounter.visual_origin, Vector2(220, 220), -animation_time, tint)
				sprite(3, encounter.visual_position, Vector2(240, 240), animation_time, tint)
	for projectile in encounter.projectiles:
		var point: Vector2 = display_positions.get(projectile["id"], projectile["position"])
		var direction: Vector2 = projectile["velocity"]
		sprite(0, point, Vector2(108, 108), direction.angle())

func draw_warning() -> void:
	var center = to_local(encounter.danger_position)
	var origin = to_local(encounter.danger_origin)
	var fraction = clampf(1.0 - encounter.danger_remaining / float(encounter.WARNINGS[encounter.spell_kind]), 0, 1)
	match encounter.spell_kind:
		"bond":
			draw_circle(center, 130, Color(1, 0.8, 0.2, 0.15))
			draw_arc(center, 130, 0, TAU, 64, Color("ffe18e"), 4, true)
			draw_string_outline(ThemeDB.fallback_font, center + Vector2(-80, -140), "JUNTEM-SE · DIVIDIR DANO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
			draw_string(ThemeDB.fallback_font, center + Vector2(-80, -140), "JUNTEM-SE · DIVIDIR DANO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe18e"))
		"spread":
			for id in encounter.mechanic_targets:
				var hero = MultiplayerManager.get_character(int(id))
				if is_instance_valid(hero) and hero.charCurrentLife > 0:
					var point = to_local(hero.global_position)
					draw_circle(point, 95, Color(0.9, 0.1, 0.3, 0.16))
					draw_arc(point, 95, 0, TAU, 48, Color("ff6b7d"), 3, true)
					draw_string_outline(ThemeDB.fallback_font, point + Vector2(-35, -105), "AFASTE-SE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
					draw_string(ThemeDB.fallback_font, point + Vector2(-35, -105), "AFASTE-SE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ff97a3"))
		"channel":
			draw_arc(origin, 140, 0, TAU * fraction, 64, Color("ffb8ff"), 6, true)
			sprite(3, encounter.danger_origin, Vector2(340, 340), animation_time)
			draw_string_outline(ThemeDB.fallback_font, origin + Vector2(-100, -190), "F · INTERROMPER CATACLISMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(ThemeDB.fallback_font, origin + Vector2(-100, -190), "F · INTERROMPER CATACLISMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe18e"))
		"rupture":
			draw_circle(center, encounter.AREA_RADIUS, Color(0.8, 0.08, 0.2, 0.25))
			draw_arc(center, encounter.AREA_RADIUS, 0, TAU, 64, Color(1, 0.25, 0.1), 4, true)
			draw_arc(center, encounter.AREA_RADIUS - 8, -PI / 2, -PI / 2 + TAU * fraction, 64, Color.YELLOW, 5, true)
		"lance":
			var end = origin + encounter.danger_direction * encounter.LANCE_LENGTH
			var normal = encounter.danger_direction.orthogonal() * encounter.LANCE_RADIUS
			draw_line(origin, end, Color(0.1, 0.6, 1, 0.25), encounter.LANCE_RADIUS * 2, true)
			draw_line(origin + normal, end + normal, Color.CYAN, 2, true)
			draw_line(origin - normal, end - normal, Color.CYAN, 2, true)
			draw_line(origin, origin.lerp(end, fraction), Color(0.8, 0.9, 1, 0.7), 3, true)
		"volley":
			var angles = [-0.28, 0, 0.28] if encounter.phase == 1 else [-0.44, -0.22, 0, 0.22, 0.44]
			for angle in angles:
				var direction = encounter.danger_direction.rotated(angle)
				draw_line(origin + direction * 80, origin + direction * 350, Color(0.8, 0.3, 1, 0.35), 3, true)
			sprite(0, encounter.danger_origin, Vector2(100, 100) * (0.5 + fraction * 0.5))
		"blink":
			sprite(3, encounter.danger_origin, Vector2(190, 190), animation_time)
			sprite(3, encounter.danger_position, Vector2(220, 220), -animation_time)
			draw_arc(center, 85, 0, TAU, 64, Color(0.6, 0.3, 1, 0.7), 2, true)
		"ward":
			sprite(3, encounter.danger_origin, Vector2(300, 300) * (0.6 + fraction * 0.4), animation_time)
