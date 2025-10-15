extends Skill

class_name Heal

var skillBaseHeal : int

func cast(casterChar : Character, targerChar : Character) -> void:
	global_position = casterChar.global_position
	targetCharacter = targerChar
	
	animatedSprite.play()
	setSkillInicialPosition()


func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.y = targetCharacter.global_position.y + 50 
	

func _physics_process(_delta: float) -> void:
	if not animatedSprite.is_playing():
		queue_free()
		targetCharacter.apply_heal(skillBaseHeal)
