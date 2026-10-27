class_name SirGura
extends Character

var image_path = "res://Art/Chars/Sir Gura Targao/stand.png"
var scene_path = "res://Scenes/Characters/Heroes/SirGura.tscn"
var attack_sprite: AnimatedSprite2D
var attack_body: AnimatedSprite2D
var attack_effect: HeroAbility
var basic_flash_remaining = 0.0

func _ready() -> void:
	super._ready()
	# Separate presentation lets the sword spin continue during movement.
	# Only accepted attacks produce effects; gameplay stays server-controlled.
	attack_body = AnimatedSprite2D.new()
	attack_body.name = "WarriorAttackBody"
	attack_body.sprite_frames = $AnimatedSprite2D.sprite_frames
	attack_body.visible = false
	add_child(attack_body)
	attack_sprite = AnimatedSprite2D.new()
	attack_sprite.name = "WarriorAttackSprite"
	attack_sprite.sprite_frames = load("res://Art/Chars/Sir Gura Targao/Ludo Sword Effects.tres")
	attack_sprite.visible = false
	add_child(attack_sprite)
	$AnimatedSprite2D.animation_changed.connect(update_body_anchor)
	update_body_anchor()

func update_body_anchor() -> void:
	# Existing sword frames have a shorter canvas than idle and a slight shift.
	$AnimatedSprite2D.offset = Vector2(-7, -4) if $AnimatedSprite2D.animation == &"auto_attack" else Vector2.ZERO

func play_basic_attack_animation(target: Character) -> void:
	if is_instance_valid(attack_effect) and not attack_effect.is_queued_for_deletion():
		return
	var body: AnimatedSprite2D = $AnimatedSprite2D
	body.flip_h = global_position.x < target.global_position.x
	body.play("auto_attack")
	body.set_frame_and_progress(4, 0)
	basic_flash_remaining = 0.24
	attack_sprite.play("auto_attack")
	attack_sprite.set_frame_and_progress(0, 0)
	update_attack_presentation()

func play_skill_animation(skill: Skill) -> void:
	if not skill is HeroAbility or skill.ability_id not in ["cleave", "bladestorm"]:
		return
	if not attack_sprite.sprite_frames.has_animation(StringName(skill.ability_id)):
		return
	if is_instance_valid(attack_effect) and not attack_effect.is_queued_for_deletion() and attack_effect.ability_id == "bladestorm":
		return
	attack_effect = skill
	basic_flash_remaining = 0
	attack_body.play(StringName(skill.ability_id))
	attack_body.set_frame_and_progress(0, 0)
	attack_sprite.play(StringName(skill.ability_id))
	attack_sprite.set_frame_and_progress(0, 0)
	update_attack_presentation()

func update_presentation(delta: float) -> void:
	super.update_presentation(delta)
	basic_flash_remaining = maxf(0, basic_flash_remaining - delta)
	update_attack_presentation()

func update_attack_presentation() -> void:
	if not is_instance_valid(attack_sprite):
		return
	var special = is_instance_valid(attack_effect) and not attack_effect.is_queued_for_deletion() and attack_effect.living() and not spectator
	var body: AnimatedSprite2D = $AnimatedSprite2D
	body.visible = not special
	attack_body.visible = special
	attack_sprite.visible = (special or basic_flash_remaining > 0) and charCurrentLife > 0 and not spectator and not get_parent().get_parent().get_node("SkillHandler").encounter_finished()
	attack_sprite.flip_h = body.flip_h
	attack_sprite.position = Vector2(120 if body.flip_h else -120, 20)
	attack_sprite.scale = Vector2.ONE * (0.95 if special else 0.7)
	attack_sprite.rotation = 0
	attack_sprite.modulate = Color.WHITE
	if special:
		attack_body.position = body.position
		attack_body.offset = Vector2(-7, -4)
		attack_body.scale = body.scale
		attack_body.flip_h = body.flip_h
		attack_body.modulate = body.modulate
		if attack_effect.ability_id == "bladestorm":
			var turn = cos(attack_effect.elapsed * TAU * 1.5)
			attack_body.scale.x *= maxf(0.4, absf(turn))
			attack_body.position.x += 37 * (1 - attack_body.scale.x)
			attack_body.flip_h = body.flip_h if turn >= 0 else not body.flip_h
			attack_sprite.position = Vector2(0, 30)
			attack_sprite.scale = Vector2.ONE * 1.1
			attack_sprite.rotation = attack_effect.elapsed * TAU * 1.5
			attack_sprite.modulate.a = 0.75
		else:
			var progress = clampf(attack_effect.elapsed / attack_effect.visual_duration, 0, 1)
			attack_sprite.scale *= lerpf(0.65, 1.15, sin(progress * PI))
			attack_sprite.rotation = lerpf(-0.8, 0.4, progress) * (-1 if body.flip_h else 1)
			attack_sprite.modulate.a = minf(1, (1 - progress) * 3)
	else:
		attack_body.stop()
		attack_effect = null
		if basic_flash_remaining <= 0:
			attack_sprite.stop()
		else:
			var progress = 1 - basic_flash_remaining / 0.24
			attack_sprite.scale *= lerpf(0.65, 1, sin(progress * PI))
			attack_sprite.rotation = lerpf(-0.8, 0.45, progress) * (-1 if body.flip_h else 1)
			attack_sprite.modulate.a = minf(1, basic_flash_remaining / 0.12)

func reset_for_round(point: Vector2, choices: Dictionary, selected_talents: Dictionary = {}) -> void:
	super.reset_for_round(point, choices, selected_talents)
	attack_effect = null
	basic_flash_remaining = 0
	update_attack_presentation()

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Sir Gura"
	charClass = "Warrior"
	charTotalLife = 150
	charCurrentLife = 150
	charTotalMana = 100
	charCurrentMana = 100
	manaRegen = 3.0
	portraitImagePath = image_path
	scenePath = scene_path
	charBaseDamage = 10
	charRange = 160
	attack_interval = 0.9
	attack_style = "melee"
	if skillList.is_empty():
		addSkillsChar()
	base_life = charTotalLife
	configure_resource()

func addSkillsChar() -> void:
	skillList.append(HeroAbility.create("charge"))
	skillList.append(HeroAbility.create("cleave"))
	skillList.append(HeroAbility.create("second_wind"))
	skillList.append(HeroAbility.create("bladestorm"))
