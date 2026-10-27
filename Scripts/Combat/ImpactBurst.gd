class_name ImpactBurst
extends Node2D

var kind = "hit"
var elapsed = 0.0
const COLORS = {"hit": Color("ffba78"), "crit": Color("ffdf6a"), "heal": Color("78efac"), "shield": Color("80caff")}

func _ready() -> void:
	z_index = 25

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.35:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var tint: Color = COLORS.get(kind, Color.WHITE)
	var fade = maxf(0, 1 - elapsed / 0.35)
	var radius = 12 + elapsed * (130 if kind == "crit" else 85)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(tint, fade), 3 if kind == "shield" else 2, true)
	for index in 6:
		var direction = Vector2.from_angle(index * TAU / 6)
		draw_line(direction * radius, direction * (radius + 10), Color(tint, fade), 2, true)
	if kind == "heal":
		draw_line(Vector2(-8, -20), Vector2(8, -20), Color(tint, fade), 4, true)
		draw_line(Vector2(0, -28), Vector2(0, -12), Color(tint, fade), 4, true)
	elif kind == "shield":
		draw_string(ThemeDB.fallback_font, Vector2(-32, -40), "ABSORVIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(tint, fade))
