class_name Charger
extends Character

var image_path = "res://Art/Chars/Charger/Charger.png"
var scene_path = "res://Scenes/Characters/Heroes/Charger.tscn"
const AUTO_ATTACK_SCALE = 1.2

func _ready() -> void:
	super._ready()
	$AnimatedSprite2D.animation_changed.connect(update_animation_scale)
	update_animation_scale()

func update_animation_scale() -> void:
	# Attack atlas margins keep the boots at the same origin as idle/cast.
	$AnimatedSprite2D.scale = Vector2.ONE * (AUTO_ATTACK_SCALE if $AnimatedSprite2D.animation == &"auto_attack" else 1.0)

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Charger"
	charClass = "Paladin"
	charTotalLife = 130
	charCurrentLife = 130
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 3.0
	portraitImagePath = image_path
	scenePath = scene_path
	charBaseDamage = 8
	charRange = 105
	attack_interval = 1.1
	attack_style = "melee"
	if skillList.is_empty():
		addSkillsChar()
	base_life = charTotalLife
	configure_resource()

func addSkillsChar() -> void:
	skillList.append(HeroAbility.create("holy_light"))
	skillList.append(HeroAbility.create("judgement"))
	skillList.append(HeroAbility.create("consecration"))
	skillList.append(HeroAbility.create("divine_dawn"))
