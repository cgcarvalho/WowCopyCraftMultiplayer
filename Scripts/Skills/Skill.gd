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
var aim_position = Vector2.INF
var cost_label = "Mana"
var cooldown_scale = 1.0
var talent_description = ""

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
			return "Chão escolhido com o mouse · Esc cancela"
	return "Inimigo"

func cast_description() -> String:
	if resetCastTime:
		return "Instantânea · Dot Master"
	return "Instantânea" if skillCastTime <= 0 else "%.1f s" % skillCastTime

func tooltip_summary(hotkey: String) -> String:
	var heading = skillName + (" · ULTIMATE" if is_ultimate else "")
	var reach = "Você" if targeting() == TargetMode.SELF else "%d" % int(cast_range)
	return "%s [%s]\n%s%s\n\n%s: %d · Recarga: %.1f s\nConjuração: %s · Alcance: %s\nAlvo: %s" % [heading, hotkey, description, talent_description, cost_label, skillManaCost, skillCoolDownTime * cooldown_scale, cast_description(), reach, target_description()]
