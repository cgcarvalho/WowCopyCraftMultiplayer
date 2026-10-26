extends CanvasLayer

const PURPLE = Color("c9a2ff")
const EXPIRING = Color("ffbf78")
var racks: Dictionary = {}
var selected_panel: PanelContainer
var selected_list: VBoxContainer
var selected_title: Label
var selected_signature = ""
var selected_rows: Array = []
var icons: Dictionary = {}
var refresh = 0.0

func _ready() -> void:
	selected_panel = PanelContainer.new()
	selected_panel.name = "SelectedEffects"
	selected_panel.visible = false
	selected_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_panel.add_theme_stylebox_override("panel", panel_style(Color(Color("151927"), 0.93), 10))
	add_child(selected_panel)
	selected_list = VBoxContainer.new()
	selected_list.add_theme_constant_override("separation", 8)
	selected_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_panel.add_child(selected_list)
	selected_title = label("EFEITOS NO ALVO", 12, Color("c3c9db"))
	selected_list.add_child(selected_title)

func panel_style(background: Color, padding: float) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(7)
	box.set_border_width_all(1)
	box.border_color = Color("70548f")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var node = Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color("080b12"))
	node.add_theme_constant_override("outline_size", 3)
	return node

func groups_for(character: Character) -> Array:
	var groups: Dictionary = {}
	for effect in character.debuffList:
		if not is_instance_valid(effect) or effect.is_queued_for_deletion() or not effect is DamageOverTime:
			continue
		var remaining = maxf(0, effect.skillDotSeconds - effect.skillTimer)
		if remaining <= 0:
			continue
		var key: String = effect.skillScenePath
		if not groups.has(key):
			groups[key] = {"key": key, "name": effect.skillName, "icon": effect.iconFilePath, "remaining": remaining, "duration": effect.skillDotSeconds, "count": 1}
		else:
			groups[key]["remaining"] = maxf(groups[key]["remaining"], remaining)
			groups[key]["count"] += 1
	var result: Array = groups.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a["name"] < b["name"])
	return result

func signature(groups: Array) -> String:
	var keys: Array[String] = []
	for group in groups:
		keys.append(group["key"])
	return "|".join(keys)

func effect_icon(path: String, dimensions: Vector2) -> TextureRect:
	if not icons.has(path):
		icons[path] = load(path)
	var node = TextureRect.new()
	node.texture = icons[path]
	node.custom_minimum_size = dimensions
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func update_labels(row: Dictionary, group: Dictionary) -> void:
	var remaining: float = group["remaining"]
	var color = EXPIRING if remaining <= 3 else PURPLE
	row["time"].text = "%ds" % ceili(remaining)
	row["time"].add_theme_color_override("font_color", color)
	if row.has("count"):
		row["count"].text = "×%d" % group["count"] if group["count"] > 1 else ""
	if row.has("bar"):
		row["bar"].max_value = group["duration"]
		row["bar"].value = remaining

func build_rack(groups: Array) -> Dictionary:
	var container = HBoxContainer.new()
	container.name = "DotIndicators"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_constant_override("separation", 6)
	add_child(container)
	var rows: Array = []
	for group in groups:
		var chip = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", panel_style(Color(Color("101522"), 0.97), 4))
		container.add_child(chip)
		var column = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		chip.add_child(column)
		var icon = effect_icon(group["icon"], Vector2(30, 30))
		column.add_child(icon)
		var seconds = label("", 15)
		seconds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(seconds)
		var count = label("", 12, Color.WHITE)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.position = Vector2(14, -4)
		icon.add_child(count)
		rows.append({"time": seconds, "count": count})
	return {"node": container, "rows": rows, "signature": signature(groups)}

func overhead_position(character: Character, container: Control) -> Vector2:
	var sprite: AnimatedSprite2D = character.get_node("AnimatedSprite2D")
	var frame = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var half_height = frame.get_height() * sprite.scale.y / 2 if frame != null else 100.0
	var head = character.get_global_transform_with_canvas() * (sprite.position - Vector2(0, half_height))
	var viewport = get_viewport().get_visible_rect().size
	var result = head - Vector2(container.size.x / 2, container.size.y + 10)
	result.x = clampf(result.x, 8, maxf(8, viewport.x - container.size.x - 8))
	result.y = maxf(112, result.y)
	return result

func update_selected(groups: Array) -> void:
	var key = signature(groups)
	if key != selected_signature:
		for row in selected_rows:
			row["node"].queue_free()
		selected_rows.clear()
		selected_signature = key
		for group in groups:
			var line = HBoxContainer.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_theme_constant_override("separation", 10)
			selected_list.add_child(line)
			line.add_child(effect_icon(group["icon"], Vector2(36, 36)))
			var column = VBoxContainer.new()
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.add_child(column)
			column.add_child(label(group["name"], 15, Color.WHITE))
			var bar = ProgressBar.new()
			bar.custom_minimum_size = Vector2(140, 5)
			bar.show_percentage = false
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_theme_stylebox_override("background", panel_style(Color("303448"), 0))
			bar.add_theme_stylebox_override("fill", panel_style(PURPLE, 0))
			column.add_child(bar)
			var count = label("", 12, Color("bfc6d6"))
			column.add_child(count)
			var seconds = label("", 20, PURPLE)
			seconds.custom_minimum_size.x = 38
			seconds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(seconds)
			selected_rows.append({"node": line, "time": seconds, "count": count, "bar": bar})
	for i in groups.size():
		update_labels(selected_rows[i], groups[i])
	selected_panel.visible = not groups.is_empty()
	selected_panel.size = selected_panel.get_combined_minimum_size()
	selected_panel.position = Vector2(get_viewport().get_visible_rect().size.x - selected_panel.size.x - 18, 140)

func _process(delta: float) -> void:
	# Position every frame; update timer text ten times per second.
	for id in racks.keys():
		var character = instance_from_id(id)
		if is_instance_valid(character):
			var node: Control = racks[id]["node"]
			node.position = overhead_position(character, node)
	refresh -= delta
	if refresh > 0:
		return
	refresh = 0.1
	var characters: Array = MultiplayerManager.playerList.values() + MultiplayerManager.enemies.values()
	var alive_ids: Array = []
	for character in characters:
		if not is_instance_valid(character) or character.charCurrentLife <= 0:
			continue
		var id: int = character.get_instance_id()
		var groups = groups_for(character)
		if groups.is_empty():
			continue
		alive_ids.append(id)
		if not racks.has(id) or racks[id]["signature"] != signature(groups):
			if racks.has(id):
				racks[id]["node"].queue_free()
			racks[id] = build_rack(groups)
		for i in groups.size():
			update_labels(racks[id]["rows"][i], groups[i])
	for id in racks.keys():
		if id not in alive_ids:
			racks[id]["node"].queue_free()
			racks.erase(id)
	var target: Character
	var local_player: Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if is_instance_valid(local_player) and is_instance_valid(local_player.charCurrentTarget):
		target = local_player.charCurrentTarget
	update_selected(groups_for(target) if is_instance_valid(target) and target.charCurrentLife > 0 else [])
