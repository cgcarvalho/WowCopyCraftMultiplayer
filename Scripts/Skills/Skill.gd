class_name Skill
extends Area2D

@onready var animatedSprite = get_node("AnimatedSprite2D")

var skillScenePath : String
var projectileSpeed : int
var targetCharacter : Character
var casterCharacter : Character

var resetCoolDown : bool = false

#Basic Stats
var skillName : String
var skillCoolDownTime : float
var skillManaCost : int = 0

func _enter_tree() -> void:
	z_index = Constants.SKILL_Z_INDEX

func physics_process(_delta: float) -> void:
	pass

func cast(_casterChar : Character, _targetChar : Character) -> void:
	pass
	
func setSkillInicialPosition() -> void:
	pass
