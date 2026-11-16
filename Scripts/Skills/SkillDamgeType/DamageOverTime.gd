extends Skill

class_name DamageOverTime

signal onDamage

var skillBaseDamage : int
var skillDotSeconds : int
var timer = 0.0
var skillTimer = 0.0
var sprite_scale := Vector2.ONE

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	animatedSprite.play()
	sprite_scale = animatedSprite.scale

	targetCharacter.debuffList.append(self)
	
	# Gameplay effects keep their world-space art; labels are rendered in screen space.
	animatedSprite.modulate.a = 0.55
	setSkillInicialPosition()
	CombatFeedback.show_skill_effect(cue_name(), global_position, casterCharacter, 85)

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
	var fade_in = clampf(skillTimer / 0.22, 0, 1)
	var fade_out = clampf((skillDotSeconds - skillTimer + 0.25) / 0.52, 0, 1)
	animatedSprite.modulate.a = (0.42 + 0.29 * pow(maxf(0, 1 - timer), 5)) * fade_in * fade_out
	animatedSprite.scale = sprite_scale * lerpf(0.65, 1.0, fade_in * fade_out)

	if timer >= 1.0 and skillTimer <= skillDotSeconds + 1:
		targetCharacter.deal_damage(skillBaseDamage, casterCharacter, true)
		timer = 0.0 
		onDamage.emit()
	elif skillTimer >= skillDotSeconds:
		queue_free()
		targetCharacter.debuffList.erase(self)
		
func renewDot() -> void:
	skillTimer = 0.0
	CombatFeedback.show_skill_effect(cue_name(), global_position, casterCharacter, 68)

func cue_name() -> StringName:
	return &"curse" if skillName == "Curse of Death" else &"corruption"


func _exit_tree() -> void:
	if is_instance_valid(targetCharacter):
		targetCharacter.debuffList.erase(self)
