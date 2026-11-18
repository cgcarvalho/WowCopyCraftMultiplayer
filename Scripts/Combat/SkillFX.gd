class_name SkillFX
extends Node2D

# Sprites are cosmetics. The server still decides every hit and each world
# effect uses the point supplied by the combat code.
const ART_PATH = "res://Art/Skills/Ludo/SkillClips.tres"
const COLORS = {
	&"reap": Color("c096ff"), &"heal": Color("ffeeb0"),
	&"dawn": Color("ffea97"), &"shield": Color("9fe9ff"),
	&"hammer": Color("ffdc78"), &"poison": Color("a9e76d"),
	&"wind": Color("e3f6ff"), &"slash": Color("ffd2a0"),
	&"bolt": Color("be94fa"), &"spark": Color("ffbd73"),
	&"coil": Color("ffbc71"), &"valve": Color("ffe6be"),
	&"rune": Color("e5b8ff"), &"interrupt": Color("95ecff")
}

static var library: SpriteFrames
static var checked_library = false
var clip: StringName
var initial_point: Vector2
var opacity = 1.0
var lifetime = 0.5
var age = 0.0
var diameter = 80.0
var direction = 0.0
var accents = 0

static func frames() -> SpriteFrames:
	if not checked_library:
		checked_library = true
		if ResourceLoader.exists(ART_PATH):
			library = load(ART_PATH)
	return library

static func draw_clip(canvas: CanvasItem, id: StringName, point: Vector2, size: Vector2, progress: float, turn: float = 0.0, color: Color = Color.WHITE) -> bool:
	var atlas = frames()
	if not atlas or not atlas.has_animation(id) or atlas.get_frame_count(id) == 0:
		return false
	var count = atlas.get_frame_count(id)
	var frame = clampi(floori(progress * count), 0, count - 1)
	var texture = atlas.get_frame_texture(id, frame)
	canvas.draw_set_transform(point, turn)
	canvas.draw_texture_rect(texture, Rect2(-size * 0.5, size), false, color)
	canvas.draw_set_transform(Vector2.ZERO)
	return true

static func install_pose(body: AnimatedSprite2D, id: StringName) -> bool:
	var atlas = frames()
	if not atlas or not atlas.has_animation(id):
		return false
	if body.sprite_frames.has_animation(id):
		return true
	body.sprite_frames = body.sprite_frames.duplicate()
	body.sprite_frames.add_animation(id)
	body.sprite_frames.set_animation_loop(id, atlas.get_animation_loop(id))
	body.sprite_frames.set_animation_speed(id, atlas.get_animation_speed(id))
	for index in atlas.get_frame_count(id):
		body.sprite_frames.add_frame(id, atlas.get_frame_texture(id, index))
	return true

static func rim(canvas: CanvasItem, point: Vector2, radius: float, tint: Color, marks: int = 0, turn: float = 0.0) -> void:
	canvas.draw_arc(point, radius, 0, TAU, 64, tint, 2.5, true)
	for i in marks:
		var unit = Vector2.from_angle(turn + i * TAU / marks)
		canvas.draw_line(point + unit * (radius - 8), point + unit * (radius + 2), tint, 2.5, true)

static func arrow(canvas: CanvasItem, point: Vector2, unit: Vector2, color: Color, width: float = 3.0) -> void:
	var tip = point + unit * 12
	var normal = unit.orthogonal() * 7
	canvas.draw_polyline(PackedVector2Array([point + normal, tip, point - normal]), color, width, true)

static func volley_point(index: int, radius: float) -> Vector2:
	return Vector2.from_angle(index * 2.39996) * radius * sqrt((index + 0.5) / 8.0) * 0.89

func configure(id: StringName, point: Vector2, alpha: float, size: float, turn: float, marks: int) -> void:
	clip = id
	initial_point = point
	opacity = alpha
	diameter = size
	direction = turn
	accents = marks
	lifetime = 0.72 if id in [&"heal", &"dawn", &"reap", &"rune"] else 0.38
	z_index = 1 if id in [&"arrow_rain", &"consecration", &"coil", &"bladestorm"] else 3

func _ready() -> void:
	global_position = initial_point

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var p = clampf(age / lifetime, 0.0, 1.0)
	var radius = diameter * 0.5
	var fade = (1.0 - smoothstep(0.5, 1.0, p)) * opacity
	var warm: Color = COLORS.get(clip, Color.WHITE)
	var col = Color(warm, fade)
	var point = Vector2.ZERO
	var size = Vector2.ONE * diameter
	match clip:
		&"pierce":
			var unit = Vector2.from_angle(direction)
			var color = Color(0.83, 1.0, 0.76, fade)
			draw_line(-unit * radius, unit * radius, color, 3.5, true)
			arrow(self, unit * radius * 0.85, unit, color)
			return
		&"arrow_rain":
			for i in 8:
				var point_on_floor = volley_point(i, radius)
				rim(self, point_on_floor, lerpf(4, 27, p), Color(0.76, 1, 0.72, fade * 0.73))
			return
		&"coil", &"consecration", &"bladestorm":
			var pulse = lerpf(radius * 0.42, radius, smoothstep(0, 0.72, p))
			var pulse_color = Color("ffbe7a") if clip != &"consecration" else Color("ffe794")
			rim(self, point, pulse, Color(pulse_color, fade * 0.86), 12, p)
			return
		&"hammer_seal":
			rim(self, point, radius * lerpf(0.42, 1.0, p), Color(1.0, 0.85, 0.53, fade), 4, PI / 4)
			draw_line(Vector2(0, -18), Vector2(0, 18), col, 3, true)
			draw_line(Vector2(-12, -5), Vector2(12, -5), col, 3, true)
			return
		&"link":
			draw_line(Vector2.ZERO, Vector2.from_angle(direction) * diameter, Color(1, 0.82, 0.42, fade), 3, true)
			return
		&"fork":
			for i in clampi(accents, 1, 2):
				arrow(self, Vector2.ZERO, Vector2.from_angle(direction + (i - 0.5) * 0.65), Color(0.79, 1.0, 0.73, fade), 4)
			return
		&"heal", &"dawn":
			point.y = -diameter * (0.34 + p * 0.12)
			size = Vector2(diameter * 0.82, diameter * 1.12)
			rim(self, Vector2.ZERO, radius * lerpf(0.25, 0.85, p), Color(warm, fade * 0.7), 4, PI / 4)
			if clip == &"dawn":
				for side in [-1, 1]:
					draw_clip(self, &"heal", point + Vector2(side * radius * 0.69, radius * 0.24), size * 0.68, p, side * 0.14, Color(1, 1, 1, fade * 0.55))
		&"reap":
			for i in clampi(accents, 0, 4):
				var angle = i * TAU / maxi(1, accents) + 0.5 + p * 1.7
				var reach = lerpf(radius, 7, smoothstep(0, 0.63, p))
				var end = Vector2.from_angle(angle) * reach
				var bend = end.rotated(-0.55) * 0.55
				draw_polyline(PackedVector2Array([end, bend, Vector2.ZERO]), col, 4 - p * 2, true)
		&"curse":
			var distance = radius * lerpf(0.35, 1.0, p)
			var purple = Color(0.82, 0.64, 1.0, fade)
			var left = Vector2(-distance * 0.68, 0)
			var right = -left
			draw_polyline(PackedVector2Array([Vector2(0, -distance), right, Vector2(0, distance), left, Vector2(0, -distance)]), purple, 2.5, true)
			draw_polyline(PackedVector2Array([Vector2(4, -distance * 0.7), Vector2(-7, -3), Vector2(6, 5), Vector2(-3, distance * 0.72)]), purple, 2.5, true)
			return
		&"corruption":
			var stain = Color(0.61, 0.31, 0.89, fade * 0.8)
			for i in 6:
				var blot = Vector2.from_angle(i * 2.39996) * radius * lerpf(0.12, 0.8, p) * (i + 3) / 8.0
				draw_circle(blot, 9 * (1 - p * 0.7), stain)
			return
		&"shield":
			var r = lerpf(radius, radius * 0.74, p)
			var top = Vector2(0, -r)
			var tip = Vector2(0, r * 0.86)
			var left = Vector2(-r * 0.78, -r * 0.48)
			var right = Vector2(r * 0.78, -r * 0.48)
			draw_polyline(PackedVector2Array([top, right, right * Vector2(0.86, -0.72), tip, left * Vector2(0.86, -0.72), left, top]), col, 3, true)
			return
		&"valve":
			size *= lerpf(0.58, 1.05, p)
			if accents > 0:
				rim(self, Vector2.ZERO, radius * lerpf(0.54, 1.0, p), col, 8, p * PI)
		&"interrupt":
			size *= lerpf(1.0, 0.2, p)
		&"interrupt_line":
			var destination = Vector2.from_angle(direction) * diameter
			var end = destination * minf(p * 3, 1)
			draw_line(Vector2.ZERO, end, Color(0.67, 0.97, 1, fade), 4, true)
			return
		&"rune":
			size *= lerpf(1.2, 0.55, p)
		&"rune_break", &"beacon_exit":
			var art = &"rune" if clip == &"rune_break" else &"beacon"
			draw_clip(self, art, Vector2(0, -diameter * 0.28), size * lerpf(1.0, 0.42, p), 1.0 - p, 0, Color(1, 1, 1, fade * 0.82))
			var edge = Color(0.82, 0.68, 1.0, fade) if clip == &"rune_break" else Color(1.0, 0.72, 0.42, fade)
			rim(self, Vector2.ZERO, radius * lerpf(0.2, 1.25, p), edge, 5)
			return
	if draw_clip(self, clip, point, size, p, direction, Color(1, 1, 1, fade)):
		return
	# A small cue is still available if an asset is absent in development.
	if clip in [&"heal", &"dawn"]:
		for i in 5:
			var x = (i - 2) * radius * 0.23
			draw_line(Vector2(x, -diameter * (0.23 + p * 0.48)), Vector2(x * 0.75, -4), col, 3, true)
	elif clip == &"wind":
		for i in 3:
			var angle = p * 8 + i * TAU / 3
			draw_arc(Vector2.ZERO, radius * lerpf(1, 0.4, p), angle, angle + 1.1, 18, col, 3, true)
	else:
		for i in 5 + mini(accents, 3):
			var unit = Vector2.from_angle(direction + i * TAU / (5 + mini(accents, 3)))
			draw_line(unit * radius * p * 0.65, unit * radius * lerpf(0.35, 1.0, p), col, 2.5, true)
