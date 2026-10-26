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
