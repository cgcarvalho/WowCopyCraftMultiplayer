extends Skill

class_name DamageOverTime

signal onDamage

var skillBaseDamage : int
var skillDotSeconds : int
var timer = 0.0
var skillTimer = 0.0

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	animatedSprite.play()
	
func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.y -= 170
		

func _physics_process(delta: float) -> void:
	setSkillInicialPosition()
	timer += delta
	skillTimer += delta

	if timer >= 1.0 and skillTimer <= skillDotSeconds + 1:
		targetCharacter.deal_damage(skillBaseDamage)
		timer = 0.0 
		onDamage.emit()
	elif skillTimer >= skillDotSeconds:
		queue_free()
		
