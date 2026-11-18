extends Skill

class_name DirectDamage

var skillBaseDamage : int
var flight_time = 0.0
var source_offset := Vector2.ZERO

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	animatedSprite.play()
	setSkillInicialPosition()
	if skillName == "Shadow Bolt":
		source_offset = casterChar.weapon_offset("bolt", global_position.direction_to(targerChar.global_position))
		animatedSprite.position = to_local(global_position + source_offset)
	
func setSkillInicialPosition() -> void:
	global_position = casterCharacter.global_position
		

func _physics_process(delta: float) -> void:
	if not is_instance_valid(targetCharacter) or (casterCharacter != null and not is_instance_valid(casterCharacter)):
		queue_free()
		return
	global_position = global_position.move_toward(targetCharacter.global_position, delta * projectileSpeed)
	flight_time += delta
	if skillName == "Shadow Bolt":
		animatedSprite.position = to_local(global_position + source_offset * maxf(0, 1 - flight_time / 0.20))

































	animatedSprite.flip_h = global_position.x > targetCharacter.global_position.x
			
	if global_position.is_equal_approx(targetCharacter.global_position):
		if skillName == "Shadow Bolt" and is_instance_valid(casterCharacter):
			CombatFeedback.show_skill_effect(&"bolt", targetCharacter.global_position, casterCharacter, 86)
		queue_free()
		var multiplier = TalentTree.skill_damage(casterCharacter.talents, self) if is_instance_valid(casterCharacter) else 1.0
		var before = targetCharacter.charCurrentLife + targetCharacter.charShield
		targetCharacter.deal_damage(skillBaseDamage, casterCharacter, false, multiplier)
		if skillName == "Shadow Bolt" and is_instance_valid(casterCharacter):
			MasteryEffects.shadow_echo(casterCharacter, targetCharacter, roundi(skillBaseDamage * multiplier), before - targetCharacter.charCurrentLife - targetCharacter.charShield)
