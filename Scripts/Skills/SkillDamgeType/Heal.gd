extends Skill

class_name Heal

var skillBaseHeal : float

func cast(casterPosition : Vector2, targetChar : Character) -> void:
	targetCharacter = targetChar
	global_position = casterPosition
	animatedSprite.play()
	setSkillInicialPosition()


func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.y = targetCharacter.global_position.y + 50 
	

func _physics_process(delta: float) -> void:
	if not animatedSprite.is_playing():
		queue_free()
		deal_heal()

func deal_heal() -> void:
	targetCharacter.charCurrentLife += skillBaseHeal
