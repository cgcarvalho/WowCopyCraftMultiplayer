class_name HeroAbility
extends Skill

var ability_id = ""
var iconFilePath = ""
var data: Dictionary
var elapsed = 0.0
var next_tick = 1.0
var destination = Vector2.ZERO
var impacted = false
var visual_duration = 0.65
var tint = Color.WHITE
var skillTimer = 0.0
var skillDotSeconds = 0

const DEFINITIONS = {
	"soul_reap": {"name": "Soul Reap", "cd": 60, "mana": 35, "cast": 1.2, "mode": "ENEMY", "range": 700, "power": 45, "radius": 130, "duration": 0, "color": "b979ff", "description": "Explode sombras: 45 de dano + 12 por DoT seu no alvo. Atinge inimigos próximos."},
	"charge": {"name": "Charge", "cd": 10, "mana": 0, "cast": 0, "mode": "ENEMY", "range": 500, "power": 16, "radius": 0, "duration": 0, "color": "ffad68", "description": "Avança até um inimigo e causa 16 de dano. Alcance: 500."},
	"cleave": {"name": "Cleave", "cd": 5, "mana": 25, "cast": 0, "mode": "ENEMY", "range": 115, "power": 24, "radius": 120, "duration": 0, "color": "ffad68", "description": "Golpe amplo: 24 de dano em inimigos próximos do alvo. Requer alcance corpo a corpo."},
	"second_wind": {"name": "Second Wind", "cd": 18, "mana": 30, "cast": 0, "mode": "SELF", "range": 0, "power": 30, "radius": 0, "duration": 0, "color": "fa9470", "description": "Recupera 30 de vida e recebe 15 de proteção."},
	"bladestorm": {"name": "Bladestorm", "cd": 60, "mana": 80, "cast": 0, "mode": "SELF", "range": 0, "power": 12, "radius": 140, "duration": 6, "color": "ffad68", "description": "Por 6s, gira causando 12 de dano por segundo. A área acompanha você."},
	"judgement": {"name": "Judgement", "cd": 6, "mana": 0, "cast": 0, "mode": "ENEMY", "range": 550, "power": 24, "radius": 0, "duration": 0, "color": "ffe299", "description": "Martelo sagrado: 24 de dano em um inimigo a até 550."},
	"holy_light": {"name": "Holy Light", "cd": 8, "mana": 1, "cast": 1.2, "mode": "ALLY", "range": 650, "power": 32, "radius": 0, "duration": 0, "color": "ffe299", "description": "Cura um aliado em 32. Sem aliado selecionado, cura você. Alt: autocura."},
	"consecration": {"name": "Consecration", "cd": 16, "mana": 2, "cast": 0, "mode": "SELF", "range": 0, "power": 7, "radius": 155, "duration": 8, "color": "ffe299", "description": "Consagra o chão por 8s: 7 de dano/s aos inimigos e 3 de cura/s aos aliados."},
	"divine_dawn": {"name": "Divine Dawn", "cd": 65, "mana": 5, "cast": 0.8, "mode": "SELF", "range": 0, "power": 40, "radius": 240, "duration": 0, "color": "ffe299", "description": "Explosão sagrada: cura 40 e concede 35 de proteção aos aliados próximos; causa 35 aos inimigos."},
	"aimed_shot": {"name": "Aimed Shot", "cd": 6, "mana": 25, "cast": 1.0, "mode": "ENEMY", "range": 750, "power": 32, "radius": 0, "duration": 0, "color": "92deae", "description": "Disparo preciso: 32 de dano. Preparação de 1s."},
	"poison_arrow": {"name": "Poison Arrow", "cd": 10, "mana": 20, "cast": 0, "mode": "ENEMY", "range": 700, "power": 8, "radius": 0, "duration": 8, "color": "a7ef70", "description": "Flecha: 8 de dano inicial + 4/s por 8s. Reaplicar renova o veneno do mesmo arqueiro."},
	"multishot": {"name": "Multi-Shot", "cd": 9, "mana": 30, "cast": 0, "mode": "ENEMY", "range": 700, "power": 18, "radius": 210, "duration": 0, "color": "92deae", "description": "Dispara em até 3 inimigos próximos do alvo; 18 de dano por flecha."},
	"arrow_rain": {"name": "Arrow Rain", "cd": 60, "mana": 60, "cast": 0.6, "mode": "GROUND", "range": 700, "power": 12, "radius": 185, "duration": 7, "color": "92deae", "description": "Escolha uma área no chão: 12 de dano/s por 7s. Clique confirma; Esc cancela."},
}

static func create(id: String) -> Skill:
	return load("res://Scenes/Skills/Classes/" + id + ".tscn").instantiate()

func configure(id: String) -> void:
	ability_id = id
	data = DEFINITIONS[id].duplicate(true)
	skillName = data.name
	skillCoolDownTime = data.cd
	skillManaCost = data.mana
	skillCastTime = data.cast
	skillScenePath = "res://Scenes/Skills/Classes/" + id + ".tscn"
	iconFilePath = "res://Art/Skills/Classes/" + id + ".tres"
	var original_icons = {
		"charge": "res://Art/Skills/Charge Icon.png",
		"holy_light": "res://Art/Skills/Heal icon.png",
		"consecration": "res://Art/Skills/Consecration Icon.png"
	}
	if original_icons.has(id):
		iconFilePath = original_icons[id]
	description = data.description
	cast_range = data.range
	target_mode = TargetMode[data.mode]
	is_ultimate = id in ["soul_reap", "bladestorm", "divine_dawn", "arrow_rain"]
	tint = Color(data.color)
	skillDotSeconds = data.duration

func cast(caster: Character, target: Character) -> void:
	casterCharacter = caster
	targetCharacter = target
	global_position = caster.global_position
	destination = aim_position if aim_position.is_finite() else target.global_position
	if ability_id in ["consecration", "arrow_rain"]:
		global_position = destination
	if ability_id == "poison_arrow":
		for effect in target.debuffList:
			if is_instance_valid(effect) and effect is HeroAbility and effect.ability_id == ability_id and effect.casterCharacter == caster:
				effect.renewDot()
				queue_free()
				return
	if ability_id in ["second_wind", "holy_light", "divine_dawn"]:
		impact()
	if ability_id in ["cleave", "soul_reap"]:
		global_position = destination
		impact()

func all_characters() -> Array:
	return MultiplayerManager.playerList.values() + MultiplayerManager.enemies.values()

func living() -> bool:
	if not is_instance_valid(casterCharacter) or casterCharacter.charCurrentLife <= 0:
		return false
	var handler = get_parent().get_node_or_null("SkillHandler")
	return handler == null or not handler.encounter_finished()

func impact() -> void:
	if impacted:
		return
	impacted = true
	if not multiplayer.is_server() or not living():
		return
	var power: int = data.power
	if ability_id == "judgement":
		casterCharacter.gain_resource(1)
	elif ability_id == "charge":
		casterCharacter.gain_resource(15)
	match ability_id:
		"holy_light":
			targetCharacter.apply_heal(power, casterCharacter)
		"second_wind":
			casterCharacter.apply_heal(power, casterCharacter)
			casterCharacter.apply_shield(maxi(casterCharacter.charShield, 15))
		"divine_dawn":
			for character in all_characters():
				if not is_instance_valid(character) or character.global_position.distance_to(global_position) > float(data.radius):
					continue
				if character.charTeam == casterCharacter.charTeam:
					character.apply_heal(power, casterCharacter)
					character.apply_shield(maxi(character.charShield, 35))
				else:
					character.deal_damage(35, casterCharacter)
		"cleave", "soul_reap":
			if ability_id == "soul_reap":
				for effect in targetCharacter.debuffList:
					if is_instance_valid(effect) and effect.casterCharacter == casterCharacter:
						power += 12
			for character in all_characters():
				if is_instance_valid(character) and character.charTeam != casterCharacter.charTeam and character.global_position.distance_to(global_position) <= float(data.radius):
					character.deal_damage(power, casterCharacter)
		_:
			if is_instance_valid(targetCharacter) and targetCharacter.charCurrentLife > 0:
				targetCharacter.deal_damage(power, casterCharacter)

func tick_effect() -> void:
	if not multiplayer.is_server() or not living():
		return
	if ability_id == "poison_arrow":
		targetCharacter.deal_damage(4, casterCharacter, true)
		return
	for character in all_characters():
		if not is_instance_valid(character) or character.charCurrentLife <= 0:
			continue
		if character.global_position.distance_to(global_position) > float(data.radius):
			continue
		if character.charTeam != casterCharacter.charTeam:
			character.deal_damage(data.power, casterCharacter, true)
		elif ability_id == "consecration":
			character.apply_heal(3, casterCharacter)

func _physics_process(delta: float) -> void:
	if not living():
		queue_free()
		return
	elapsed += delta
	skillTimer = elapsed
	if ability_id == "bladestorm":
		global_position = casterCharacter.global_position
	if ability_id == "charge":
		if not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0:
			queue_free()
			return
		var offset = casterCharacter.global_position - targetCharacter.global_position
		var stop = targetCharacter.global_position + offset.normalized() * 70
		if casterCharacter.is_multiplayer_authority():
			casterCharacter.global_position = ArenaNavigation.move(casterCharacter.global_position, (stop - casterCharacter.global_position).limit_length(delta * 900))
		global_position = casterCharacter.global_position
		if offset.length() <= 100:
			impact()
			queue_free()
		elif elapsed > 1.0:
			queue_free()
	elif ability_id in ["aimed_shot", "judgement", "multishot", "poison_arrow"] and not impacted:
		if not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0:
			queue_free()
			return
		destination = targetCharacter.global_position
		global_position = global_position.move_toward(destination, 850 * delta)
		if global_position.distance_to(destination) < 4:
			impact()
			if ability_id == "poison_arrow":
				targetCharacter.debuffList.append(self)
				elapsed = 0.0
				skillTimer = 0.0
			if ability_id == "multishot":
				var count = 1
				for character in all_characters():
					if count >= 3:
						break
					if is_instance_valid(character) and character != targetCharacter and character.charTeam != casterCharacter.charTeam and character.charCurrentLife > 0 and character.global_position.distance_to(destination) <= float(data.radius):
						var bolt = CombatProjectile.new()
						get_parent().add_child(bolt)
						bolt.launch(casterCharacter, character, data.power, "arrow", destination)
						count += 1
			if ability_id != "poison_arrow":
				queue_free()
				return
	# Projectiles may take longer than the short impact animation at full range.
	if ability_id in ["aimed_shot", "judgement", "multishot", "poison_arrow"] and not impacted:
		if elapsed > 2.0:
			queue_free()
		queue_redraw()
		return
	if ability_id == "poison_arrow" and impacted:
		if not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0:
			queue_free()
			return
		global_position = targetCharacter.global_position
	if float(data.duration) > 0 and (ability_id != "poison_arrow" or impacted):
		while elapsed >= next_tick and next_tick <= float(data.duration):
			tick_effect()
			next_tick += 1.0
		if elapsed >= float(data.duration):
			queue_free()
	elif elapsed > visual_duration and ability_id != "charge":
		queue_free()
	queue_redraw()

func renewDot() -> void:
	elapsed = 0
	skillTimer = 0
	next_tick = 1.0

func _exit_tree() -> void:
	if is_instance_valid(targetCharacter):
		targetCharacter.debuffList.erase(self)

func _draw() -> void:
	if ability_id in ["aimed_shot", "multishot", "judgement", "poison_arrow"] and not impacted:
		var direction = (destination - global_position).normalized()
		draw_line(-direction * 30, direction * 10, tint, 3, true)
		draw_line(direction * 10, direction.rotated(0.6) * -4, tint, 3, true)
		draw_line(direction * 10, direction.rotated(-0.6) * -4, tint, 3, true)
		return
	if ability_id == "poison_arrow":
		draw_arc(Vector2.ZERO, 24, elapsed, elapsed + TAU * 0.8, 24, Color(tint, 0.6), 2, true)
		return
	var radius = maxf(float(data.radius), 45)
	var long_effect = float(data.duration) > 0
	var fade = 1.0 if long_effect else maxf(0, 1 - elapsed / visual_duration)
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.08 * fade))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(tint, 0.65 * fade), 2.5, true)
	if ability_id == "consecration" or ability_id == "divine_dawn":
		draw_line(Vector2(-25, 0), Vector2(25, 0), Color(tint, fade), 5, true)
		draw_line(Vector2(0, -38), Vector2(0, 38), Color(tint, fade), 5, true)
	elif ability_id == "arrow_rain":
		for i in 12:
			var angle = i * 2.4
			var point = Vector2.from_angle(angle) * radius * sqrt((i + 1) / 13.0)
			var drop = fmod(elapsed * 170 + i * 19, 65)
			draw_line(point + Vector2(0, drop - 65), point + Vector2(-8, drop - 88), Color(tint, 0.85), 2, true)
	else:
		for i in 3:
			var angle = elapsed * 7 + i * TAU / 3
			draw_arc(Vector2.ZERO, radius * (0.7 + i * 0.08), angle, angle + 1.2, 18, Color(tint, fade), 5, true)
