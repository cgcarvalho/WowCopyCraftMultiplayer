class_name Skill
extends Area2D

@onready var animatedSprite = get_node("AnimatedSprite2D")

var skillScenePath : String
var projectileSpeed : int
var targetCharacter : Character
var casterCharacter : Character

var resetCoolDown : bool = false
var resetCastTime : bool = false

#Basic Stats
var skillName : String
var skillCoolDownTime : float
var skillManaCost : int = 0
var skillCastTime : float = 0
enum TargetMode { LEGACY, ENEMY, ALLY, SELF, GROUND }
var target_mode: TargetMode = TargetMode.LEGACY
var cast_range: float = 800.0
var is_ultimate = false
var description = ""

func targeting() -> TargetMode:
	if target_mode != TargetMode.LEGACY:
		return target_mode
	if self is Heal or self is Shield or self is Buff:
		return TargetMode.ALLY
	if self is AreaDamage:
		return TargetMode.GROUND
	return TargetMode.ENEMY

func _enter_tree() -> void:
	z_index = Constants.SKILL_Z_INDEX

func physics_process(_delta: float) -> void:
	pass

func cast(_casterChar : Character, _targetChar : Character) -> void:
	pass
	
func setSkillInicialPosition() -> void:
	pass

func target_description() -> String:
	match targeting():
		TargetMode.ALLY:
			return "Aliado ou você · Alt: autocura"
		TargetMode.SELF:
			return "Você / área ao seu redor"
		TargetMode.GROUND:
			return "Chão sob o alvo; sem alvo, sua posição"
	return "Inimigo"

func cast_description() -> String:
	return "Instantânea" if skillCastTime <= 0 else "%.1f s" % skillCastTime

func tooltip_summary(hotkey: String) -> String:
	var heading = skillName + (" · ULTIMATE" if is_ultimate else "")
	var reach = "Você" if targeting() == TargetMode.SELF else "%d" % int(cast_range)
	return "%s [%s]\n%s\n\nMana: %d · Recarga: %.1f s\nConjuração: %s · Alcance: %s\nAlvo: %s" % [heading, hotkey, description, skillManaCost, skillCoolDownTime, cast_description(), reach, target_description()]
