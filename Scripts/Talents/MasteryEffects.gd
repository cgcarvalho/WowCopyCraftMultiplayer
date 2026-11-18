class_name MasteryEffects
extends RefCounted

static func enemies_near(source: Character, point: Vector2, radius: float, exclude: Character = null) -> Array[Character]:
	var result: Array[Character] = []
	for enemy in MultiplayerManager.enemies.values():
		if is_instance_valid(enemy) and enemy != exclude and enemy.charTeam != source.charTeam and enemy.charCurrentLife > 0 and not enemy.spectator and enemy.global_position.distance_to(point) <= radius:
			result.append(enemy)
	result.sort_custom(func(a, b):
		var first = a.global_position.distance_squared_to(point)
		var second = b.global_position.distance_squared_to(point)
		return int(a.name) < int(b.name) if is_equal_approx(first, second) else first < second)
	return result

static func allies_near(source: Character, point: Vector2, radius: float, exclude: Character = null) -> Array[Character]:
	var result: Array[Character] = []
	for ally in MultiplayerManager.playerList.values():
		if is_instance_valid(ally) and ally != exclude and ally.charCurrentLife > 0 and not ally.spectator and ally.charTeam == source.charTeam and ally.global_position.distance_to(point) <= radius:
			result.append(ally)
	return result

static func secondary(source: Character, target: Character, power: int, origin: Vector2, style: String) -> void:
	var scene = source.get_tree().current_scene
	scene.get_node("SkillHandler").secondary_projectile.rpc(int(source.name), int(target.name), power, style, origin)

static func shadow_echo(source: Character, target: Character, power: int, effective: int) -> void:
	if not source.multiplayer.is_server() or effective <= 0 or not MasteryCatalog.active(source, "echo"):
		return
	var candidates = enemies_near(source, target.global_position, 180, target)
	for index in mini(2, candidates.size()):
		secondary(source, candidates[index], maxi(1, roundi(power * 0.35)), target.global_position, "magic")

static func skill_impact(skill: HeroAbility, effective: int) -> void:
	var source = skill.casterCharacter
	if not source.multiplayer.is_server():
		return
	var target = skill.targetCharacter
	match skill.ability_id:
		"holy_light":
			if MasteryCatalog.active(source, "chain_light"):
				var allies = allies_near(source, target.global_position, 200, target)
				allies.sort_custom(func(a, b):
					var a_fraction = float(a.charCurrentLife) / a.charTotalLife
					var b_fraction = float(b.charCurrentLife) / b.charTotalLife
					return int(a.name) < int(b.name) if is_equal_approx(a_fraction, b_fraction) else a_fraction < b_fraction)
				if not allies.is_empty():
					allies[0].apply_heal(roundi(int(skill.data.power) * 0.35), source)
					CombatFeedback.show_skill_effect(&"heal", allies[0].global_position, source, 88, 0, 0, allies[0])
					var offset = allies[0].global_position - target.global_position
					CombatFeedback.show_skill_effect(&"link", target.global_position, source, offset.length(), offset.angle())
		"second_wind":
			if MasteryCatalog.active(source, "shared_guard"):
				var allies = allies_near(source, source.global_position, 220, source)
				allies.sort_custom(func(a, b): return a.global_position.distance_squared_to(source.global_position) < b.global_position.distance_squared_to(source.global_position))
				if not allies.is_empty():
					var protection = 30 if TalentTree.has(source.talents, "guardian", 2) else 15
					allies[0].upsert_shield(roundi(protection * 0.5), source, 3, "shared_guard")
					CombatFeedback.show_skill_effect(&"shield", allies[0].global_position, source, 94, 0, 0, allies[0])
		"soul_reap":
			if effective > 0 and MasteryCatalog.active(source, "contagion"):
				var candidates = enemies_near(source, target.global_position, 130, target)
				for effect in target.debuffList.duplicate():
					if not is_instance_valid(effect) or not effect is DamageOverTime or effect.casterCharacter != source:
						continue
					var remaining = minf(6, effect.skillDotSeconds - effect.skillTimer)
					if remaining <= 0:
						continue
					for index in mini(2, candidates.size()):
						source.get_tree().current_scene.get_node("SkillHandler").copy_dot.rpc(effect.skillScenePath, int(source.name), int(candidates[index].name), remaining)
		"aimed_shot":
			if effective > 0 and MasteryCatalog.active(source, "piercing"):
				var bolt = PiercingArrow.new()
				bolt.source = source
				bolt.origin = target.global_position
				bolt.direction = skill.facing
				bolt.excluded_id = int(target.name)
				bolt.power = maxi(1, roundi(int(skill.data.power) * TalentTree.skill_damage(source.talents, skill) * 0.45))
				source.get_tree().current_scene.add_child(bolt)

static func periodic(skill: HeroAbility) -> void:
	var source = skill.casterCharacter
	if not source.multiplayer.is_server():
		return
	if skill.ability_id == "consecration" and MasteryCatalog.active(source, "protective_ground"):
		for ally in allies_near(source, skill.global_position, float(skill.data.radius)):
			ally.upsert_shield(4, source, 1.2, "protective_ground")
	if skill.ability_id == "bladestorm" and MasteryCatalog.active(source, "drag"):
		var now = Time.get_ticks_msec()
		for enemy in enemies_near(source, source.global_position, float(skill.data.radius)):
			if enemy is LesserEnemy and now >= int(skill.drag_ready.get(int(enemy.name), 0)):
				skill.drag_ready[int(enemy.name)] = now + 2000
				enemy.global_position = ArenaNavigation.move(enemy.global_position, enemy.global_position.direction_to(source.global_position) * minf(35, enemy.global_position.distance_to(source.global_position)))

static func poison_death(victim: Character) -> void:
	if not victim.multiplayer.is_server():
		return
	for effect in victim.debuffList.duplicate():
		if not is_instance_valid(effect) or not effect is HeroAbility or effect.ability_id != "poison_arrow" or effect.secondary_effect:
			continue
		var source = effect.casterCharacter
		if not MasteryCatalog.active(source, "infection") or source.charCurrentLife <= 0:
			continue
		var remaining = minf(4, float(effect.data.duration) - effect.elapsed)
		if remaining <= 0:
			continue
		var targets = enemies_near(source, victim.global_position, 160, victim)
		for index in mini(2, targets.size()):
			source.get_tree().current_scene.get_node("SkillHandler").copy_dot.rpc(effect.skillScenePath, int(source.name), int(targets[index].name), remaining)

static func circuit(source: Character, target: Character) -> void:
	if not source.multiplayer.is_server():
		return
	if MasteryCatalog.active(source, "conductive_rivet"):
		var targets = enemies_near(source, target.global_position, 180, target)
		if not targets.is_empty():
			secondary(source, targets[0], 7, target.global_position, "rivet")
	elif MasteryCatalog.active(source, "shelter_circuit"):
		var point: Vector2 = source.get("beacon_position")
		for ally in allies_near(source, point, 165):
			ally.upsert_shield(6, source, 2, "shelter_circuit")
			CombatFeedback.show_skill_effect(&"shield", ally.global_position, source, 84, 0, 0, ally)
