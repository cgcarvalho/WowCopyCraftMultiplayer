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

	targetCharacter.debuffList.append(self)
	
	# Gameplay effects keep their world-space art; labels are rendered in screen space.
	animatedSprite.modulate.a = 0.55
	setSkillInicialPosition()

func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	var index = targetCharacter.debuffList.find(self)
	global_position.x += (index - (targetCharacter.debuffList.size() - 1) / 2.0) * 32
	global_position.y += 12

func _physics_process(delta: float) -> void:
	if not is_instance_valid(targetCharacter) or (casterCharacter != null and not is_instance_valid(casterCharacter)):
		queue_free()
		return
	setSkillInicialPosition()
	timer += delta
	skillTimer += delta

	if timer >= 1.0 and skillTimer <= skillDotSeconds + 1:
		targetCharacter.deal_damage(skillBaseDamage, casterCharacter, true)
		timer = 0.0 
		onDamage.emit()
	elif skillTimer >= skillDotSeconds:
		queue_free()
		targetCharacter.debuffList.erase(self)
		
func renewDot() -> void:
	skillTimer = 0.0		


func _exit_tree() -> void:
	if is_instance_valid(targetCharacter):
		targetCharacter.debuffList.erase(self)
