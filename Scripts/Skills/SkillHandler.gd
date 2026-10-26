class_name SKillHandler extends Node

@onready var player_cast_bar: Control = $"../PlayerCastBar"
var cooldowns: Dictionary = {}
var casting: Dictionary = {}
var attack_times: Dictionary = {}
var proc_ready: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id: int):
		cooldowns.erase(id)
		casting.erase(id)
		attack_times.erase(id)
		proc_ready.erase(id))

func encounter_finished() -> bool:
	var encounter = get_parent().get_node_or_null("BossEncounter")
	return encounter != null and encounter.status in ["victory", "defeat"]

func valid_sender(id: int) -> bool:
	var sender = multiplayer.get_remote_sender_id()
	return (sender == id) or (sender == 0 and id == multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func loadSkillScene(filePath: String, idCasterChar: int, idTargetChar: int) -> void:
	if encounter_finished() or not multiplayer.is_server() or not valid_sender(idCasterChar):
		return
	var caster: Character = MultiplayerManager.playerList.get(idCasterChar)
	if not is_instance_valid(caster) or caster.charCurrentLife <= 0 or casting.has(idCasterChar):
		return
	var template: Skill
	for candidate in caster.skillList:
		if candidate.skillScenePath == filePath:
			template = candidate
			break
	if template == null:
		return
	var target: Character = MultiplayerManager.get_character(idTargetChar)
	if template is AreaDamage and not is_instance_valid(target):
		target = caster
	if not is_instance_valid(target) or target.charCurrentLife <= 0:
		return
	var support = template is Heal or template is Shield or template is Buff
	if support and target.charTeam != caster.charTeam:
		return
	if not support and not template is AreaDamage and target.charTeam == caster.charTeam:
		return
	var now = Time.get_ticks_msec()
	var player_cooldowns: Dictionary = cooldowns.get(idCasterChar, {})
	if proc_ready.get(idCasterChar, "") != filePath and now < player_cooldowns.get(filePath, 0):
		return
	if caster.charCurrentMana < template.skillManaCost:
		return
	player_cooldowns[filePath] = now + int(template.skillCoolDownTime * 1000)
	cooldowns[idCasterChar] = player_cooldowns
	caster.charCurrentMana -= template.skillManaCost
	var duration = 0.0 if proc_ready.get(idCasterChar, "") == filePath else template.skillCastTime
	proc_ready.erase(idCasterChar)
	template.resetCastTime = false
	template.resetCoolDown = false
	if duration > 0:
		casting[idCasterChar] = true
		await get_tree().create_timer(duration).timeout
		casting.erase(idCasterChar)
	if encounter_finished() or not is_instance_valid(caster) or not is_instance_valid(target):
		return
	if caster.charCurrentLife <= 0 or target.charCurrentLife <= 0:
		return
	if template is DamageOverTime:
		for effect in target.debuffList:
			if is_instance_valid(effect) and effect.get_script() == template.get_script() and effect.casterCharacter == caster:
				refresh_dot.rpc(filePath, idCasterChar, idTargetChar)
				return
	play_skill.rpc(template.skillScenePath, idCasterChar, int(target.name))

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
func play_skill(path: String, caster_id: int, target_id: int) -> void:
	var caster: Character = MultiplayerManager.playerList.get(caster_id)
	var target: Character = MultiplayerManager.get_character(target_id)
	if not is_instance_valid(caster) or not is_instance_valid(target):
		return
	var skill: Skill = load(path).instantiate()
	if multiplayer.is_server():
		checkPassive(skill, caster)
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
	if caster.charCurrentLife <= 0 or target.charCurrentLife <= 0 or casting.has(caster_id):
		return
	if caster.global_position.distance_to(target.global_position) > caster.charRange:
		return
	var now = Time.get_ticks_msec()
	if now < attack_times.get(caster_id, 0):
		return
	attack_times[caster_id] = now + 1000
	target.deal_damage(caster.charBaseDamage, caster)

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
