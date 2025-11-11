extends Skill

class_name DirectDamage

var skillBaseDamage : int

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	animatedSprite.play()
	setSkillInicialPosition()
	
func setSkillInicialPosition() -> void:
	global_position = casterCharacter.global_position
		

func _physics_process(delta: float) -> void:
	global_position = global_position.move_toward(targetCharacter.global_position, delta * projectileSpeed)

































	animatedSprite.flip_h = global_position.x > targetCharacter.global_position.x
			
	if global_position.is_equal_approx(targetCharacter.global_position):
		queue_free()
		targetCharacter.deal_damage(skillBaseDamage)
