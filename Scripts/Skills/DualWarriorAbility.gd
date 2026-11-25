class_name DualWarriorAbility
extends HeroAbility

const MOVES = {
	"twin_cross": {"name": "Corte Cruzado", "cd": 6, "mana": 0, "cast": 0, "mode": "ENEMY", "range": 155, "power": 18, "radius": 0, "duration": 0, "color": "e5bb85", "description": "Cruza as duas espadas: 18 de dano + 4 por Cadência consumida (máx. 3). Gera 10 de Fúria ao acertar."},
	"steel_step": {"name": "Passo de Aço", "cd": 10, "mana": 0, "cast": 0, "mode": "ENEMY", "range": 360, "power": 10, "radius": 0, "duration": 0, "color": "a6c5de", "description": "Investe até um inimigo a até 360 unidades, respeitando obstáculos. Causa 10 de dano e gera 10 de Fúria ao alcançar o alvo."},
	"blade_guard": {"name": "Guarda de Lâminas", "cd": 16, "mana": 30, "cast": 0, "mode": "SELF", "range": 0, "power": 24, "radius": 180, "duration": 0, "color": "c0dbf1", "description": "Recebe 24 de proteção por 3 s. A primeira absorção dessa guarda gera 12 de Fúria e contra-ataca um inimigo a até 180 por 8 de dano."},
	"blade_dance": {"name": "Dança das Lâminas", "cd": 60, "mana": 65, "cast": 0, "mode": "SELF", "range": 0, "power": 6, "radius": 150, "duration": 4, "color": "e3b374", "description": "Por 4 s, golpeia inimigos a até 150 a cada 0,5 s: oito pulsos de 6 de dano. A área acompanha seu movimento."}
}
@export var ability: String:
	set(value):
		ability = value
		configure(value)

func configure(id: String) -> void:
	ability_id = id
	data = MOVES[id].duplicate(true)
	skillName = data.name
	skillCoolDownTime = data.cd
	skillManaCost = data.mana
	skillCastTime = data.cast
	skillScenePath = "res://Scenes/Skills/Classes/" + id + ".tscn"
	iconFilePath = "res://Art/Skills/Classes/" + id + ".tres"
	description = data.description
	cast_range = data.range
	target_mode = TargetMode[data.mode]
	is_ultimate = id == "blade_dance"
	tint = Color(data.color)
	skillDotSeconds = data.duration
	visual_duration = 0.5

func cast(caster: Character, target: Character) -> void:
	casterCharacter = caster
	targetCharacter = target
	global_position = caster.global_position
	facing = caster.global_position.direction_to(target.global_position)
	next_tick = 0.5
	match ability_id:
		"twin_cross":
			if multiplayer.is_server():
				cross_hit()
		"blade_guard":
			if multiplayer.is_server():
				caster.upsert_shield(int(data.power), caster, 3, "blade_guard")
				caster.riposte_remaining = 3.0
				if TalentTree.has(caster.talents, "duelist", 3):
					caster.apply_heal(12, caster)
			cue(&"shield", global_position, 132, 0, 0, caster)

func cross_hit() -> void:
	if impacted or not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0:
		return
	impacted = true
	var stacks = casterCharacter.cadence
	var before = targetCharacter.charCurrentLife + targetCharacter.charShield
	hurt(targetCharacter, int(data.power) + 4 * stacks)
	if before <= targetCharacter.charCurrentLife + targetCharacter.charShield:
		return
	casterCharacter.consume_cadence()
	casterCharacter.gain_resource(10)
	cue(&"slash", targetCharacter.global_position, 122, -0.65)
	cue(&"slash", targetCharacter.global_position, 122, 0.65)
	if stacks == 3 and MasteryCatalog.active(casterCharacter, "cross_frenzy"):
		var targets = MasteryEffects.enemies_near(casterCharacter, targetCharacter.global_position, 140, targetCharacter)
		for index in mini(2, targets.size()):
			targets[index].deal_damage(8, casterCharacter)
			cue(&"slash", targets[index].global_position, 90)

func _physics_process(delta: float) -> void:
	if not living():
		queue_free()
		return
	elapsed += delta
	if ability_id == "steel_step":
		if not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0 or targetCharacter.spectator:
			queue_free()
			return
		var offset = casterCharacter.global_position - targetCharacter.global_position
		var stop = targetCharacter.global_position + offset.normalized() * 70
		if casterCharacter.is_multiplayer_authority():
			casterCharacter.global_position = ArenaNavigation.move(casterCharacter.global_position, (stop - casterCharacter.global_position).limit_length(delta * 900))
		global_position = casterCharacter.global_position
		if offset.length() <= 110:
			if multiplayer.is_server() and not impacted:
				impacted = true
				var before = targetCharacter.charCurrentLife + targetCharacter.charShield
				hurt(targetCharacter, int(data.power))
				if before > targetCharacter.charCurrentLife + targetCharacter.charShield:
					casterCharacter.gain_resource(10)
				cue(&"slash", targetCharacter.global_position, 115, facing.angle())
			queue_free()
		elif elapsed > 0.8:
			queue_free()
	elif ability_id == "blade_dance":
		global_position = casterCharacter.global_position
		while elapsed >= next_tick and next_tick <= float(data.duration):
			if multiplayer.is_server():
				for target in MasteryEffects.enemies_near(casterCharacter, global_position, float(data.radius)):
					hurt(target, int(data.power), true)
				cue(&"slash", global_position, float(data.radius) * 2, next_tick * TAU)
			next_tick += 0.5
		if elapsed >= float(data.duration):
			queue_free()
	elif elapsed >= visual_duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if ability_id == "blade_dance":
		var opacity = CombatFeedback.effect_opacity(casterCharacter)
		for index in 2:
			var angle = elapsed * TAU * 1.8 + index * PI
			draw_arc(Vector2.ZERO, float(data.radius), angle, angle + 1.5, 20, Color(0.94, 0.81, 0.62, opacity * 0.55), 4, true)
	elif ability_id == "steel_step":
		draw_line(Vector2.ZERO, -facing * 65, Color(0.74, 0.86, 1, maxf(0, 0.7 - elapsed)), 5, true)
