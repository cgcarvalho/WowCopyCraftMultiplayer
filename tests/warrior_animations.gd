extends Node

var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.get_node("MultiplayerHUD").hide()
	var encounter = main.get_node("BossEncounter")
	encounter.status = "active"
	encounter.set_physics_process(false)
	var boss: Character = encounter.boss
	boss.set_physics_process(false)
	boss.charTotalLife = 10000
	boss.charCurrentLife = 10000
	boss.position = Vector2(480, 300)
	var hero: SirGura = load("res://Scenes/Characters/Heroes/SirGura.tscn").instantiate()
	hero.name = "1"
	MultiplayerManager.playerList[1] = hero
	main.get_node("Players").add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector2(400, 300)
	hero.charCurrentMana = 100
	hero.charCritChance = 0
	hero.charCurrentTarget = boss
	var handler = main.get_node("SkillHandler")
	var body: AnimatedSprite2D = hero.get_node("AnimatedSprite2D")
	var frames = body.sprite_frames
	for animation in [&"auto_attack", &"cleave", &"bladestorm"]:
		check(frames.has_animation(animation) and frames.get_frame_count(animation) >= 8, "Warrior has a complete " + String(animation) + " animation")
		var texture = hero.attack_sprite.sprite_frames.get_frame_texture(animation, 0)
		check(texture != null and "Ludo" in texture.resource_path, String(animation) + " uses a dedicated Ludo effect sprite")
		check(texture.get_image().get_pixel(0, 0).a == 0, String(animation) + " keeps a transparent canvas")
	check(frames.get_frame_texture("auto_attack", 4).region == Rect2(640, 2080, 640, 416), "Attack release at 35 percent now coincides with the existing sword's contact pose")
	check(is_equal_approx(frames.get_frame_count("auto_attack") / frames.get_animation_speed("auto_attack"), hero.attack_interval), "Basic slash duration matches the existing 0.9-second attack interval")
	check(not frames.get_animation_loop("cleave") and frames.get_animation_loop("bladestorm"), "Cleave is a single swing and Bladestorm loops")
	check(not hero.attack_sprite.visible and body.visible, "Special attack layer starts hidden")
	handler.loadSkillScene("res://Scenes/Skills/Classes/cleave.tscn", 1, -1)
	var cleave = hero.attack_effect
	cleave.set_physics_process(false)
	check(is_instance_valid(cleave) and hero.attack_sprite.visible and not body.visible and hero.attack_sprite.animation == &"cleave", "Server-accepted Cleave shows its wide swing without drawing the idle body twice")
	check(boss.charCurrentLife == 9976 and hero.charCurrentMana == 75, "Cleave keeps its existing damage and rage cost")
	hero.attack_sprite.set_frame_and_progress(0, 0.25)
	body.flip_h = true
	hero.flash_time = 0.2
	hero.flash_color = Color.RED
	hero.update_presentation(0)
	check(hero.attack_sprite.frame == 0 and is_equal_approx(hero.attack_sprite.frame_progress, 0.25), "Presentation updates do not restart a skill animation every frame")
	check(hero.attack_sprite.flip_h and hero.attack_body.modulate == Color.RED, "Special swing follows facing and the character retains damage feedback")
	cleave.free()
	hero.update_presentation(0)
	check(body.visible and not hero.attack_sprite.visible, "Finishing Cleave restores the normal character presentation")
	hero.charCurrentMana = 100
	handler.loadSkillScene("res://Scenes/Skills/Classes/bladestorm.tscn", 1, 1)
	var storm = hero.attack_effect
	storm.set_physics_process(false)
	check(hero.attack_sprite.visible and hero.attack_sprite.animation == &"bladestorm", "Server-accepted Bladestorm starts the spinning animation")
	hero.ability_animation_time = 0
	Input.action_press("move_right")
	hero._physics_process(0.02)
	var origin = hero.position
	hero._physics_process(0.05)
	hero.update_presentation(0)
	Input.action_release("move_right")
	check(hero.position.x > origin.x and hero.attack_sprite.animation == &"bladestorm" and hero.attack_sprite.visible, "Bladestorm stays visible while normal movement continues")
	handler.cooldowns.clear()
	hero.charCurrentMana = 100
	handler.loadSkillScene("res://Scenes/Skills/Classes/cleave.tscn", 1, -1)
	check(hero.attack_effect == storm and hero.attack_sprite.animation == &"bladestorm", "A regular ability does not replace an active ultimate's spin")
	var before = boss.charCurrentLife
	for tick in 5:
		storm._physics_process(1.0)
	hero.update_presentation(0)
	check(hero.attack_sprite.visible and boss.charCurrentLife == before - 60, "Spin follows the actual effect through its first five damage ticks")
	storm._physics_process(1.0)
	hero.update_presentation(0)
	check(not hero.attack_sprite.visible and body.visible and boss.charCurrentLife == before - 72, "Final tick ends the spin without changing ultimate damage")
	await get_tree().process_frame
	handler.cooldowns.clear()
	hero.charCurrentMana = 100
	handler.loadSkillScene("res://Scenes/Skills/Classes/bladestorm.tscn", 1, 1)
	hero.charCurrentLife = 0
	hero.update_presentation(0)
	check(not hero.attack_sprite.visible and body.visible, "Death clears the spin and preserves the normal death presentation")
	hero.charCurrentLife = hero.charTotalLife
	handler.cooldowns.clear()
	hero.charCurrentMana = 100
	handler.loadSkillScene("res://Scenes/Skills/Classes/bladestorm.tscn", 1, 1)
	hero.reset_for_round(Vector2(400, 300), {})
	hero.set_physics_process(false)
	check(hero.attack_effect == null and not hero.attack_sprite.visible and body.visible and body.animation == &"idle", "Round reset clears the special animation immediately")
	hero.charCurrentTarget = boss
	handler.basic_attack(1, -1)
	check(hero.attack_sprite.visible and hero.attack_sprite.animation == &"auto_attack" and body.frame == 4, "An accepted basic hit aligns the sword pose and starts its Ludo slash")
	check(body.offset == Vector2(-7, -4), "Attack canvas compensates for the original feet and horizontal offset")
	hero.attack_sprite.set_frame_and_progress(0, 0.5)
	handler.basic_attack(1, -1)
	check(is_equal_approx(hero.attack_sprite.frame_progress, 0.5), "Server-rejected duplicate attacks do not restart the visual effect")
	hero.update_presentation(0.3)
	check(not hero.attack_sprite.visible and body.visible, "Basic slash fades away without hiding the character")
	for child in main.get_children():
		if child is CombatProjectile:
			child.set_physics_process(false)
			child._physics_process(1.0)
			child.free()
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("Warrior animation failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
