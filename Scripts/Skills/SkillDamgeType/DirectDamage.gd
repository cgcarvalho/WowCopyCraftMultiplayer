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
	if not is_instance_valid(targetCharacter) or (casterCharacter != null and not is_instance_valid(casterCharacter)):
		queue_free()
		return
	global_position = global_position.move_toward(targetCharacter.global_position, delta * projectileSpeed)

































	animatedSprite.flip_h = global_position.x > targetCharacter.global_position.x
			
	if global_position.is_equal_approx(targetCharacter.global_position):
		queue_free()
		var multiplier = TalentTree.skill_damage(casterCharacter.talents, self) if is_instance_valid(casterCharacter) else 1.0
		targetCharacter.deal_damage(skillBaseDamage, casterCharacter, false, multiplier)
