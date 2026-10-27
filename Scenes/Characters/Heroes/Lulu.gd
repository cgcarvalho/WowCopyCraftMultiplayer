class_name Lulu
extends Character

var image_path = "res://Art/Chars/Lulu - Hunter/Lulu Stand.png"
var scene_path = "res://Scenes/Characters/Heroes/Lulu.tscn"

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Lulu"
	charClass = "Hunter"
	charTotalLife = 100
	charCurrentLife = 100
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 3.0
	portraitImagePath = image_path
	scenePath = scene_path
	charBaseDamage = 8
	charRange = 700
	attack_interval = 1.15
	attack_style = "arrow"
	if skillList.is_empty():
		addSkillsChar()
	base_life = charTotalLife
	configure_resource()

func addSkillsChar() -> void:
	skillList.append(HeroAbility.create("aimed_shot"))
	skillList.append(HeroAbility.create("poison_arrow"))
	skillList.append(HeroAbility.create("multishot"))
	skillList.append(HeroAbility.create("arrow_rain"))
