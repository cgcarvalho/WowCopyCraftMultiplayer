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
			
	if global_position.is_equal_approx(targetCharacter.global_position):
		queue_free()
		deal_damage()

func deal_damage() -> void:
	targetCharacter.charCurrentLife -= skillBaseDamage
	
	var damageLocation = targetCharacter.global_position
	damageLocation.y += - 150
	DamageNumbers.display_number(skillBaseDamage, damageLocation, false)
