class_name Skill
extends Area2D

@onready var animatedSprite = get_node("AnimatedSprite2D")

var skillScenePath : String
var projectileSpeed : int
var targetCharacter : Character
var casterPosition : Vector2

#Basic Stats
var skillName : String

func _enter_tree() -> void:
	z_index = 5

func physics_process(delta: float) -> void:
	pass

func cast(casterGP : Vector2, targetChar : Character) -> void:
	pass

func setSkillInicialPosition() -> void:
	pass
