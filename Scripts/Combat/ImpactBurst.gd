class_name ImpactBurst
extends Node2D

var kind = "hit"
var elapsed = 0.0
var intensity = 1.0
var periodic = false
var direction = Vector2.RIGHT
const COLORS = {"hit": Color("ffba78"), "crit": Color("ffdf6a"), "heal": Color("78efac"), "shield": Color("80caff")}

func _ready() -> void:
	z_index = 25

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime():
		queue_free()
	queue_redraw()

func lifetime() -> float:
	return 0.12 if periodic else (0.24 if kind == "crit" else 0.2)

func _draw() -> void:
	var tint: Color = COLORS.get(kind, Color.WHITE)
	var fade = maxf(0, 1 - elapsed / lifetime()) * intensity
	var radius = (5 if periodic else 10) + elapsed * (110 if kind == "crit" else 65)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(tint, fade), 3 if kind == "shield" else 2, true)
	for index in (3 if periodic else 5):
		var spark = direction.rotated((index - 2) * 0.55)
		draw_line(spark * radius, spark * (radius + (5 if periodic else 12)), Color(tint, fade), 2, true)
	if kind == "heal":
		draw_line(Vector2(-8, -20), Vector2(8, -20), Color(tint, fade), 4, true)
		draw_line(Vector2(0, -28), Vector2(0, -12), Color(tint, fade), 4, true)
	elif kind == "shield":
		draw_string(ThemeDB.fallback_font, Vector2(-32, -40), "ABSORVIDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(tint, fade))
