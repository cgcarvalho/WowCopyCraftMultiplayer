extends Node

var failures = 0

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var encounter = main.get_node("BossEncounter")
	var boss = encounter.boss
	var visuals = encounter.get_node("SpellVisual")
	encounter.set_physics_process(false)
	boss.set_physics_process(false)
	visuals.set_process(false)
	main.request_player("res://Scenes/Characters/Heroes/SirGura.tscn")
	var hero = MultiplayerManager.playerList[1]
	hero.set_physics_process(false)
	encounter.status = "active"
	encounter.opening_delay = 0
	boss.position = Vector2(700, 300)
	hero.position = Vector2(350, 300)
	for clip in ["charge", "eruption", "orb", "lance", "sigil"]:
		var count: int = visuals.frames.get_frame_count(clip)
		check(count >= 12, clip + " has a smooth multi-frame sequence")
		check(visuals.frame_index(clip, -1) == 0 and visuals.frame_index(clip, 2) == count - 1, clip + " clamps one-shot playback instead of wrapping")
		var image: Image = visuals.texture_for(clip, 0.5).get_image()
		check(image.get_pixel(0, 0).a == 0 and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0, clip + " keeps transparent outer corners")
	for kind in encounter.WARNINGS:
		encounter.danger_visible = false
		encounter.begin_spell(kind)
		encounter.danger_remaining = encounter.WARNINGS[kind] * 0.5
		check(is_equal_approx(visuals.warning_progress(), 0.5), kind + " preparation follows replicated cast progress")
	encounter.visual_kind = "rupture"
	encounter.visual_remaining = encounter.IMPACT_SECONDS * 0.25
	check(is_equal_approx(visuals.impact_progress(), 0.75), "Impact catches up to the server timeline")
	encounter.danger_visible = false
	encounter.begin_spell("spread")
	var center: Vector2 = hero.global_position
	encounter.resolve_area()
	hero.position += Vector2(200, 0)
	check(encounter.visual_targets == [center], "Spread aftermath stays at the actual damage position")
	encounter.begin_spell("channel")
	center = hero.global_position
	encounter.resolve_area()
	hero.position += Vector2(0, 100)
	check(encounter.visual_targets == [center], "Cataclysm records its impact positions")
	hero.charCurrentLife = 100
	hero.position = boss.position + Vector2(-100, 0)
	encounter.begin_spell("channel")
	encounter.interrupt_channel(hero)
	check(encounter.visual_kind == "interrupted" and encounter.visual_targets.is_empty() and not encounter.danger_visible, "Interrupt replaces the explosion with a harmless fizzle")
	check(hero.charCurrentLife == 100 and is_zero_approx(visuals.impact_progress()), "Fizzle starts at frame zero without damage")
	encounter.danger_visible = false
	encounter.begin_spell("lance")
	encounter.danger_remaining = encounter.WARNINGS.lance * 0.5
	boss.facing_left = true
	boss._process(0)
	var sprite: AnimatedSprite2D = boss.get_node("AnimatedSprite2D")
	var follows_staff = true
	for index in sprite.sprite_frames.get_frame_count("idle"):
		sprite.frame = index
		var image: Image = sprite.sprite_frames.get_frame_texture("idle", index).get_image()
		var anchor: Vector2 = sprite.to_local(visuals.staff_point())
		anchor.x = -anchor.x # Undo the presentation flip to sample the original art.
		var pixel = image.get_pixelv(Vector2i(anchor + Vector2(image.get_size()) / 2))
		follows_staff = follows_staff and pixel.r > 0.5 and pixel.b > 0.5 and pixel.a > 0.5
	check(follows_staff, "Charge follows the actual gem in every flipped and scaled body frame")
	encounter.danger_visible = false
	boss._process(0)
	check(sprite.speed_scale == 1 and is_zero_approx(sprite.rotation), "Casting lean and speed return to normal")
	encounter.projectiles = [{"id": 44, "position": Vector2(500, 300), "velocity": Vector2.RIGHT * 260, "life": 3.0}]
	visuals._process(0.01)
	encounter.projectiles = []
	visuals._process(0.01)
	check(visuals.fading_orbs.size() == 1, "Removed orb creates one short dissipating effect")
	visuals._process(0.2)
	check(visuals.fading_orbs.is_empty(), "Orb aftermath expires without lingering")
	encounter.finish("victory")
	visuals._process(0)
	check(encounter.visual_targets.is_empty() and visuals.display_positions.is_empty() and visuals.fading_orbs.is_empty(), "Victory clears all spell visuals")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	MultiplayerManager.playerList.clear()
	await get_tree().create_timer(1).timeout
	print("Jefferson animation failures: ", failures)
	get_tree().quit(1 if failures else 0)
