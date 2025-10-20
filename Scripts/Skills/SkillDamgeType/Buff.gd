extends Skill

class_name Buff

var buffDuration : float

func cast(casterChar : Character, targerChar : Character) -> void:
	global_position = casterChar.global_position
	targetCharacter = targerChar
	
	casterChar.ui_handler.createBuffs(self)
	#animatedSprite.play()
	#setSkillInicialPosition()


func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.y += 50 
	

func _physics_process(_delta: float) -> void:
	pass
