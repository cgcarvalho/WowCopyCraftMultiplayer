extends Skill

class_name Heal

var skillBaseHeal : float

func cast(casterChar : Character, targerChar : Character) -> void:
	global_position = casterChar.global_position
	targetCharacter = targerChar
	
	animatedSprite.play()
	setSkillInicialPosition()


func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.y = targetCharacter.global_position.y + 50 
	

func _physics_process(delta: float) -> void:
	if not animatedSprite.is_playing():
		queue_free()
		deal_heal()

func deal_heal() -> void:
	targetCharacter.charCurrentLife += skillBaseHeal
	
	var healLocation = targetCharacter.global_position
	healLocation.y += - 150
	DamageNumbers.display_number(skillBaseHeal, healLocation, false, true)
