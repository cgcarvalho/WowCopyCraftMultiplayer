extends Skill

class_name AreaDamage

var skillBaseDamage : int
var skillDuration : int
var timer = 0.0
var skillTimer = 0.0
var playersInArea : Array[Character]

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	setSkillInicialPosition()
	animatedSprite.play()
	
func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	#global_position.y -= 170
		

func _physics_process(delta: float) -> void:
	
	timer += delta
	skillTimer += delta
	
	if timer >= 1.0 and skillTimer <= skillDuration + 1:
		for player in playersInArea:
			player.deal_damage(skillBaseDamage)
		timer = 0.0 
	elif skillTimer >= skillDuration:
		queue_free()

func _area_entered(body : Area2D) -> void:
	if body.has_method("deal_damage"):
		playersInArea.append(body)
		
func _area_exited(body : Area2D) -> void:
	if body.has_method("deal_damage"):
		playersInArea.erase(body)	
