extends Skill

class_name DeslocateAttack

var skillBaseDamage : int
var deslocateSpeed : int

var playersInArea : Array[Character]


func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	animatedSprite.play()
	
	
func setSkillInicialPosition() -> void:
	global_position = casterCharacter.global_position
		
		

func _physics_process(delta: float) -> void:
	setSkillInicialPosition()
	
	casterCharacter.global_position = casterCharacter.global_position.move_toward(targetCharacter.global_position, delta * deslocateSpeed)
			
	if casterCharacter.global_position.is_equal_approx(targetCharacter.global_position):
		targetCharacter.deal_damage(skillBaseDamage)
		queue_free()


func _area_entered(body : Area2D) -> void:
	if body.has_method("deal_damage"):
		playersInArea.append(body)
		
func _area_exited(body : Area2D) -> void:
	if body.has_method("deal_damage"):
		playersInArea.erase(body)	
