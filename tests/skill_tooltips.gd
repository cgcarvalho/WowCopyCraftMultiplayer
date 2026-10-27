extends Node

var failures = 0
var checks = 0
var main: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func text_in(node: Node) -> String:
	var text = node.text if node is Label else ""
	for child in node.get_children():
		text += "\n" + text_in(child)
	return text

func previews_in(node: Node) -> Array:
	var rows: Array = [node] if node is SelectionSkill else []
	for child in node.get_children():
		rows.append_array(previews_in(child))
	return rows

func complete(panel: Control, skill: Skill) -> bool:
	var text = text_in(panel)
	return not skill.description.is_empty() and text.contains(skill.skillName) and text.contains(skill.description) and text.contains(skill.cost_label + ":") and text.contains("Recarga:") and text.contains("Conjuração: " + skill.cast_description()) and text.contains("Alvo: " + skill.target_description()) and text.contains("Tecla") and (not skill.is_ultimate or text.contains("ULTIMATE"))

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.get_node("MultiplayerHUD").hide()
	var encounter = main.get_node("BossEncounter")
	encounter.set_physics_process(false)
	encounter.boss.set_physics_process(false)
	encounter.status = "active"
	var bar = main.get_node("CombatHUD/SkillBar")
	for hero_name in ["Aurora", "SirGura", "Charger", "Lulu"]:
		main.request_player("res://Scenes/Characters/Heroes/" + hero_name + ".tscn")
		var hero: Character = MultiplayerManager.playerList[1]
		hero.set_physics_process(false)
		var buttons = bar.get_node("PanelContainer/HBoxContainer").get_children()
		check(buttons.size() == 4, hero_name + " exposes all four skill tooltips in combat")
		for button in buttons:
			var panel = button._make_custom_tooltip(button.tooltip_text)
			check(not button.tooltip_text.is_empty() and complete(panel, button.skillCast), hero_name + " / " + button.skillCast.skillName + ": complete combat tooltip")
			panel.free()
			button.on_cast_result(1, button.skillCast.skillScenePath, true, 0, 4)
			check(not button.disabled and not button.timer.is_stopped() and button.mouse_filter != Control.MOUSE_FILTER_IGNORE, button.skillCast.skillName + ": tooltip remains accessible during cooldown")
		if hero_name == "Charger":
			var sprite: AnimatedSprite2D = hero.get_node("AnimatedSprite2D")
			var frames = sprite.sprite_frames
			check(frames.get_frame_count("auto_attack") == 8 and frames.get_frame_texture("auto_attack", 0).atlas.resource_path.ends_with("Charger Auto Attack.png"), "Charger has a dedicated eight-frame hammer attack atlas")
			check(frames.get_frame_texture("auto_attack", 0).atlas != frames.get_frame_texture("cast", 0).atlas, "Charger autoattack no longer reuses spellcasting frames")
			check(is_equal_approx(frames.get_frame_count("auto_attack") / frames.get_animation_speed("auto_attack"), 1.1), "Hammer swing duration matches the existing attack interval")
			sprite.play("auto_attack")
			check(sprite.scale.is_equal_approx(Vector2(1.2, 1.2)), "Hammer animation uses calibrated character size")
			sprite.play("cast")
			check(sprite.scale == Vector2.ONE, "Casting restores the original sprite scale")
			sprite.play("auto_attack")
			hero.reset_for_round(hero.position, {})
			hero.set_physics_process(false)
			check(sprite.animation == &"idle" and sprite.scale == Vector2.ONE, "Round reset returns Charger to correctly sized idle")
			hero.charCritChance = 0
			hero.position = Vector2(400, 300)
			encounter.boss.position = Vector2(480, 300)
			hero.charCurrentTarget = encounter.boss
			var hp = encounter.boss.charCurrentLife
			hero.state_machine.set_state(Attack.new())
			var attack: Attack = hero.state_machine.current_state
			attack.physics_process(hero.attack_interval * 0.34)
			check(encounter.boss.charCurrentLife == hp, "Charger windup does not damage before the strike")
			attack.physics_process(hero.attack_interval * 0.02)
			for node in main.get_children():
				if node is CombatProjectile:
					node.set_physics_process(false)
					node._physics_process(0.001)
					node.queue_free()
			check(encounter.boss.charCurrentLife == hp - 8 and hero.charCurrentMana == 3, "Hammer strike deals one authorized hit and generates holy power at impact")
			check(int(floor(0.35 * frames.get_animation_speed("auto_attack") * hero.attack_interval)) == 2, "Attack release coincides with the hammer impact frame")
		if hero_name == "Lulu":
			hero.reset_for_round(hero.position, {}, {"marksman": 3})
			hero.set_physics_process(false)
			bar.createButtons()
			var button = bar.get_node("PanelContainer/HBoxContainer").get_child(0)
			var panel = button._make_custom_tooltip(button.tooltip_text)
			check(text_in(panel).contains("Talentos:") and text_in(panel).contains("0.7 s"), "Visible combat tooltip includes talents and modified cast time")
			panel.free()
			get_tree().current_scene = self
			button.mouse_entered.emit()
			button.mouse_exited.emit()
			check(main.get_node("CombatPreview").preview_skill == null, "Hover can exit safely while the current scene changes")
			get_tree().current_scene = main
		hero.free()
	var selection = load("res://Scenes/Components/PlayerSelect/PlayerSelect.tscn").instantiate()
	main.add_child(selection)
	var rows = previews_in(selection)
	check(rows.size() == 16, "Selection screen exposes all sixteen playable abilities")
	for row in rows:
		var panel = row._make_custom_tooltip(row.tooltip_text)
		check(row.mouse_filter == Control.MOUSE_FILTER_STOP and complete(panel, row.skill), row.skill.skillName + ": selection tooltip receives hover over the entire icon/name row")
		check(row.get_child(0).texture != null and row.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE and row.get_child(1).mouse_filter == Control.MOUSE_FILTER_IGNORE, row.skill.skillName + ": icon and text preserve hover on the parent row")
		panel.free()
	selection.queue_free()
	get_tree().current_scene = self
	main.queue_free()
	await get_tree().process_frame
	print("Skill tooltip failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
