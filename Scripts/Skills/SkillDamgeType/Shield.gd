extends Skill

class_name Shield

var skillBaseShield : int
var shieldTime : int 
@onready var timer: Timer = $Timer

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	global_position = casterChar.global_position
	targetCharacter = targerChar
	targetCharacter.apply_shield(skillBaseShield, casterChar)
	
	animatedSprite.play()
	timer.start()


func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	global_position.x -= 30
	

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(targetCharacter) or (casterCharacter != null and not is_instance_valid(casterCharacter)):
		queue_free()
		return
	setSkillInicialPosition()
	
	if multiplayer.is_server() and targetCharacter.charShield <= 0:
		endShield()
	

func endShield() -> void:
	queue_free()

