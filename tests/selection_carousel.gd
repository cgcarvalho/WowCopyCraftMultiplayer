extends Node

var failures = 0
var checks = 0
var selection: CanvasLayer
var output_dir = ""
var confirmations = 0
var chosen_path = ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in 3:
		await get_tree().process_frame

func visible_rows(node: Node) -> Array:
	var rows = [node] if node is SelectionSkill and node.is_visible_in_tree() else []
	for child in node.get_children():
		rows.append_array(visible_rows(child))
	return rows

func layout_issues(node: Node, bounds: Rect2) -> Array[String]:
	var issues: Array[String] = []
	if node is ScrollContainer:
		issues.append("ScrollContainer: " + str(node.get_path()))
	if node is Control and node.is_visible_in_tree():
		var rect = node.get_global_rect()
		if not bounds.grow(1).encloses(rect):
			issues.append(str(node.get_path()) + " " + str(rect))
	for child in node.get_children():
		issues.append_array(layout_issues(child, bounds))
	return issues

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event)
	event.pressed = false
	get_viewport().push_input(event)
	await settle()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")
	selection = load("res://Scenes/Components/PlayerSelect/PlayerSelect.tscn").instantiate()
	add_child(selection)
	await settle()
	check(selection.charList.size() == 6 and selection.neighbor_buttons.size() == 2, "The carousel has all six heroes and two selectable neighbors")
	var capture = not output_dir.is_empty() and DisplayServer.get_name() != "headless"
	# Capture one fixed-size window per rendered run; headless checks resize in place.
	var resolutions = [get_tree().root.size] if capture else [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1152, 648), Vector2i(960, 540), Vector2i(800, 600)]
	for resolution in resolutions:
		get_tree().root.size = resolution
		await settle()
		var problems: Array[String] = []
		for index in selection.charList.size():
			selection.show_character(index, false)
			await settle()
			problems.append_array(layout_issues(selection, Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)))
			if capture and index in [2, 5]:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output_dir.path_join("carrossel-%dx%d-%s.png" % [resolution.x, resolution.y, selection.current_character().charName]))
		check(problems.is_empty(), "All six heroes fit at %dx%d with the Play button and no scrolling%s" % [resolution.x, resolution.y, "" if problems.is_empty() else ": " + " | ".join(problems)])
	for index in selection.charList.size():
		selection.show_character(index, false)
		await settle()
		var hero = selection.current_character()
		var rows = visible_rows(selection)
		var matching = rows.size() == 4 and selection.hero_name.text == hero.charName and selection.play_button.text == "Jogar com " + hero.charName
		for row_index in rows.size():
			matching = matching and rows[row_index].skill == hero.skillList[row_index]
		check(matching and selection.passive_panels[index].hero == hero and selection.passive_panels[index].is_visible_in_tree(), hero.charName + " shows its own four skills, passive and confirmation")
	selection.show_character(5, false)
	selection.next_button.pressed.emit()
	check(selection.selected_index == 0, "The next arrow wraps from the last hero to the first")
	selection.previous_button.pressed.emit()
	check(selection.selected_index == 5, "The previous arrow wraps from the first hero to the last")
	selection.neighbor_buttons[0].pressed.emit()
	check(selection.selected_index == 4, "Clicking the left neighbor selects the character shown there")
	selection.neighbor_buttons[1].pressed.emit()
	check(selection.selected_index == 5, "Clicking the right neighbor selects the character shown there")
	selection.quick_buttons[2].pressed.emit()
	check(selection.current_character() is DualWieldWarrior and selection.quick_buttons[2].button_pressed, "The Tiagolas shortcut selects and highlights Tiagolas")
	await key(KEY_RIGHT)
	check(selection.selected_index == 3, "Right-arrow keyboard input advances the carousel")
	await key(KEY_A)
	check(selection.selected_index == 2, "A keyboard input returns to the preceding hero")
	await key(KEY_D)
	check(selection.selected_index == 3, "D keyboard input advances the carousel")
	await key(KEY_LEFT)
	check(selection.selected_index == 2, "Left-arrow keyboard input returns to Tiagolas")
	selection.playerSelected.connect(func(hero):
		confirmations += 1
		chosen_path = hero.scenePath)
	selection.play_button.grab_focus()
	await key(KEY_ENTER)
	selection.choose_character()
	selection.navigate(1)
	check(confirmations == 1 and chosen_path == DualWieldWarrior.SCENE_PATH and selection.selected_index == 2, "Enter confirms the highlighted hero once and prevents duplicate selection")
	selection.free()
	await settle()
	var main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	main.get_node("Session").open_lobby()
	main.loadCharSelectionScreen()
	var live_selection = main.get_node("CurrentMap").get_child(0)
	live_selection.show_character(2, false)
	live_selection.play_button.pressed.emit()
	await settle()
	var spawned = MultiplayerManager.playerList.get(1)
	check(is_instance_valid(spawned) and spawned is DualWieldWarrior and not main.get_node("SessionUI").selecting_class, "The real Play button spawns Tiagolas and opens the lobby")
	main.get_node("Session").set_ready(true)
	check(main.get_node("Session").can_start(), "The selected hero can ready up and start the encounter through the existing lobby")
	get_tree().current_scene = self
	main.queue_free()
	await settle()
	print("Selection carousel failures: ", failures, " (", checks, " checks)")
	get_tree().quit(1 if failures else 0)
