extends Skill

class_name DamageOverTime

signal onDamage

var skillBaseDamage : int
var skillDotSeconds : int
var timer = 0.0
var skillTimer = 0.0
var lb : Label

func cast(casterChar : Character, targerChar : Character) -> void:
	casterCharacter = casterChar
	targetCharacter = targerChar
	animatedSprite.play()

	targetCharacter.debuffList.append(self)
	
	lb = Label.new()
	var label_settings = LabelSettings.new()
	label_settings.font_size = 60
	lb.label_settings = label_settings

	add_child(lb)
	
func setSkillInicialPosition() -> void:
	global_position = targetCharacter.global_position
	
	if self is CurseOfDeath:
		global_position.x += 10
		#lb.global_position.x -= 60
		global_position.y -= 210
	elif self is Corruption:
		global_position.x += 60
		global_position.y -= 180
		
		

func _physics_process(delta: float) -> void:
	setSkillInicialPosition()
	timer += delta
	skillTimer += delta
	lb.text = str("%2.2f" % skillTimer )

	if timer >= 1.0 and skillTimer <= skillDotSeconds + 1:
		targetCharacter.deal_damage(skillBaseDamage)
		timer = 0.0 
		onDamage.emit()
	elif skillTimer >= skillDotSeconds:
		queue_free()
		targetCharacter.debuffList.erase(self)
		
func renewDot() -> void:
	skillTimer = 0.0		
