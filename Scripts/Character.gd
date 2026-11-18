extends Area2D
class_name Character

enum Teams {RED, BLUE}

var state_machine: StateStrategy
var ui_handler: UIHandler
var isCrit : bool = false
@export var speed = 5.0
var portraitImagePath : String
var portrait_icon: Texture2D
var scenePath : String
var charTeam : Teams = Teams.BLUE

#region Character Properties
#HP
var charTotalLife: int = 0
var charCurrentLife: int:
	set(value):
		charCurrentLife = clamp(value, 0, charTotalLife)

#Mana
var charTotalMana: float = 0
var charCurrentMana:float:
	set(value):
		charCurrentMana = clamp(value, 0, charTotalMana)
var manaRegen : float = 0

#Defense
var charShield : int = 0


#Basic Stats
var charName: String
var charBaseDamage : int
var charCritChance : float = Constants.DEFAULT_CRIT_CHANCE
var charLifeStealPercent : float = Constants.DEFAULT_LIFE_STEAL
var charRange : float
var charClass = ""
var attack_interval = 1.0
var attack_style = "melee"
var ability_animation_time = 0.0
var ability_pose: StringName = &"cast"
var ability_pose_speed := 1.0
var cast_visual = ""
var ability_animation_length = 0.45
var aura_was_active = false
var aura_flash = 0.0
var basic_animation_remaining = 0.0
var last_move_direction = Vector2.RIGHT
var resource_name = "Mana"
var resource_color = Color("6579f5")
var spectator = false
var interrupt_remaining = 0.0
var momentum = 0
var momentum_time = 0.0
var steady_time = 0.0
var shadow_bolt_ready = false
var previous_position = Vector2.ZERO
var flash_time = 0.0
var flash_color = Color.WHITE
var death_progress = 0.0
var base_life = 100
var damage_bonus = 1.0
var healing_bonus = 1.0
var cooldown_multiplier = 1.0
var talents: Dictionary = {}
var mastery = ""
var shield_sources: Array = []

#Skills
var skillList : Array[Skill] 
var buffList : Array[Skill]
var debuffList : Array[Skill]
var passiveSkill : PassiveSkill

#Target
var charCurrentTarget : Character

#endregion

func _enter_tree() -> void:
	if not is_inside_tree():
		return
	var config = SceneReplicationConfig.new()
	for property in ["charCurrentLife", "charCurrentMana", "charShield", "charTotalLife", "momentum", "momentum_time", "steady_time", "shadow_bolt_ready", "spectator", "damage_bonus", "healing_bonus", "cooldown_multiplier", "interrupt_remaining", "talents", "mastery"]:
		var path = NodePath(".:" + property)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "CombatSynchronizer"
	sync.replication_config = config
	sync.set_multiplayer_authority(1)
	add_child(sync)

func _ready() -> void:
	previous_position = global_position
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.sprite_frames = sprite.sprite_frames.duplicate()
	var frames = sprite.sprite_frames
	if not frames.has_animation("auto_attack"):
		copy_animation(frames, "cast", "auto_attack", true)
	if not frames.has_animation("cast"):
		copy_animation(frames, "auto_attack", "cast", false)
	frames.set_animation_loop("auto_attack", true)
	frames.set_animation_speed("auto_attack", frames.get_frame_count("auto_attack") / attack_interval)
	var main = get_parent().get_parent()
	state_machine = StateStrategy.new($AnimatedSprite2D, self, main)
	ui_handler = UIHandler.new(main)
	
	if is_multiplayer_authority(): 
		ui_handler.showPlayerHPBar(self, true)
		ui_handler.createSkillBar()

	
func _physics_process(delta: float) -> void:
	ability_animation_time = maxf(0.0, ability_animation_time - delta)
	basic_animation_remaining = maxf(0, basic_animation_remaining - delta)
	var session = get_tree().current_scene.get_node_or_null("Session") if get_tree().current_scene != null else null
	visible = not spectator and (session == null or not session.running or session.stage not in ["lobby", "menu"])
	if spectator or (session != null and session.running and session.stage != "active"):
		if charCurrentLife > 0:
			$AnimatedSprite2D.play("idle")
		return
	if charCurrentLife <= 0:
		die()
		return
	if multiplayer.is_server():
		expire_shields()
		update_class_passive(delta)
		if passiveSkill:
			passiveSkill.physics_process(delta)
		if charTotalMana > 0:
			charCurrentMana += manaRegen * delta
	if charCurrentLife <= 0:
		die()
		return
	if not is_multiplayer_authority():
		if not $AnimatedSprite2D.is_playing():
			$AnimatedSprite2D.play()
		return
	
	if state_machine:
		state_machine._physics_process(delta)
	
	
	if is_instance_valid(charCurrentTarget):
		$AnimatedSprite2D.flip_h = global_position.x < charCurrentTarget.global_position.x
	if ability_animation_time > 0:
		$AnimatedSprite2D.play(ability_pose, ability_pose_speed)
	
	if charCurrentLife <= 0:
		die()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_player = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
		if not is_instance_valid(local_player):
			return
		var preview = get_tree().current_scene.get_node_or_null("CombatPreview")
		if preview != null and preview.aiming:
			return
		if preview != null:
			preview.select_target(self)
			return
		local_player.charCurrentTarget = self
		ui_handler.showTargetHPBar(self, local_player == self)

func battle_report() -> BattleReport:
	var scene = get_tree().current_scene
	var session = scene.get_node_or_null("Session") if scene != null else null
	return session.combat_report if session != null and session.running and session.stage == "active" else null

func minimum_life_after_damage() -> int:
	return 0

func deal_damage(damage: int, source: Character = null, periodic: bool = false, skill_multiplier: float = 1.0) -> void:
	if not multiplayer.is_server() or charCurrentLife <= 0 or damage <= 0 or spectator:
		return
	var chance = source.charCritChance if is_instance_valid(source) else charCritChance
	isCrit = randf() < chance
	var multiplier = source.outgoing_damage_multiplier(periodic) if is_instance_valid(source) else 1.0
	multiplier *= skill_multiplier
	damage = maxi(1, roundi(damage * multiplier * (Constants.CRIT_MULTIPLIER if isCrit else 1.0)))
	if TalentTree.has(talents, "guardian", 1) or TalentTree.has(talents, "bulwark", 1):
		damage = maxi(1, roundi(damage * 0.9))
	if has_paladin_aura():
		damage = maxi(1, roundi(damage * (1 - ClassPassives.AURA_REDUCTION)))
	expire_shields()
	var absorbed = mini(charShield, damage)
	consume_shield(absorbed)
	charShield -= absorbed
	damage -= absorbed
	var before = charCurrentLife
	var life_floor = minimum_life_after_damage()
	if life_floor > 0:
		damage = mini(damage, maxi(0, before - life_floor))
	charCurrentLife -= damage
	if before > 0 and charCurrentLife == 0:
		MasteryEffects.poison_death(self)
	var report = battle_report()
	if report != null:
		report.damage(self, source, before - charCurrentLife, charCurrentLife == 0)
	if charClass == "Warrior":
		gain_resource(8)
	if damage > 0:
		DamageNumbers.display_number.rpc(damage, global_position, isCrit, false, periodic)
	CombatFeedback.impact.rpc(int(name), global_position, "shield" if damage == 0 else ("crit" if isCrit else "hit"), int(source.name) if is_instance_valid(source) else 0, periodic)

func apply_heal(heal: int, source: Character = null) -> void:
	if not multiplayer.is_server() or charCurrentLife <= 0 or heal <= 0 or spectator:
		return
	var multiplier = source.healing_bonus if is_instance_valid(source) else 1.0
	if has_paladin_aura():
		multiplier *= 1 + ClassPassives.AURA_HEAL
	var before = charCurrentLife
	charCurrentLife += roundi(heal * multiplier)
	var report = battle_report()
	if report != null:
		report.heal(source, charCurrentLife - before)
	if charCurrentLife > before:
		DamageNumbers.display_number.rpc(charCurrentLife - before, global_position, false, true)
		CombatFeedback.impact.rpc(int(name), global_position, "heal", int(source.name) if is_instance_valid(source) else 0)

func apply_shield(shield: int, source: Character = null, duration: float = 0.0) -> void:
	if not multiplayer.is_server() or charCurrentLife <= 0 or spectator:
		return
	expire_shields()
	if shield <= charShield:
		return
	reconcile_shield_sources()
	var contribution = {"id": int(source.name) if is_instance_valid(source) else 0, "amount": shield - charShield}
	if duration > 0:
		contribution.expires_at = Time.get_ticks_msec() + roundi(duration * 1000)
	shield_sources.append(contribution)
	charShield = shield
	if shield > 0:
		CombatFeedback.impact.rpc(int(name), global_position, "shield", int(source.name) if is_instance_valid(source) else 0)

func reconcile_shield_sources() -> void:
	var total = 0
	for contribution in shield_sources:
		total += int(contribution.amount)
	if total != charShield:
		# Legacy/debug direct assignments have no known provider.
		shield_sources = [{"id": 0, "amount": charShield}] if charShield > 0 else []

func has_sourced_shield(source_id: int, key: String) -> bool:
	for contribution in shield_sources:
		if int(contribution.id) == source_id and contribution.get("key", "") == key and int(contribution.amount) > 0:
			return true
	return false

func remove_sourced_shield(source_id: int, key: String) -> void:
	if not multiplayer.is_server():
		return
	reconcile_shield_sources()
	for index in range(shield_sources.size() - 1, -1, -1):
		var contribution: Dictionary = shield_sources[index]
		if int(contribution.id) == source_id and contribution.get("key", "") == key:
			charShield = maxi(0, charShield - int(contribution.amount))
			shield_sources.remove_at(index)

func upsert_shield(amount: int, source: Character, duration: float, key: String) -> void:
	if not multiplayer.is_server() or charCurrentLife <= 0 or spectator or not is_instance_valid(source) or amount <= 0:
		return
	expire_shields()
	remove_sourced_shield(int(source.name), key)
	shield_sources.append({"id": int(source.name), "amount": amount, "key": key, "expires_at": Time.get_ticks_msec() + roundi(duration * 1000)})
	charShield += amount

func expire_shields() -> void:
	if shield_sources.is_empty():
		return
	var now = Time.get_ticks_msec()
	for index in range(shield_sources.size() - 1, -1, -1):
		var contribution: Dictionary = shield_sources[index]
		if contribution.get("expires_at", now + 1) <= now:
			charShield = maxi(0, charShield - int(contribution.amount))
			shield_sources.remove_at(index)

func consume_shield(amount: int) -> void:
	reconcile_shield_sources()
	var report = battle_report()
	while amount > 0 and not shield_sources.is_empty():
		var contribution: Dictionary = shield_sources[0]
		var used = mini(amount, int(contribution.amount))
		if report != null:
			report.add(int(contribution.id), "absorbed", used)
		contribution.amount -= used
		amount -= used
		if contribution.amount <= 0:
			shield_sources.pop_front()

func apply_crit(damage : int) -> int:
	var random_value = randf()
	var newDamage = damage
	isCrit = random_value < charCritChance

	if isCrit:
		newDamage = damage * Constants.CRIT_MULTIPLIER
	
	return newDamage

func die() -> void:
	$AnimatedSprite2D.stop()
	modulate = Color(0.5, 0.5, 0.5, 0.65)
	if is_instance_valid(state_machine) and state_machine.current_state is Attack:
		state_machine.set_state(Idle.new())
	# Keep the node alive for presentation and in-place round resets.


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for skill in skillList:
			if is_instance_valid(skill) and not skill.is_inside_tree():
				skill.free()
		if is_instance_valid(passiveSkill):
			passiveSkill.free()
		if is_instance_valid(state_machine):
			if is_instance_valid(state_machine.current_state):
				state_machine.current_state.free()
			state_machine.free()
		if is_instance_valid(ui_handler):
			ui_handler.free()

func copy_animation(frames: SpriteFrames, source: StringName, destination: StringName, looped: bool) -> void:
	if not frames.has_animation(source):
		source = &"idle"
	frames.add_animation(destination)
	frames.set_animation_loop(destination, looped)
	frames.set_animation_speed(destination, frames.get_animation_speed(source))
	for index in frames.get_frame_count(source):
		frames.add_frame(destination, frames.get_frame_texture(source, index), frames.get_frame_duration(source, index))

func play_ability(duration: float, path: String = "") -> void:
	cast_visual = path.get_file().get_basename()
	var pose: StringName = &"cast"
	match cast_visual:
		"aimed_shot": pose = &"pose_aimed"
		"charge": pose = &"pose_charge"
		"field_beacon", "valve_burst", "overload": pose = &"pose_device"
	var body: AnimatedSprite2D = $AnimatedSprite2D
	ability_pose = pose if body.sprite_frames.has_animation(pose) else &"cast"
	ability_animation_length = maxf(duration, 0.65 if ability_pose == &"pose_device" else 0.45)
	ability_animation_time = ability_animation_length
	ability_pose_speed = 1.0
	if ability_pose == &"pose_aimed":
		var frames = body.sprite_frames
		var art_duration = frames.get_frame_count(ability_pose) / frames.get_animation_speed(ability_pose)
		ability_pose_speed = art_duration / ability_animation_length
	body.play(ability_pose, ability_pose_speed)

func weapon_offset(style: String, aim: Vector2) -> Vector2:
	var side = -1.0 if aim.x < 0.0 else 1.0
	match style:
		"arrow", "arrow_fork", "aimed", "poison": return Vector2(side * 49, -20)
		"rivet", "rivet_skill": return Vector2(side * 33, -20)
		"magic", "bolt": return Vector2(side * 29, -21)
		"hammer", "holy": return Vector2(side * 51, -31)
	return Vector2.ZERO

func play_skill_animation(_skill: Skill) -> void:
	pass

func play_basic_attack_animation(target: Character) -> void:
	basic_animation_remaining = 0.24
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.flip_h = global_position.x < target.global_position.x
	sprite.play("auto_attack")
	sprite.set_frame_and_progress(int(sprite.sprite_frames.get_frame_count("auto_attack") * 0.35), 0)

func configure_resource() -> void:
	match charClass:
		"Warrior":
			resource_name = "Raiva"
			resource_color = Color("e68249")
			charTotalMana = 100
			charCurrentMana = 0
			manaRegen = 0
		"Paladin":
			resource_name = "Poder sagrado"
			resource_color = Color("e9c762")
			charTotalMana = 5
			charCurrentMana = 2
			manaRegen = 0
		"Hunter":
			resource_name = "Foco"
			resource_color = Color("74c988")
			charTotalMana = 100
			charCurrentMana = 100
			manaRegen = 8

	for skill in skillList:
		skill.cost_label = resource_name

func gain_resource(amount: float) -> void:
	if multiplayer.is_server() and charCurrentLife > 0:
		charCurrentMana += amount

func on_basic_hit(_target: Character = null) -> void:
	if not multiplayer.is_server():
		return
	if charClass == "Warrior":
		gain_resource(16 if TalentTree.has(talents, "berserker", 2) else 12)
		momentum = mini(ClassPassives.MOMENTUM_MAX, momentum + 1)
		momentum_time = ClassPassives.MOMENTUM_SECONDS
	elif charClass == "Paladin":
		gain_resource(1)

func update_class_passive(delta: float) -> void:
	interrupt_remaining = maxf(0, interrupt_remaining - delta)
	var moved = global_position.distance_to(previous_position) > 0.5
	steady_time = 0 if moved else minf(2.0, steady_time + delta)
	previous_position = global_position
	momentum_time = maxf(0, momentum_time - delta)
	if momentum_time <= 0:
		momentum = 0

func outgoing_damage_multiplier(periodic: bool = false) -> float:
	var result = damage_bonus
	if periodic and TalentTree.has(talents, "affliction", 1):
		result *= 1.2
	if charClass == "Warrior":
		result *= 1.0 + momentum * ClassPassives.MOMENTUM_DAMAGE
	elif charClass == "Hunter" and steady_time >= ClassPassives.STEADY_SECONDS:
		result *= 1 + (ClassPassives.STEADY_TALENT_DAMAGE if TalentTree.has(talents, "marksman", 3) else ClassPassives.STEADY_DAMAGE)
	return result

func has_paladin_aura() -> bool:
	if charTeam != Teams.BLUE:
		return false
	for hero in MultiplayerManager.playerList.values():
		if is_instance_valid(hero) and hero.charClass == "Paladin" and hero.charCurrentLife > 0 and not hero.spectator and hero.global_position.distance_to(global_position) <= ClassPassives.AURA_RADIUS:
			return true
	return false

func passive_text() -> String:
	return ClassPassives.definition(charClass, talents).name + " · " + ClassPassives.state(self).text

func _process(delta: float) -> void:
	update_presentation(delta)
	if multiplayer.get_unique_id() == int(name):
		var aura_now = has_paladin_aura()
		if aura_now != aura_was_active:
			aura_was_active = aura_now
			aura_flash = 0.46
		aura_flash = maxf(0.0, aura_flash - delta)
		queue_redraw()

func _draw() -> void:
	if spectator or charCurrentLife <= 0 or multiplayer.get_unique_id() != int(name):
		return
	var side = 1.0 if $AnimatedSprite2D.flip_h else -1.0
	var point = Vector2(side * 60, -44)
	if aura_flash > 0:
		var aura_color = Color(1, 0.88, 0.49, aura_flash * 1.6)
		draw_arc(Vector2(0, 80), 30, PI * 0.1, PI * 0.9, 20, aura_color, 2.5, true)
	if charClass == "Warrior" and charShield > 0:
		draw_arc(Vector2(0, 48), 93, 0.15, PI - 0.15, 38, Color(0.61, 0.88, 1.0, 0.54), 4, true)
	if ability_animation_time > 0:
		var progress = 1.0 - clampf(ability_animation_time / ability_animation_length, 0.0, 1.0)
		match cast_visual:
			"Shadow_bolt", "soul_reap":
				var focus = Vector2(side * 45, -46)
				var pulse = sin(progress * PI) * 0.7
				draw_circle(focus, 9 + progress * 8, Color(0.78, 0.49, 1.0, pulse))
			"aimed_shot":
				var bow_side = point + Vector2(side * 27, 0)
				draw_line(bow_side, bow_side + Vector2(side * lerpf(14, 72, progress), 0), Color(0.8, 1, 0.73, 0.41), 2.5, true)
	var color: Color
	match charClass:
		"Warlock":
			if not shadow_bolt_ready:
				return
			color = Color("cda3ff")
		"Warrior":
			if momentum < ClassPassives.MOMENTUM_MAX:
				return
			color = Color("ffc595")
		"Hunter":
			if steady_time < ClassPassives.STEADY_SECONDS:
				return
			color = Color("c1efae")
		"Paladin":
			return
		_: return
	var radius = 6 + sin(Time.get_ticks_msec() * 0.006) * 1.5
	draw_polyline(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point - Vector2(radius, 0), point + Vector2(0, -radius)]), color, 2.0, true)

func update_presentation(delta: float) -> void:
	flash_time = maxf(0, flash_time - delta)
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.modulate = flash_color if flash_time > 0 else Color.WHITE
	if charCurrentLife <= 0:
		sprite.stop()
		death_progress = minf(1, death_progress + delta * 1.5)
		sprite.rotation = -0.8 * death_progress
		modulate = Color(0.7, 0.7, 0.7, 1 - death_progress * 0.75)

func reset_for_round(point: Vector2, choices: Dictionary, selected_talents: Dictionary = {}, selected_mastery: String = "") -> void:
	talents = selected_talents.duplicate(true) if TalentTree.valid(charClass, selected_talents) else {}
	mastery = selected_mastery if MasteryCatalog.valid(charClass, talents, selected_mastery) else ""
	charTotalLife = roundi(base_life * (1 + 0.2 * int(choices.get("endurance", 0)) + (0.2 if TalentTree.has(talents, "guardian", 3) else 0.0)))
	charCurrentLife = charTotalLife
	charShield = 0
	shield_sources.clear()
	damage_bonus = 1 + 0.12 * int(choices.get("offense", 0))
	healing_bonus = 1 + 0.15 * int(choices.get("mastery", 0))
	if TalentTree.has(talents, "light", 1):
		healing_bonus *= 1.2
	cooldown_multiplier = maxf(0.45, pow(0.88, int(choices.get("mastery", 0))))
	charCurrentMana = charTotalMana
	configure_resource()
	if charClass == "Warlock":
		manaRegen = 5.0 if TalentTree.has(talents, "affliction", 2) else 3.0
	for skill in skillList:
		TalentTree.configure_skill(skill, talents)
		skill.cooldown_scale = cooldown_multiplier
		if MasteryCatalog.affects(mastery, skill):
			skill.talent_description += "\nMaestria · " + MasteryCatalog.DEFINITIONS[mastery].text
	interrupt_remaining = 0
	charCurrentTarget = null
	ability_animation_time = 0
	aura_was_active = false
	aura_flash = 0
	basic_animation_remaining = 0
	momentum = 0
	momentum_time = 0
	steady_time = 0
	shadow_bolt_ready = false
	for skill in skillList:
		skill.resetCoolDown = false
		skill.resetCastTime = false
	flash_time = 0
	death_progress = 0
	spectator = false
	debuffList.clear()
	buffList.clear()
	global_position = point
	previous_position = point
	modulate = Color.WHITE
	$AnimatedSprite2D.rotation = 0
	$AnimatedSprite2D.modulate = Color.WHITE
	$AnimatedSprite2D.speed_scale = 1
	$AnimatedSprite2D.play("idle")
	if is_instance_valid(state_machine):
		state_machine.next_basic_attack_at_msec = 0
		state_machine.set_state(Idle.new())
	var movement_sync = get_node_or_null("MultiplayerSynchronizer")
	if movement_sync != null:
		movement_sync.replication_interval = 0
		movement_sync.delta_interval = 0
	set_physics_process(true)

func _exit_tree() -> void:
	var id = int(name)
	if MultiplayerManager.playerList.get(id) == self:
		MultiplayerManager.playerList.erase(id)
