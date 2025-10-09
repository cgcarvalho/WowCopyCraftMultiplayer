extends Skill

class_name DirectDamege

var targetCharacter : Area2D
var casterGP
var count = 0

func cast(casterPosition : Vector2, targetChar : Area2D) -> void:
	targetCharacter = targetChar
	global_position = casterPosition
	z_index = 5
	get_node("AnimatedSprite2D").play()

	
	

func _physics_process(delta: float) -> void:
	global_position = global_position.move_toward(targetCharacter.global_position, delta * projectileSpeed)
			
	if global_position.is_equal_approx(targetCharacter.global_position):
		queue_free()

	
