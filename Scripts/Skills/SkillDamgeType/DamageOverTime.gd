extends Skill

class_name DamageOverTime

var skillBaseDamage : float
var skillDotSeconds : int
var timer = 0.0
var skillTimer = 0.0

func cast(casterGP : Vector2, targetChar : Character) -> void:
	targetCharacter = targetChar
	casterPosition = casterGP
	animatedSprite.play()
	setSkillInicialPosition()
	
func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.y = targetCharacter.global_position.y - 170
		

func _physics_process(delta: float) -> void:
	timer += delta
	skillTimer += delta
	
	if timer >= 1.0 and skillTimer <= skillDotSeconds + 1:
		deal_damage()
		timer = 0.0 
	elif skillTimer >= skillDotSeconds:
		queue_free()
		

func deal_damage() -> void:
	targetCharacter.charCurrentLife -= skillBaseDamage
	
	var damageLocation = targetCharacter.global_position
	damageLocation.y += - 150
	DamageNumbers.display_number(skillBaseDamage, damageLocation, false)
