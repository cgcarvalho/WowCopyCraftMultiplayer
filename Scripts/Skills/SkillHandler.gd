

class_name SKillHandler extends Node
@onready var player_cast_bar: Control = $"../PlayerCastBar"
@onready var target_cast_bar: Control = $"../TargetCastBar"


@rpc("any_peer", "call_local")
func loadSkillScene(filePath : String, idCasterChar : int, idTargetChar : int) -> void:
	var loadSkill : Skill = load(filePath).instantiate()
	var target_player : Character = MultiplayerManager.playerList.get(idTargetChar)
	var caster_player : Character = MultiplayerManager.playerList.get(idCasterChar)
	
	caster_player.charCurrentMana -= loadSkill.skillManaCost
	
	checkPassive(loadSkill, caster_player)
	
	var listSkill = target_player.debuffList.filter(func(n): return typeof(n) == typeof(loadSkill))
	if len(listSkill) > 0:
		var skill : DamageOverTime  = listSkill[0]
		skill.renewDot()
	else:
		get_parent().add_child(loadSkill)
		loadSkill.cast(caster_player, target_player)
	


func checkPassive(skill : Skill, caster : Character) -> void:
	if skill is DamageOverTime:
		if caster.passiveSkill and (caster.passiveSkill is DotMaster):
			skill.onDamage.connect(caster.passiveSkill.on_proc)
		
		
func castBar(skillName : String, castTime : float) -> void:
	player_cast_bar.start_cast(skillName, castTime) 
	target_cast_bar.start_cast(skillName, castTime) 
	
