class_name EngineerAbility
extends HeroAbility

@export var ability: String:
	set(value):
		ability = value
		configure(value)

func cast_requirement(caster: Character, ground: Vector2 = Vector2.INF) -> String:
	match ability_id:
		"field_beacon", "valve_burst":
			if not ground.is_finite():
				return "Escolha um ponto no chão"
			if ability_id == "field_beacon" and not ArenaNavigation.allowed(ground):
				return "Coloque a Baliza em terreno livre"
		"overload":
			var engineer = caster as Engineer
			if engineer.beacon_remaining <= 0:
				return "Instale uma Baliza primeiro"
			if engineer.global_position.distance_to(engineer.beacon_position) > cast_range:
				return "Baliza fora do alcance"
	return ""

func target_description() -> String:
	return "Sua Baliza de Campo ativa" if ability_id == "overload" else super.target_description()

func cast(caster: Character, target: Character) -> void:
	casterCharacter = caster
	targetCharacter = target
	var engineer = caster as Engineer
	match ability_id:
		"rivet_shot":
			var projectile = CombatProjectile.new()
			get_parent().add_child(projectile)
			projectile.hit.connect(engineer.on_rivet_hit)
			projectile.launch(caster, target, int(data.power), "rivet_skill", caster.global_position)
		"field_beacon":
			if multiplayer.is_server():
				engineer.deploy_beacon(aim_position, float(data.duration))
		"valve_burst":
			global_position = aim_position
			if multiplayer.is_server():
				burst(engineer)
			return
		"overload":
			if multiplayer.is_server():
				engineer.start_overload()
	queue_free()

func burst(engineer: Engineer) -> void:
	var linked = engineer.in_beacon(global_position)
	var protective = linked and TalentTree.has(engineer.talents, "safeguard", 2)
	var chain = linked and TalentTree.has(engineer.talents, "workshop", 2)
	var power = 31 if linked and not protective else int(data.power)
	cue(&"valve", global_position, float(data.radius) * 2, 0.0, 1 if linked else 0)
	if linked:
		var offset = global_position - engineer.beacon_position
		cue(&"link", engineer.beacon_position, offset.length(), offset.angle())
	var extra_target: Character
	var extra_distance = 200.0
	for target in all_characters():
		if not is_instance_valid(target) or target.charCurrentLife <= 0 or target.spectator:
			continue
		var distance = target.global_position.distance_to(global_position)
		if target.charTeam == engineer.charTeam:
			if protective and distance <= float(data.radius):
				target.apply_shield(10, engineer, 3.0)
				cue(&"shield", target.global_position, 92, 0, 0, target)
		elif distance <= float(data.radius):
			hurt(target, power)
		elif chain and distance <= extra_distance:
			extra_target = target
			extra_distance = distance
	if extra_target != null:
		hurt(extra_target, 10)
		var arc = extra_target.global_position - global_position
		cue(&"link", global_position, arc.length(), arc.angle())

func _physics_process(delta: float) -> void:
	if not living():
		queue_free()
		return
	elapsed += delta
	if elapsed >= 0.45:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if ability_id != "valve_burst":
		return
	var progress = clampf(elapsed / 0.45, 0, 1)
	var radius = float(data.radius)
	SkillFX.rim(self, Vector2.ZERO, radius, Color(tint, 0.35 * (1.0 - progress)), 8)
