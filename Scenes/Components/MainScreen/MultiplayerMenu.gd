extends Control

func _ready() -> void:
	get_viewport().size_changed.connect(fit_panel)
	$Panel.resized.connect(fit_panel)
	call_deferred("fit_panel")
	var menu_theme = Theme.new()
	menu_theme.default_font_size = 16
	var card = StyleBoxFlat.new()
	card.bg_color = Color(Color("111a2a"), 0.96)
	card.set_corner_radius_all(18)
	card.set_border_width_all(1)
	card.border_color = Color("83704c")
	card.shadow_color = Color(0, 0, 0, 0.5)
	card.shadow_size = 18
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		card.set_content_margin(side, 26)
	menu_theme.set_stylebox("panel", "PanelContainer", card)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("25344b") if state == "normal" else Color("374b68")
		if state == "disabled":
			box.bg_color = Color("202634")
		box.set_corner_radius_all(8)
		box.set_border_width_all(2 if state == "focus" else 1)
		box.border_color = Color("edce8c") if state == "focus" else Color("53627a")
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.draw_center = false
		menu_theme.set_stylebox(state, "Button", box)
	var field = StyleBoxFlat.new()
	field.bg_color = Color("0a111e")
	field.set_corner_radius_all(8)
	field.set_border_width_all(1)
	field.border_color = Color("53627a")
	field.content_margin_left = 14
	field.content_margin_right = 14
	menu_theme.set_stylebox("normal", "LineEdit", field)
	var focused = field.duplicate()
	focused.border_color = Color("edce8c")
	menu_theme.set_stylebox("focus", "LineEdit", focused)
	menu_theme.set_color("font_color", "Label", Color("e9edf5"))
	menu_theme.set_color("font_color", "Button", Color("e9edf5"))
	theme = menu_theme
	var host: Button = $Panel/VBoxContainer/Host
	var gold = StyleBoxFlat.new()
	gold.bg_color = Color("d8b46e")
	gold.set_corner_radius_all(8)
	host.add_theme_stylebox_override("normal", gold)
	var hover = gold.duplicate()
	hover.bg_color = Color("f0d394")
	host.add_theme_stylebox_override("hover", hover)
	host.add_theme_stylebox_override("pressed", hover)
	host.add_theme_color_override("font_color", Color("172033"))
	host.add_theme_color_override("font_hover_color", Color("172033"))
	host.add_theme_color_override("font_pressed_color", Color("172033"))
	host.add_theme_color_override("font_focus_color", Color("172033"))
	host.add_theme_color_override("font_hover_pressed_color", Color("172033"))
	%ServerAddress.text_submitted.connect(func(_value: String):
		if not %Join.disabled:
			get_parent().join_game())
	host.call_deferred("grab_focus")

func fit_panel() -> void:
	var viewport_size = get_viewport_rect().size
	$Panel.position = (viewport_size - $Panel.size) / 2
