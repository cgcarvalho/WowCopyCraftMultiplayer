class_name CombatProjectile
extends Node2D

var caster: Character
var target: Character
var damage = 0
var style = "arrow"
var elapsed = 0.0
var landed = false

func launch(owner_character: Character, victim: Character, amount: int, attack_kind: String, origin: Vector2) -> void:
	caster = owner_character
	target = victim
	damage = amount
	style = attack_kind
	global_position = origin
	z_index = Constants.PLAYER_Z_INDEX + 1
	if style == "melee":
		global_position = target.global_position

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(target) or not is_instance_valid(caster) or target.charCurrentLife <= 0 or caster.charCurrentLife <= 0:
		queue_free()
		return
	var handler = get_parent().get_node_or_null("SkillHandler")
	if handler != null and handler.encounter_finished():
		queue_free()
		return
	if style != "melee":
		rotation = (target.global_position - global_position).angle()
		global_position = global_position.move_toward(target.global_position, delta * 900)
	if not landed and (style == "melee" or global_position.distance_to(target.global_position) < 4):
		landed = true
		target.deal_damage(damage, caster)
		if style != "melee":
			queue_free()
	if elapsed > (0.25 if style == "melee" else 2.0):
		queue_free()
	queue_redraw()

func _draw() -> void:
	match style:
		"melee":
			draw_arc(Vector2.ZERO, 45, elapsed * 8, elapsed * 8 + 2.0, 20, Color(1, 0.75, 0.5, maxf(0, 1 - elapsed * 4)), 5, true)
		"arrow":
			draw_line(Vector2(-32, 0), Vector2(10, 0), Color("d6f5d0"), 2.5, true)
			draw_polyline(PackedVector2Array([Vector2(0, -5), Vector2(10, 0), Vector2(0, 5)]), Color("d6f5d0"), 2, true)
			for sign_value in [-1, 1]:
				draw_line(Vector2(-24, 0), Vector2(-32, sign_value * 6), Color("92deae"), 2, true)
		_:
			var tint = Color("ffe299") if style == "holy" else Color("bc7bff")
			draw_circle(Vector2.ZERO, 8, tint)
			draw_line(Vector2(-25, 0), Vector2.ZERO, Color(tint, 0.4), 5, true)
