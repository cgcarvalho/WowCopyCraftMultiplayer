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
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	var camera: Camera2D = main.get_node("ArenaCamera")
	await get_tree().process_frame
	camera.force_update_scroll()
	check(camera.is_current() and camera.zoom == Vector2(0.75, 0.75), "Combat camera zooms out while remaining fixed for the whole party")
	check(camera.position == ArenaNavigation.WORLD_SIZE / 2, "Camera frames the expanded island rather than following one player")
	var map = main.uiHanlder.changeScene(Constants.MAP_FOREST)
	var grass: TileMapLayer = map.get_node("Grass")
	var water: TileMapLayer = map.get_node("Water")
	check(grass.get_used_rect().end.x >= 94 and grass.get_used_rect().end.y >= 54, "Painted ground expands in both dimensions")
	check(grass.get_cell_source_id(Vector2i(85, 35)) >= 0, "New reachable space has actual terrain underfoot")
	check(water.get_cell_source_id(Vector2i(-16, -16)) >= 0 and water.get_cell_source_id(Vector2i(110, 65)) >= 0, "Water overscan fills the edges of non-widescreen windows")
	check(map.get_node("Trees").get_used_cells().size() == 2 and ArenaNavigation.TRUNKS[0] == Vector2(850, 185), "Visual trees keep their existing gameplay collision positions")
	var point = ArenaNavigation.move(Vector2(1090, 600), Vector2(320, 0))
	check(point.is_equal_approx(Vector2(1410, 600)) and ArenaNavigation.allowed(point), "Player movement reaches the newly opened side of the arena")
	check(ArenaNavigation.allowed(ArenaNavigation.move(point, Vector2(5000, 5000))), "Movement still stops at the expanded outer boundary")
	var boss = encounter.boss
	check(Jefferson.ARENA.has_point(boss.safe_position(Vector2(1350, 620))), "Boss navigation can use the expanded fighting area")
	var sprite: AnimatedSprite2D = boss.get_node("AnimatedSprite2D")
	var frame = sprite.sprite_frames.get_frame_texture("idle", 0)
	check(is_equal_approx(frame.get_height() * boss.animation_scale, 630), "Jefferson is fifty percent larger in world space")
	check(boss.get_node("CollisionShape2D").shape.size == Vector2(240, 300), "Boss selection shape grows with his visual presentation")
	main.request_player("res://Scenes/Characters/Heroes/Lulu.tscn")
	var hero: Character = MultiplayerManager.playerList[1]
	hero.set_physics_process(false)
	hero.position = Vector2(1100, 500)
	var hud: CanvasLayer = main.get_node("CombatHUD")
	var bar: Control = main.get_node("CombatHUD/SkillBar")
	var ui_transform = bar.get_global_transform_with_canvas()
	var world_transform = hero.get_global_transform_with_canvas()
	camera.zoom = Vector2(0.6, 0.6)
	camera.force_update_scroll()
	check(hud.layer == 1 and bar.get_global_transform_with_canvas().is_equal_approx(ui_transform), "HUD position and scale are independent of combat zoom")
	check(not hero.get_global_transform_with_canvas().is_equal_approx(world_transform), "Zoom affects world objects while the HUD stays fixed")
	camera.zoom = Vector2(0.75, 0.75)
	camera.force_update_scroll()
	var preview = main.get_node("CombatPreview")
	var handler = main.get_node("SkillHandler")
	var rain: Skill = hero.skillList[3]
	var destination = Vector2(1380, 620)
	check(handler.valid_ground(rain, hero, destination), "Server permits ground abilities in the expanded arena")
	var button = bar.get_node("PanelContainer/HBoxContainer").get_child(3)
	preview.begin(rain, button)
	check(preview.confirm(destination), "Production targeting accepts a valid location in the new area")
	await get_tree().create_timer(0.7).timeout
	var placed: HeroAbility
	for node in main.get_children():
		if node is HeroAbility and node.ability_id == "arrow_rain":
			placed = node
	check(placed != null and placed.global_position.is_equal_approx(destination), "Ground skill lands at its world location despite camera zoom")
	var event_count = DamageNumbers.displayed_events
	DamageNumbers.display_number(7, destination, false, false, true)
	var number: Label = DamageNumbers.get_child(DamageNumbers.get_child_count() - 1)
	check(DamageNumbers.layer == 3 and number.label_settings.font_size == 23 and number.get_global_transform_with_canvas().get_scale() == Vector2.ONE, "Combat numbers retain their readable screen-space font size")
	check(DamageNumbers.displayed_events == event_count + 1 and number.position.distance_to(get_viewport().get_canvas_transform() * (destination + Vector2(0, -125))) <= 46, "Damage feedback projects the authoritative world position into the camera view")
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1).timeout
	print("Arena view failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
