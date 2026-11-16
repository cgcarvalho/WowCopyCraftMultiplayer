class_name CombatProjectile
extends Node2D

var caster: Character
var target: Character
var damage = 0
var style = "arrow"
var elapsed = 0.0
var landed = false
var basic = false
var display_offset := Vector2.ZERO
signal hit(target: Character)

func launch(owner_character: Character, victim: Character, amount: int, attack_kind: String, origin: Vector2) -> void:
	caster = owner_character
	target = victim
	damage = amount
	style = attack_kind
	if basic or style == "rivet_skill":
		display_offset = caster.weapon_offset(style, origin.direction_to(victim.global_position))
	modulate.a = CombatFeedback.effect_opacity(caster)
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
		if basic:
			caster.on_basic_hit(target)
		hit.emit(target)
		if style == "rivet_skill":
			CombatFeedback.show_skill_effect(&"spark", target.global_position, caster, 74, rotation)
		if style != "melee":
			queue_free()
	if elapsed > (0.25 if style == "melee" else 2.0):
		queue_free()
	queue_redraw()

func _draw() -> void:
	var point = (display_offset * maxf(0, 1 - elapsed / 0.16)).rotated(-rotation)
	match style:
		"melee":
			draw_arc(Vector2.ZERO, 45, elapsed * 8, elapsed * 8 + 2.0, 20, Color(1, 0.75, 0.5, maxf(0, 1 - elapsed * 4)), 5, true)
		"arrow":
			draw_line(point + Vector2(-32, 0), point + Vector2(10, 0), Color("d6f5d0"), 2.5, true)
			SkillFX.arrow(self, point, Vector2.RIGHT, Color("d6f5d0"), 2)
			for sign_value in [-1, 1]:
				draw_line(point + Vector2(-24, 0), point + Vector2(-32, sign_value * 6), Color("92deae"), 2, true)
		"arrow_fork":
			HeroAbility.draw_projectile(self, "arrow_fork", point, Vector2.RIGHT, Color("b8f7c0"), elapsed)
		"rivet", "rivet_skill":
			var powered = style == "rivet_skill"
			var tail = 55.0 if powered else 24.0
			draw_line(point - Vector2(tail, 0), point + Vector2(4, 0), Color("ffb46d"), 4 if powered else 3, true)
			if not powered or not SkillFX.draw_clip(self, &"rivet", point, Vector2.ONE * 44, fposmod(elapsed * 6, 1)):
				draw_rect(Rect2(point + Vector2(-5, -4), Vector2(15, 8) if powered else Vector2(10, 6)), Color("ffe0a8"))
		_:
			var tint = Color("ffe299") if style == "holy" else Color("bc7bff")
			draw_circle(point, 8, tint)
			draw_line(point + Vector2(-25, 0), point, Color(tint, 0.4), 5, true)
