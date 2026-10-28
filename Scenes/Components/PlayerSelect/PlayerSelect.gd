extends CanvasLayer

signal playerSelected
var charList: Array[Character] = []
const ROLES = {
	"Warlock": "Sombras, maldições e explosão de DoTs",
	"Warrior": "Combate corpo a corpo e resistência",
	"Paladin": "Cura, proteção e áreas sagradas",
	"Hunter": "Flechas à distância, veneno e ataques em área"
}

func text_label(text: String, font_size: int, color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _ready() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color("101521")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Screen.add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	$Screen.add_child(margin)
	var scroll = ScrollContainer.new()
	margin.add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)
	content.add_child(text_label("ESCOLHA SEU PERSONAGEM", 26, Color("ffe299")))
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	content.add_child(cards)
	charList = [Aurora.new(), SirGura.new(), Charger.new(), Lulu.new()]
	for character in charList:
		character._enter_tree()
		var panel = PanelContainer.new()
		panel.custom_minimum_size.x = 236
		var box = StyleBoxFlat.new()
		box.bg_color = Color("1b2435")
		box.set_corner_radius_all(12)
		box.set_border_width_all(1)
		box.border_color = Color("5f6685")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_content_margin(side, 12)
		panel.add_theme_stylebox_override("panel", box)
		cards.add_child(panel)
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		panel.add_child(column)
		column.add_child(text_label(character.charName, 22))
		column.add_child(text_label(character.charClass, 17, Color("ffe299")))
		var portrait = TextureRect.new()
		portrait.texture = load(character.portraitImagePath)
		portrait.custom_minimum_size = Vector2(212, 96)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(portrait)
		var role = text_label(ROLES[character.charClass], 14, Color("bdc7dc"))
		role.custom_minimum_size = Vector2(212, 36)
		role.mouse_filter = Control.MOUSE_FILTER_STOP
		role.tooltip_text = "Recurso: " + character.resource_name
		column.add_child(role)
		var passive = PassivePanel.new()
		passive.configure(character, true)
		column.add_child(passive)
		for index in character.skillList.size():
			var skill = character.skillList[index]
			var preview = SelectionSkill.new()
			preview.configure(skill, "R / 4" if skill.is_ultimate else str(index + 1))
			column.add_child(preview)
		var button = Button.new()
		button.text = "Jogar com " + character.charName
		button.custom_minimum_size.y = 42
		button.pressed.connect(func(): playerSelected.emit(character))
		column.add_child(button)
	content.add_child(text_label("Passe o mouse nas passivas e habilidades para ver os detalhes.\nWASD: mover · Clique/Tab: alvo · Autoataque ao alcance · 1/2/3: habilidades · R/4: ultimate · Alt + cura: autocura", 14, Color("bdc7dc")))

func _exit_tree() -> void:
	for character in charList:
		if is_instance_valid(character):
			character.free()
