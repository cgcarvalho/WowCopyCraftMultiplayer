class_name SirGura
extends Character

var image_path = "res://Art/Chars/Sir Gura Targao/stand.png"
var scene_path = "res://Scenes/Characters/Heroes/SirGura.tscn"

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Sir Gura"
	charClass = "Warrior"
	charTotalLife = 150
	charCurrentLife = 150
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 3.0
	portraitImagePath = image_path
	scenePath = scene_path
	charBaseDamage = 10
	charRange = 100
	attack_interval = 0.9
	attack_style = "melee"
	if skillList.is_empty():
		addSkillsChar()
	base_life = charTotalLife
	configure_resource()

func addSkillsChar() -> void:
	skillList.append(HeroAbility.create("charge"))
	skillList.append(HeroAbility.create("cleave"))
	skillList.append(HeroAbility.create("second_wind"))
	skillList.append(HeroAbility.create("bladestorm"))
