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
var skillDotSeconds = 0.0
var display_offset := Vector2.ZERO
var facing := Vector2.RIGHT
var trail := PackedVector2Array()
var shield_cue = false
var secondary_effect = false
var drag_ready: Dictionary = {}

const PROJECTILES = {"aimed_shot": "aimed", "judgement": "hammer", "multishot": "arrow_fork", "poison_arrow": "poison"}

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
	"rivet_shot": {"name": "Tiro de Rebite", "cd": 5, "mana": 0, "cast": 0.35, "mode": "ENEMY", "range": 590, "power": 16, "radius": 0, "duration": 0, "color": "ffb46d", "description": "Dispara um rebite que causa 16 de dano e gera 18 de Pressão ao acertar."},
	"field_beacon": {"name": "Baliza de Campo", "cd": 12, "mana": 20, "cast": 0, "mode": "GROUND", "range": 480, "power": 0, "radius": 165, "duration": 10, "color": "ffa965", "description": "Instala uma Baliza por 10 s. Seus ataques básicos que acertam dentro do raio 165 carregam Circuito Fechado. Uma Baliza ativa por Téo."},
	"valve_burst": {"name": "Estouro de Válvula", "cd": 9, "mana": 28, "cast": 0.45, "mode": "GROUND", "range": 480, "power": 23, "radius": 125, "duration": 0, "color": "ffd090", "description": "Causa 23 de dano em raio 125. Se o centro estiver na sua Baliza no impacto, causa 31."},
	"overload": {"name": "Sobrecarga", "cd": 60, "mana": 60, "cast": 0.55, "mode": "SELF", "range": 480, "power": 12, "radius": 175, "duration": 5, "color": "ffa965", "description": "Requer sua Baliza ativa a até 480. Ativa uma área de raio 175 por 5 s com quatro pulsos de 12 de dano."},
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
	is_ultimate = id in ["soul_reap", "bladestorm", "divine_dawn", "arrow_rain", "overload"]
	tint = Color(data.color)
	skillDotSeconds = data.duration

func cast(caster: Character, target: Character) -> void:
	casterCharacter = caster
	targetCharacter = target
	global_position = caster.global_position
	destination = aim_position if aim_position.is_finite() else target.global_position
	if global_position.distance_squared_to(destination) > 0.01:
		facing = global_position.direction_to(destination)
	if ability_id in PROJECTILES:
		display_offset = caster.weapon_offset(PROJECTILES[ability_id], facing)
	if ability_id in ["consecration", "arrow_rain"]:
		z_index = 1
	if ability_id in ["consecration", "arrow_rain"]:
		global_position = destination
	if ability_id == "poison_arrow":
		for effect in target.debuffList:
			if is_instance_valid(effect) and effect is HeroAbility and effect.ability_id == ability_id and effect.casterCharacter == caster:
				effect.data.duration = data.duration
				effect.skillDotSeconds = skillDotSeconds
				effect.secondary_effect = false
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
	var primary_before = targetCharacter.charCurrentLife + targetCharacter.charShield if is_instance_valid(targetCharacter) else 0
	var power: int = data.power
	if ability_id == "judgement":
		casterCharacter.gain_resource(1)
	elif ability_id == "charge":
		casterCharacter.gain_resource(15)
	match ability_id:
		"holy_light":
			targetCharacter.apply_heal(power, casterCharacter)
			cue(&"heal", targetCharacter.global_position, 132, 0, 0, targetCharacter)
		"second_wind":
			casterCharacter.apply_heal(power, casterCharacter)
			casterCharacter.apply_shield(30 if TalentTree.has(casterCharacter.talents, "guardian", 2) else 15, casterCharacter)
			shield_cue = true
			cue(&"wind", global_position, 145)
		"divine_dawn":
			for character in all_characters():
				if not is_instance_valid(character) or character.charCurrentLife <= 0 or character.spectator or character.global_position.distance_to(global_position) > float(data.radius):
					continue
				if character.charTeam == casterCharacter.charTeam:
					character.apply_heal(60 if TalentTree.has(casterCharacter.talents, "light", 3) else power, casterCharacter)
					character.apply_shield(50 if TalentTree.has(casterCharacter.talents, "bulwark", 3) else 35, casterCharacter)
					cue(&"shield", character.global_position, 100, 0, 0, character)
				else:
					character.deal_damage(35, casterCharacter)
					cue(&"slash", character.global_position, 75)
			cue(&"dawn", global_position, 245)
		"cleave", "soul_reap":
			var dot_count = 0
			if ability_id == "soul_reap":
				for effect in targetCharacter.debuffList:
					if is_instance_valid(effect) and effect.casterCharacter == casterCharacter:
						dot_count += 1
						power += 18 if TalentTree.has(casterCharacter.talents, "affliction", 3) else 12
			if ability_id == "soul_reap":
				cue(&"reap", global_position, 240, 0.0, dot_count)
			else:
				cue(&"slash", global_position, 95, facing.angle())
			for character in all_characters():
				if is_instance_valid(character) and character.charTeam != casterCharacter.charTeam and character.global_position.distance_to(global_position) <= float(data.radius):
					hurt(character, power)
		_:
			if is_instance_valid(targetCharacter) and targetCharacter.charCurrentLife > 0:
				hurt(targetCharacter, power)
				match ability_id:
					"judgement": cue(&"hammer_seal", targetCharacter.global_position, 110)
					"charge": cue(&"slash", targetCharacter.global_position, 124, facing.angle())
					"poison_arrow": cue(&"poison", targetCharacter.global_position, 78)
					"aimed_shot": cue(&"slash", targetCharacter.global_position, 86, facing.angle())
	var effective = primary_before - targetCharacter.charCurrentLife - targetCharacter.charShield if is_instance_valid(targetCharacter) else 0
	MasteryEffects.skill_impact(self, effective)

func cue(clip: StringName, point: Vector2, size: float, angle: float = 0.0, marks: int = 0, recipient: Character = null) -> void:
	CombatFeedback.show_skill_effect(clip, point, casterCharacter, size, angle, marks, recipient)

func hurt(character: Character, power: int, periodic: bool = false) -> void:
	character.deal_damage(power, casterCharacter, periodic, TalentTree.skill_damage(casterCharacter.talents, self))

func tick_effect() -> void:
	if not multiplayer.is_server() or not living():
		return
	MasteryEffects.periodic(self)
	if ability_id == "poison_arrow":
		hurt(targetCharacter, 6 if TalentTree.has(casterCharacter.talents, "venom", 1) else 4, true)
		cue(&"poison", targetCharacter.global_position, 45)
		return
	for character in all_characters():
		if not is_instance_valid(character) or character.charCurrentLife <= 0:
			continue
		if character.global_position.distance_to(global_position) > float(data.radius):
			continue
		if character.charTeam != casterCharacter.charTeam:
			hurt(character, data.power, true)
			if ability_id in ["consecration", "arrow_rain"]:
				cue(&"slash", character.global_position, 56)
		elif ability_id == "consecration":
			var life_before = character.charCurrentLife
			character.apply_heal(3, casterCharacter)
			if character.charCurrentLife > life_before:
				cue(&"heal", character.global_position, 44, 0, 0, character)
	if ability_id in ["bladestorm", "arrow_rain", "consecration"]:
		var wave := StringName(ability_id)
		cue(wave, global_position, float(data.radius) * 2)

func _physics_process(delta: float) -> void:
	if not living():
		queue_free()
		return
	elapsed += delta
	skillTimer = elapsed
	if shield_cue and elapsed >= 0.18:
		shield_cue = false
		if casterCharacter.charShield > 0:
			cue(&"shield", casterCharacter.global_position, 112)
	if ability_id == "bladestorm":
		global_position = casterCharacter.global_position
	if ability_id == "charge":
		if not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0:
			cue(&"wind", global_position, 80)
			queue_free()
			return
		var offset = casterCharacter.global_position - targetCharacter.global_position
		if offset.length_squared() > 1:
			facing = -offset.normalized()
		if absf(facing.x) > 0.02:
			casterCharacter.get_node("AnimatedSprite2D").flip_h = facing.x > 0
		trail.append(casterCharacter.global_position)
		if trail.size() > 7:
			trail.remove_at(0)
		var stop = targetCharacter.global_position + offset.normalized() * 70
		if casterCharacter.is_multiplayer_authority():
			casterCharacter.global_position = ArenaNavigation.move(casterCharacter.global_position, (stop - casterCharacter.global_position).limit_length(delta * 900))
		global_position = casterCharacter.global_position
		if offset.length() <= 100:
			impact()
			queue_free()
		elif elapsed > 1.0:
			cue(&"wind", global_position, 80)
			queue_free()
	elif ability_id in PROJECTILES and not impacted:
		if not is_instance_valid(targetCharacter) or targetCharacter.charCurrentLife <= 0:
			queue_free()
			return
		destination = targetCharacter.global_position
		if destination.distance_squared_to(global_position) > 16:
			facing = global_position.direction_to(destination)
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
						bolt.launch(casterCharacter, character, data.power, "arrow_fork", destination)
						count += 1
				if count > 1:
					cue(&"fork", destination, 94, facing.angle(), count - 1)
			if ability_id != "poison_arrow":
				queue_free()
				return
	# Projectiles may take longer than the short impact animation at full range.
	if ability_id in PROJECTILES and not impacted:
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
	if is_instance_valid(targetCharacter):
		cue(&"poison", targetCharacter.global_position, 68)

func _exit_tree() -> void:
	if is_instance_valid(targetCharacter):
		targetCharacter.debuffList.erase(self)

func _draw() -> void:
	if ability_id in PROJECTILES and not impacted:
		var point = display_offset * (1.0 - minf(elapsed / 0.19, 1.0))
		draw_projectile(self, PROJECTILES[ability_id], point, facing, tint, elapsed)
		return
	if ability_id == "poison_arrow":
		var remaining = maxf(0, float(data.duration) - elapsed)
		for i in 3:
			var point = Vector2.from_angle(elapsed * 2 + i * TAU / 3) * 34
			var fade = clampf(remaining / 0.48, 0, 1)
			draw_circle(point + Vector2(0, -23), lerpf(2, 4, fade), Color(tint, 0.32 * fade))
	if ability_id == "charge":
		for i in range(1, trail.size()):
			var alpha = float(i) / trail.size() * 0.42
			draw_line(to_local(trail[i - 1]) + Vector2(0, 18), to_local(trail[i]) + Vector2(0, 18), Color(tint, alpha), 4 + i, true)
	if ability_id in ["consecration", "arrow_rain", "bladestorm", "soul_reap", "divine_dawn", "cleave"]:
		var radius = float(data.radius)
		var fade = 1.0 if float(data.duration) > 0 else maxf(0, 1 - elapsed / visual_duration)
		SkillFX.rim(self, Vector2.ZERO, radius, Color(tint, 0.42 * fade), 12 if ability_id == "consecration" else 0)
		if ability_id == "consecration":
			var pulse = 0.20 + 0.55 * pow(1 - fposmod(elapsed, 1.0), 4)
			SkillFX.draw_clip(self, &"consecration", Vector2.ZERO, Vector2.ONE * radius * 2, 0.0, 0.0, Color(1, 1, 1, pulse))
		elif ability_id == "arrow_rain":
			var until_hit = next_tick - elapsed
			if until_hit < 0.40:
				var air_time = clampf(1 - until_hit / 0.40, 0.0, 1.0)
				for i in 8:
					var point = SkillFX.volley_point(i, radius)
					var height = lerpf(132.0, 8.0, air_time)
					var arrow_point = point - Vector2(height * 0.24, height)
					if not SkillFX.draw_clip(self, &"arrow", arrow_point, Vector2.ONE * 96, air_time * 0.68, 0, Color(1, 1, 1, 0.88)):
						draw_line(arrow_point - Vector2(10, 42), arrow_point, Color(0.7, 0.96, 0.74, 0.8), 3.0, true)

static func draw_projectile(canvas: CanvasItem, style: String, point: Vector2, direction: Vector2, tint: Color, time: float) -> void:
	if style == "hammer":
		if SkillFX.draw_clip(canvas, &"hammer", point, Vector2(78, 78), fposmod(time * 3, 1), direction.angle()):
			return
		canvas.draw_line(point - direction * 18, point + direction * 9, tint, 5, true)
		canvas.draw_line(point + direction * 9 - direction.orthogonal() * 12, point + direction * 9 + direction.orthogonal() * 12, tint, 9, true)
		return
	var tail = 65.0 if style == "aimed" else 34.0
	var width = 4.5 if style == "aimed" else 2.5
	canvas.draw_line(point - direction * tail, point + direction * 10, tint, width, true)
	SkillFX.arrow(canvas, point, direction, tint, width)
	if style == "poison":
		canvas.draw_circle(point + direction * 12, 5, tint)
		canvas.draw_circle(point - direction * 14 + direction.orthogonal() * 5, 3, Color(tint, 0.65))
	if style == "arrow_fork":
		for side in [-1.0, 1.0]:
			canvas.draw_line(point, point + direction.rotated(side * 0.44) * -26, tint, 3, true)
