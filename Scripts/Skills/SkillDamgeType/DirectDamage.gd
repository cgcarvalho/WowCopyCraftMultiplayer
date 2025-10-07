extends Skill

class_name DirectDamege




func enter() -> void:
	skill_handler.animatedSprite.play()
	global_position = skill_handler.playerCaster.global_position


func physics_process(delta: float) -> void:
	if skill_handler and skill_handler.playerCaster.charCurrentTarget:
		var targetGP = skill_handler.playerCaster.charCurrentTarget.global_position
		global_position = global_position.move_toward(targetGP, delta * projectileSpeed)
		
		if global_position.is_equal_approx(targetGP):
			exit()
	
	
func exit() -> void:
	queue_free()
