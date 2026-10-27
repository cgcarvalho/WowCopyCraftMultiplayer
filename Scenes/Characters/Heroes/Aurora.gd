class_name Aurora
extends Character

var image_path = "res://Art/Chars/Aurora - Warlock/AuroraStand.png"
var scene_path = "res://Scenes/Characters/Heroes/Aurora.tscn"

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Aurora"
	charClass = "Warlock"
	charTotalLife = 100
	charCurrentLife = 100
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 3.0
	portraitImagePath = image_path
	scenePath = scene_path
	charBaseDamage = 6
	charRange = 650
	attack_interval = 1.3
	attack_style = "shadow"
	if skillList.is_empty():
		addSkillsChar()
	base_life = charTotalLife
	configure_resource()

func addSkillsChar() -> void:
	skillList.append(ShadowBolt.new())
	skillList.append(Corruption.new())
	skillList.append(CurseOfDeath.new())
	skillList.append(HeroAbility.create("soul_reap"))
	passiveSkill = DotMaster.new(self)
