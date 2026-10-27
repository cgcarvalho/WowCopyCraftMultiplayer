class_name SKillHandler extends Node

@onready var player_cast_bar: Control = $"../PlayerCastBar"
var cooldowns: Dictionary = {}
var casting: Dictionary = {}
var attack_times: Dictionary = {}
var proc_ready: Dictionary = {}
var round_token = 0
var cast_serial = 0
signal combat_reset

func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id: int):
		cooldowns.erase(id)
		casting.erase(id)
		attack_times.erase(id)
		proc_ready.erase(id))

func encounter_finished() -> bool:
	var encounter = get_parent().get_node_or_null("BossEncounter")
	var session = get_parent().get_node_or_null("Session")
	return (session != null and session.running and session.stage != "active") or (encounter != null and encounter.status in ["victory", "defeat"])

func valid_sender(id: int) -> bool:
	var sender = multiplayer.get_remote_sender_id()
	return (sender == id) or (sender == 0 and id == multiplayer.get_unique_id())

signal cast_confirmed(caster_id: int, path: String, accepted: bool, duration: float, cooldown: float)

func selected_target(template: Skill, caster: Character, target_id: int) -> Character:
	if template.targeting() == Skill.TargetMode.SELF:
		return caster
	var target = MultiplayerManager.get_character(target_id)
	if target == null and template.targeting() in [Skill.TargetMode.ALLY, Skill.TargetMode.GROUND]:
		return caster
	return target

func valid_target(template: Skill, caster: Character, target: Character) -> bool:
	if not is_instance_valid(target) or target.charCurrentLife <= 0:
		return false
	var mode = template.targeting()
	if mode == Skill.TargetMode.ENEMY and target.charTeam == caster.charTeam:
		return false
	if mode == Skill.TargetMode.ALLY and target.charTeam != caster.charTeam:
		return false
	return mode == Skill.TargetMode.SELF or caster.global_position.distance_to(target.global_position) <= template.cast_range

@rpc("authority", "call_local", "reliable")
func cast_result(caster_id: int, path: String, accepted: bool, duration: float, cooldown: float) -> void:
	cast_confirmed.emit(caster_id, path, accepted, duration, cooldown)
	var caster = MultiplayerManager.playerList.get(caster_id)
	if accepted and is_instance_valid(caster):
		caster.play_ability(duration)
		CombatFeedback.play_sound("cast")

func valid_ground(template: Skill, caster: Character, point: Vector2) -> bool:
	return template.targeting() == Skill.TargetMode.GROUND and point.is_finite() and ArenaNavigation.BOUNDS.has_point(point) and caster.global_position.distance_to(point) <= template.cast_range

@rpc("any_peer", "call_local", "reliable")
func loadSkillScene(filePath: String, idCasterChar: int, idTargetChar: int, ground: Vector2 = Vector2.INF) -> void:
	if not multiplayer.is_server() or not valid_sender(idCasterChar):
		return
	var caster: Character = MultiplayerManager.playerList.get(idCasterChar)
	var template: Skill
	if is_instance_valid(caster):
		for candidate in caster.skillList:
			if candidate.skillScenePath == filePath:
				template = candidate
				break
	if encounter_finished() or template == null or caster.charCurrentLife <= 0 or caster.spectator or casting.has(idCasterChar):
		cast_result.rpc(idCasterChar, filePath, false, 0.0, 0.0)
		return
	var explicit_ground = ground != Vector2.INF
	if explicit_ground and not valid_ground(template, caster, ground):
		cast_result.rpc(idCasterChar, filePath, false, 0.0, 0.0)
		return
	var target = caster if explicit_ground else selected_target(template, caster, idTargetChar)
	var now = Time.get_ticks_msec()
	var player_cooldowns: Dictionary = cooldowns.get(idCasterChar, {})
	var proc = proc_ready.get(idCasterChar, "") == filePath
	if not valid_target(template, caster, target) or (not proc and now < player_cooldowns.get(filePath, 0)) or caster.charCurrentMana < template.skillManaCost:
		cast_result.rpc(idCasterChar, filePath, false, 0.0, 0.0)
		return
	var cooldown = template.skillCoolDownTime * caster.cooldown_multiplier
	player_cooldowns[filePath] = now + int(cooldown * 1000)
	cooldowns[idCasterChar] = player_cooldowns
	caster.charCurrentMana -= template.skillManaCost
	var duration = 0.0 if proc else template.skillCastTime
	proc_ready.erase(idCasterChar)
	template.resetCastTime = false
	template.resetCoolDown = false
	var token = round_token
	cast_serial += 1
	var serial = cast_serial
	if duration > 0:
		casting[idCasterChar] = {"serial": serial, "origin": caster.global_position}
	cast_result.rpc(idCasterChar, filePath, true, duration, cooldown)
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		if token != round_token or not casting.has(idCasterChar) or casting[idCasterChar].serial != serial:
			return
		casting.erase(idCasterChar)
	if token != round_token or encounter_finished() or not is_instance_valid(caster) or not is_instance_valid(target):
		return
	if caster.charCurrentLife <= 0 or not valid_target(template, caster, target):
		return
	if explicit_ground and not valid_ground(template, caster, ground):
		return
	if template is DamageOverTime:
		for effect in target.debuffList:
			if is_instance_valid(effect) and effect.get_script() == template.get_script() and effect.casterCharacter == caster:
				refresh_dot.rpc(filePath, idCasterChar, int(target.name))
				return
	play_skill.rpc(template.skillScenePath, idCasterChar, int(target.name), ground)

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for id in casting.keys():
		var caster = MultiplayerManager.playerList.get(id)
		if not is_instance_valid(caster) or caster.charCurrentLife <= 0 or caster.global_position.distance_to(casting[id].origin) > 14:
			casting.erase(id)
			cancel_cast.rpc(id)

@rpc("authority", "call_local", "reliable")
func cancel_cast(id: int) -> void:
	var caster = MultiplayerManager.playerList.get(id)
	if is_instance_valid(caster):
		caster.ability_animation_time = 0
	if multiplayer.get_unique_id() == id:
		player_cast_bar.cancel_cast()
		get_parent().get_node("SkillBar").show_feedback("Conjuração interrompida")

func reset_combat() -> void:
	round_token += 1
	cooldowns.clear()
	casting.clear()
	attack_times.clear()
	proc_ready.clear()
	combat_reset.emit()

@rpc("any_peer", "call_local", "reliable")
func request_interrupt() -> void:
	if not multiplayer.is_server() or encounter_finished():
		return
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	var caster: Character = MultiplayerManager.playerList.get(id)
	var encounter = get_parent().get_node("BossEncounter")
	if not is_instance_valid(caster) or caster.charCurrentLife <= 0 or caster.spectator or caster.interrupt_remaining > 0:
		return
	var reach = 200.0 if caster.charClass == "Warrior" else 650.0
	if caster.global_position.distance_to(encounter.boss.global_position) > reach:
		return
	if encounter.interrupt_channel(caster):
		caster.interrupt_remaining = 16.0
		interrupt_feedback.rpc(id)

@rpc("authority", "call_local", "reliable")
func interrupt_feedback(_id: int) -> void:
	CombatFeedback.play_sound("interrupt")
	get_parent().get_node("SkillBar").show_feedback("Cataclismo interrompido!")

@rpc("authority", "call_local", "reliable")
func refresh_dot(path: String, caster_id: int, target_id: int) -> void:
	var target = MultiplayerManager.get_character(target_id)
	var caster = MultiplayerManager.playerList.get(caster_id)
	if not is_instance_valid(target) or not is_instance_valid(caster):
		return
	for effect in target.debuffList:
		if is_instance_valid(effect) and effect.skillScenePath == path and effect.casterCharacter == caster:
			effect.renewDot()
			return

# Only the server broadcasts effects; clients animate, server mutates combat state.
@rpc("authority", "call_local", "reliable")
func play_skill(path: String, caster_id: int, target_id: int, ground: Vector2 = Vector2.INF) -> void:
	var caster: Character = MultiplayerManager.playerList.get(caster_id)
	var target: Character = MultiplayerManager.get_character(target_id)
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	var skill: Skill = load(path).instantiate()
	TalentTree.configure_skill(skill, caster.talents)
	if multiplayer.is_server():
		checkPassive(skill, caster)
	skill.aim_position = ground
	get_parent().add_child(skill)
	skill.cast(caster, target)

@rpc("any_peer", "call_local", "reliable")
func basic_attack(caster_id: int, target_id: int) -> void:
	if encounter_finished() or not multiplayer.is_server() or not valid_sender(caster_id):
		return
	var caster: Character = MultiplayerManager.playerList.get(caster_id)
	var target: Character = MultiplayerManager.get_character(target_id)
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	if caster.charTeam == target.charTeam:
		return
	if caster.charCurrentLife <= 0 or target.charCurrentLife <= 0 or caster.spectator or target.spectator or casting.has(caster_id):
		return
	if caster.global_position.distance_to(target.global_position) > caster.charRange:
		return
	var now = Time.get_ticks_msec()
	if now < attack_times.get(caster_id, 0):
		return
	attack_times[caster_id] = now + int(caster.attack_interval * 1000)
	play_basic_attack.rpc(caster_id, target_id, caster.charBaseDamage, caster.attack_style)

@rpc("authority", "call_local", "reliable")
func play_basic_attack(caster_id: int, target_id: int, amount: int, style: String) -> void:
	var caster = MultiplayerManager.get_character(caster_id)
	var target = MultiplayerManager.get_character(target_id)
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	var projectile = CombatProjectile.new()
	get_parent().add_child(projectile)
	projectile.basic = true
	projectile.launch(caster, target, amount, style, caster.global_position)

@rpc("authority", "call_remote", "reliable")
func reset_skill(path: String, owner_id: int) -> void:
	var player: Character = MultiplayerManager.playerList.get(owner_id)
	if is_instance_valid(player):
		for skill in player.skillList:
			if skill.skillScenePath == path:
				skill.resetCoolDown = true
				skill.resetCastTime = true

func checkPassive(skill: Skill, caster: Character) -> void:
	if skill is DamageOverTime and caster.passiveSkill is DotMaster:
		skill.onDamage.connect(caster.passiveSkill.on_proc)

func castBar(skillName: String, castTime: float) -> void:
	player_cast_bar.start_cast(skillName, castTime)
