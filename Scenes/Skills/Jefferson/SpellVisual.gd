extends Node2D

# Staff gem centers in the existing 36-frame, 209px Ludo body animation.
const STAFF_POINTS = [
	Vector2(145, 61), Vector2(146, 61), Vector2(146, 61), Vector2(146, 60), Vector2(148, 50), Vector2(145, 43),
	Vector2(145, 37), Vector2(142, 33), Vector2(142, 31), Vector2(139, 29), Vector2(138, 28), Vector2(138, 27),
	Vector2(137, 26), Vector2(137, 26), Vector2(137, 25), Vector2(136, 25), Vector2(134, 27), Vector2(139, 27),
	Vector2(139, 27), Vector2(139, 26), Vector2(139, 27), Vector2(139, 28), Vector2(141, 31), Vector2(141, 34),
	Vector2(142, 39), Vector2(143, 42), Vector2(146, 50), Vector2(148, 58), Vector2(148, 59), Vector2(148, 59),
	Vector2(147, 59), Vector2(147, 59), Vector2(148, 60), Vector2(149, 58), Vector2(146, 61), Vector2(145, 61)
]

var frames: SpriteFrames
var display_positions: Dictionary = {}
var display_directions: Dictionary = {}
var fading_orbs: Array = []
var animation_time = 0.0
@onready var encounter = get_parent()

func _ready() -> void:
	frames = load("res://Art/Skills/Jefferson/LudoSpells.tres")

func active_visuals() -> bool:
	return encounter.status == "active" and encounter.boss.charCurrentLife > 0

func warning_progress() -> float:
	return clampf(1 - encounter.danger_remaining / float(encounter.WARNINGS[encounter.spell_kind]), 0, 1)

func impact_progress() -> float:
	var duration = encounter.INTERRUPT_SECONDS if encounter.visual_kind == "interrupted" else encounter.IMPACT_SECONDS
	return clampf(1 - encounter.visual_remaining / duration, 0, 1)

func frame_index(clip: String, progress: float) -> int:
	return roundi(clampf(progress, 0, 1) * maxi(0, frames.get_frame_count(clip) - 1))

func texture_for(clip: String, progress: float) -> Texture2D:
	if frames == null or not frames.has_animation(clip) or frames.get_frame_count(clip) == 0:
		return null
	return frames.get_frame_texture(clip, frame_index(clip, progress))

func loop_progress(clip: String, elapsed: float) -> float:
	return fposmod(elapsed * frames.get_animation_speed(clip) / maxi(1, frames.get_frame_count(clip)), 1)

func staff_point() -> Vector2:
	var sprite: AnimatedSprite2D = encounter.boss.get_node("AnimatedSprite2D")
	var texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var point: Vector2 = STAFF_POINTS[sprite.frame % STAFF_POINTS.size()] - texture.get_size() / 2
	if sprite.flip_h:
		point.x = -point.x
	return sprite.to_global(point)

func _process(delta: float) -> void:
	if not active_visuals():
		display_positions.clear()
		display_directions.clear()
		fading_orbs.clear()
		animation_time = 0
		queue_redraw()
		return
	animation_time += delta
	var present: Dictionary = {}
	var directions: Dictionary = {}
	for projectile in encounter.projectiles:
		var id: int = projectile["id"]
		var target: Vector2 = projectile["position"]
		var current: Vector2 = display_positions.get(id, target)
		present[id] = current.lerp(target, 1.0 - exp(-24 * delta))
		directions[id] = Vector2(projectile["velocity"]).normalized()
	for id in display_positions:
		if not present.has(id):
			fading_orbs.append({"point": display_positions[id], "direction": display_directions.get(id, Vector2.RIGHT), "remaining": 0.18})
	display_positions = present
	display_directions = directions
	for index in range(fading_orbs.size() - 1, -1, -1):
		fading_orbs[index].remaining -= delta
		if fading_orbs[index].remaining <= 0:
			fading_orbs.remove_at(index)
	queue_redraw()

func sprite(clip: String, point: Vector2, size: Vector2, progress: float, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	var texture = texture_for(clip, progress)
	if texture == null:
		return
	draw_set_transform(to_local(point), angle)
	draw_texture_rect(texture, Rect2(-size / 2, size), false, tint)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if not active_visuals():
		return
	if encounter.boss.charShield > 0 or encounter.has_runic_conductors():
		var linked = encounter.has_runic_conductors()
		var aura_tint = Color(0.8, 0.64, 1.0, 0.74) if linked else Color(1, 0.84, 0.54, 0.58)
		sprite("sigil", encounter.boss.global_position, Vector2(300, 340) * Jefferson.VISUAL_SCALE, loop_progress("sigil", animation_time), animation_time * 0.35, aura_tint)
	for conductor in encounter.conductors:
		if conductor.charCurrentLife > 0:
			var start = to_local(conductor.global_position) + Vector2(0, -20)
			var end = to_local(encounter.boss.global_position)
			draw_line(start, end, Color(0.34, 0.21, 0.52, 0.64), 7, true)
			draw_line(start, end, Color(0.91, 0.75, 1.0, 0.74), 2, true)
			for i in 3:
				var pulse = fposmod(animation_time * 1.75 + float(i) / 3, 1)
				draw_circle(start.lerp(end, pulse), 3, Color("f0cbff"))
	if encounter.danger_visible:
		draw_warning()
		var progress = warning_progress()
		sprite("charge", staff_point(), Vector2.ONE * lerpf(60, 140, progress), progress, -animation_time * 0.7, Color(1, 1, 1, 0.8))
	if encounter.visual_remaining > 0:
		var progress = impact_progress()
		var opacity = clampf(encounter.visual_remaining / 0.3, 0, 1)
		var tint = Color(1, 1, 1, opacity)
		match encounter.visual_kind:
			"rupture":
				sprite("eruption", encounter.visual_position, Vector2.ONE * encounter.AREA_RADIUS * 2.15, minf(1.0, 0.13 + progress), 0, tint)
				var center = to_local(encounter.visual_position)
				SkillFX.rim(self, center, encounter.AREA_RADIUS, Color(1, 0.47, 0.28, opacity * (1 - progress)), 8)
				for i in 6:
					var offset = Vector2.from_angle(i * TAU / 6.0)
					var bend = center + offset.rotated(0.26) * encounter.AREA_RADIUS * 0.43
					draw_polyline(PackedVector2Array([center, bend, center + offset * encounter.AREA_RADIUS * lerpf(0.47, 0.96, progress)]), Color(1, 0.45, 0.3, opacity * (1 - progress)), 2.3, true)
			"lance":
				var middle = encounter.visual_origin + encounter.visual_direction * encounter.LANCE_LENGTH / 2
				sprite("lance", middle, Vector2(encounter.LANCE_LENGTH, encounter.LANCE_RADIUS * 2), minf(1, 0.12 + progress), encounter.visual_direction.angle(), tint)
			"blink":
				sprite("sigil", encounter.visual_origin, Vector2.ONE * lerpf(270, 90, progress), progress, -progress * TAU, tint)
				sprite("sigil", encounter.visual_position, Vector2.ONE * lerpf(90, 285, progress), progress, progress * TAU, Color(0.65, 0.84, 1.0, opacity))
			"ward": sprite("sigil", encounter.visual_origin, Vector2.ONE * lerpf(200, 450, progress), progress, progress, tint)
			"bond":
				sprite("sigil", encounter.visual_position, Vector2.ONE * 260, progress, progress, tint)
				draw_arc(to_local(encounter.visual_position), 130, 0, TAU, 64, Color(1, 0.85, 0.4, opacity), 4, true)
			"spread":
				for point in encounter.visual_targets:
					sprite("eruption", point, Vector2.ONE * 190, progress, 0, Color(1, 0.55, 0.72, opacity))
			"channel":
				for point in encounter.visual_targets:
					var offset: Vector2 = point - encounter.visual_origin
					draw_line(to_local(encounter.visual_origin), to_local(encounter.visual_origin + offset * minf(progress * 5, 1)), Color(0.92, 0.72, 1.0, opacity * 0.75), 5, true)
					sprite("eruption", point, Vector2(108, 260), progress, 0, Color(0.84, 0.62, 1, opacity))
				var column = to_local(encounter.visual_origin) + Vector2(0, -150)
				SkillFX.draw_clip(self, &"cataclysm", column, Vector2(230, 375), progress, 0, tint)
			"interrupted":
				sprite("sigil", encounter.visual_origin, Vector2.ONE * lerpf(400, 70, progress), 1 - progress, -progress * 2, Color(0.65, 0.85, 1, opacity * 0.6))
		if encounter.visual_kind in ["lance", "volley", "rupture"]:
			sprite("orb", staff_point(), Vector2.ONE * lerpf(150, 20, progress), progress, 0, tint)
			if progress < 0.36:
				draw_arc(to_local(staff_point()), lerpf(11, 44, progress / 0.36), 0, TAU, 32, Color(0.92, 0.78, 1.0, 1 - progress / 0.36), 3, true)
	for projectile in encounter.projectiles:
		var point: Vector2 = display_positions.get(projectile["id"], projectile["position"])
		var direction: Vector2 = projectile["velocity"]
		var age = maxf(0, 4 - float(projectile["life"]))
		draw_line(to_local(point - direction.normalized() * 38), to_local(point), Color(0.6, 0.25, 1, 0.3), 7, true)
		# Ludo's ring occupies roughly half the cell; its core matches the hit radius.
		sprite("orb", point, Vector2.ONE * encounter.ORB_RADIUS * 4, loop_progress("orb", age), direction.angle())
	for fading in fading_orbs:
		var progress = 1 - fading.remaining / 0.18
		sprite("orb", fading.point, Vector2.ONE * lerpf(encounter.ORB_RADIUS * 4, 110, progress), progress, fading.direction.angle(), Color(1, 1, 1, 1 - progress))

func warning_label(point: Vector2, text: String, size: int, color: Color) -> void:
	var canvas_scale = maxf(0.25, absf(get_global_transform_with_canvas().get_scale().x))
	var font_size = roundi(size / canvas_scale)
	var outline = roundi(4 / canvas_scale)
	var transform_to_screen = get_global_transform_with_canvas()
	var screen_point = transform_to_screen * point
	var viewport_size = get_viewport_rect().size
	var width = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * canvas_scale
	screen_point.x = clampf(screen_point.x, 8, maxf(8, viewport_size.x - width - 8))
	screen_point.y = clampf(screen_point.y, 170, maxf(170, viewport_size.y - 145))
	point = transform_to_screen.affine_inverse() * screen_point
	draw_string_outline(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color.BLACK)
	draw_string(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_warning() -> void:
	var center = to_local(encounter.danger_position)
	var origin = to_local(encounter.danger_origin)
	var fraction = warning_progress()
	match encounter.spell_kind:
		"bond":
			sprite("sigil", encounter.danger_position, Vector2.ONE * 230, fraction, fraction, Color(1, 1, 1, 0.22))
			draw_circle(center, 130, Color(1, 0.8, 0.2, 0.15))
			draw_arc(center, 130, 0, TAU, 64, Color("ffe18e"), 4, true)
			for i in 6:
				var outward = Vector2.from_angle(i * TAU / 6)
				SkillFX.arrow(self, center + outward * 117, -outward, Color("ffe18e"))
			warning_label(center + Vector2(-80, -140), "JUNTEM-SE · DIVIDIR DANO", 15, Color("ffe18e"))
		"spread":
			var own_id = multiplayer.get_unique_id()
			var local_point = Vector2.INF
			var points: Array[Vector2] = []
			for id in encounter.mechanic_targets:
				var hero = MultiplayerManager.get_character(int(id))
				if is_instance_valid(hero) and hero.charCurrentLife > 0:
					var point = to_local(hero.global_position)
					points.append(point)
					if int(id) == own_id:
						local_point = point
					sprite("charge", hero.global_position, Vector2.ONE * 170, fraction, fraction, Color(1, 0.55, 0.7, 0.22))
					draw_circle(point, 95, Color(0.9, 0.1, 0.3, 0.16))
					SkillFX.rim(self, point, 95, Color("ffdce3") if int(id) == own_id else Color("ff6b7d"))
					for i in 6:
						var unit = Vector2.from_angle(i * TAU / 6)
						SkillFX.arrow(self, point + unit * 81, unit, Color("ffb1bb"), 2.0)
			if local_point.is_finite():
				var overlapping = 0
				for point in points:
					if point.distance_to(local_point) < 190:
						overlapping += 1
				if overlapping > 1:
					SkillFX.rim(self, local_point, 87, Color("ffc2c9"), 14)
				warning_label(local_point + Vector2(-62, -103), "AFASTE-SE · %.1fs" % encounter.danger_remaining, 15, Color("fff1f3"))
		"channel":
			sprite("sigil", encounter.danger_origin, Vector2(340, 340) * Jefferson.VISUAL_SCALE, fraction, fraction * TAU, Color(1, 1, 1, 0.4))
			draw_arc(origin, 140 * Jefferson.VISUAL_SCALE, 0, TAU * fraction, 64, Color("ffb8ff"), 6, true)
			SkillFX.draw_clip(self, &"cataclysm", origin + Vector2(0, -135), Vector2(180, 300), fraction * 0.53, 0, Color(1.0, 1.0, 1.0, 0.68))
			warning_label(origin + Vector2(-100, -Jefferson.VISUAL_HEIGHT / 2 - 10), "F · INTERROMPER CATACLISMO", 16, Color("ffe18e"))
		"rupture":
			sprite("charge", encounter.danger_position, Vector2.ONE * encounter.AREA_RADIUS * 1.8, fraction, 0, Color(1, 1, 1, 0.3))
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
			sprite("orb", encounter.danger_origin, Vector2(100, 100) * (0.5 + fraction * 0.5), fraction)
		"blink":
			sprite("sigil", encounter.danger_origin, Vector2.ONE * lerpf(210, 76, fraction), fraction, -fraction * TAU, Color(0.76, 0.58, 1, 0.69))
			sprite("sigil", encounter.danger_position, Vector2.ONE * lerpf(76, 210, fraction), fraction, fraction * TAU, Color(0.54, 0.81, 1, 0.69))
			SkillFX.rim(self, center, 85, Color(0.54, 0.81, 1, 0.7), 4, PI / 4)
		"ward":
			sprite("sigil", encounter.danger_origin, Vector2(300, 300) * Jefferson.VISUAL_SCALE * (0.6 + fraction * 0.4), fraction, fraction, Color(1, 1, 1, 0.55))
