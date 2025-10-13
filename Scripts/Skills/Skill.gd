class_name Skill
extends Area2D

@onready var animatedSprite = get_node("AnimatedSprite2D")

var skillScenePath : String
var projectileSpeed : int
var targetCharacter : Character
var casterCharacter : Character

#Basic Stats
var skillName : String

func _enter_tree() -> void:
	z_index = 2

func physics_process(delta: float) -> void:
	pass

func cast(casterChar : Character, targetChar : Character) -> void:
	pass

func setSkillInicialPosition() -> void:
	pass
