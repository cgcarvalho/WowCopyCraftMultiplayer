extends CanvasLayer

var screen: Control
var overlay: ColorRect
var content: VBoxContainer
var signature = ""
var selecting_class = false
var resource_text: Label
var passive_text: Label
var aim_text: Label
var speech: Label
var interrupt_button: Button
var countdown_text: Label
var result_delay = 0.0
var hud_backplate: Panel
var last_stage = ""
var name_draft = ""
var talents_open = false
var report_open = true
@onready var main = get_parent()
@onready var session = main.get_node("Session")

func label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var node = Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func button(text: String, callback: Callable) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.pressed.connect(callback)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("302c29") if state == "normal" else Color("554633")
		if state == "disabled":
			style.bg_color = Color("242329")
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		style.border_color = Color("91784b") if state != "disabled" else Color("45413b")
		style.content_margin_left = 12
		style.content_margin_right = 12
		if state == "focus":
			style.draw_center = false
			style.border_color = Color("ffe6a0")
			node.add_theme_stylebox_override("focus", style)
		else:
			node.add_theme_stylebox_override(state, style)
	return node

func panel_style() -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color("1a1a22")
	box.border_color = Color("a78950")
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, 18)
	return box

func _ready() -> void:
	layer = 15
	hud_backplate = Panel.new()
	hud_backplate.z_index = 4
	hud_backplate.position = Vector2(90, 500)
	hud_backplate.size = Vector2(1050, 135)
	hud_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style = panel_style()
	hud_style.bg_color = Color(0.07, 0.07, 0.09, 0.88)
	hud_backplate.add_theme_stylebox_override("panel", hud_style)
	main.get_node("CombatHUD").add_child.call_deferred(hud_backplate)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	resource_text = label("", 17, Color("ead09b"))
	resource_text.position = Vector2(100, 510)
	resource_text.size = Vector2(570, 26)
	screen.add_child(resource_text)
	passive_text = label("", 13, Color("e5ddce"))
	passive_text.position = Vector2(380, 549)
	passive_text.size = Vector2(580, 40)
	screen.add_child(passive_text)
	aim_text = label("", 14, Color("ffe9ae"))
	aim_text.position = Vector2(380, 592)
	aim_text.size = Vector2(590, 40)
	screen.add_child(aim_text)
	speech = label("", 17, Color("e2b8ff"))
	speech.position = Vector2(365, 105)
	speech.size = Vector2(480, 55)
	speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech.add_theme_color_override("font_outline_color", Color.BLACK)
	speech.add_theme_constant_override("outline_size", 5)
	screen.add_child(speech)
	interrupt_button = button("F · Interromper", func(): main.get_node("SkillHandler").request_interrupt.rpc_id(1))
	interrupt_button.position = Vector2(970, 555)
	interrupt_button.size = Vector2(170, 44)
	interrupt_button.tooltip_text = "Interrompe Cataclismo Arcano. Recarga: 16s. Alcance: 200 para Warrior, 650 para as demais classes."
	screen.add_child(interrupt_button)
	countdown_text = label("", 54, Color("ffe4a6"))
	countdown_text.position = Vector2(350, 230)
	countdown_text.size = Vector2(450, 130)
	countdown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(countdown_text)
	overlay = ColorRect.new()
	overlay.color = Color(0.035, 0.04, 0.065, 0.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(overlay)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margin)
	var scroll = ScrollContainer.new()
	margin.add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	panel.custom_minimum_size.x = 830
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	overlay.hide()
	get_viewport().size_changed.connect(layout_combat_hud)
	layout_combat_hud()

func layout_combat_hud() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var horizontal = maxf(0, (viewport_size.x - 1152) / 2)
	var bottom = maxf(0, viewport_size.y - 648)
	hud_backplate.position = Vector2(90 + horizontal, 500 + bottom)
	main.get_node("CombatHUD/SkillBar").position = Vector2(100 + horizontal, 550 + bottom)
	resource_text.position = Vector2(100 + horizontal, 510 + bottom)
	passive_text.position = Vector2(380 + horizontal, 549 + bottom)
	aim_text.position = Vector2(380 + horizontal, 592 + bottom)
	interrupt_button.position = Vector2(970 + horizontal, 555 + bottom)
	speech.position.x = 365 + horizontal
	countdown_text.position.x = 350 + horizontal

func enter_selection() -> void:
	selecting_class = true
	main.loadCharSelectionScreen()

func add_party() -> void:
	var ids = session.roster.keys()
	ids.sort()
	for id in ids:
		var member: Dictionary = session.roster[id]
		var state = "Pronto" if member.ready else "Escolhendo / não pronto"
		if session.stage == "victory":
			state = "Melhoria escolhida" if member.reward != "" else "Escolhendo melhoria"
		var text = "%s · %s · %s" % [member.name, member["class"] if member["class"] != "" else "Sem classe", state]
		if member["class"] != "":
			text += "\n" + TalentTree.summary(member["class"], member.get("talents", {}))
		content.add_child(label(text, 16, Color("a5dbb4") if member.ready else Color("c9c4b8")))

func show_talents(value: bool) -> void:
	talents_open = value
	rebuild()

func add_talents(member: Dictionary) -> void:
	var choices: Dictionary = member.get("talents", {})
	var remaining = TalentTree.POINTS - TalentTree.spent(choices)
	content.add_child(label("TALENTOS · %s" % member.get("class", ""), 26, Color("edcf8d")))
	content.add_child(label("%d / %d pontos disponíveis · Cada talento exige o anterior do mesmo caminho.\nVocê pode combinar caminhos. Alterações cancelam seu Pronto." % [remaining, TalentTree.POINTS], 15))
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	var tree = TalentTree.branches(member.get("class", ""))
	for branch in tree:
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.custom_minimum_size.x = 382
		column.add_theme_constant_override("separation", 8)
		columns.add_child(column)
		column.add_child(label(tree[branch].name, 21, Color("edcf8d")))
		for index in tree[branch].nodes.size():
			var tier = index + 1
			var rank = int(choices.get(branch, 0))
			var node_data = tree[branch].nodes[index]
			var state = "APRENDIDO" if rank >= tier else ("1 PONTO" if rank == tier - 1 and remaining > 0 else "BLOQUEADO")
			var node = button("%d · %s · %s\n%s" % [tier, node_data[0], state, node_data[1]], func(): session.learn_talent.rpc_id(1, branch, tier))
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node.alignment = HORIZONTAL_ALIGNMENT_LEFT
			node.add_theme_font_size_override("font_size", 14)
			node.custom_minimum_size = Vector2(382, 92)
			node.tooltip_text = str(node_data[1]) + ("\nExige o talento anterior deste caminho." if tier > 1 else "")
			node.disabled = session.transitioning or remaining <= 0 or rank != tier - 1
			if rank >= tier:
				node.add_theme_color_override("font_disabled_color", Color("a5dbb4"))
			column.add_child(node)
	var reset = button("Redistribuir pontos · grátis", func(): session.reset_talents.rpc_id(1))
	reset.disabled = session.transitioning or TalentTree.spent(choices) == 0
	content.add_child(reset)
	content.add_child(button("Voltar ao grupo", func(): show_talents(false)))

func add_report() -> void:
	var report: Dictionary = session.report
	if report.is_empty():
		content.add_child(label("Aguardando o resumo do host...", 16))
		return
	var seconds = float(report.duration)
	content.add_child(label("Tempo de combate: %02d:%02d · Destaques por contribuição" % [int(seconds) / 60, int(seconds) % 60], 16, Color("edcf8d")))
	var players: Dictionary = report.players
	var ids = players.keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = players[id]
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", panel_style())
		content.add_child(card)
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		card.add_child(column)
		var title = "%s · %s · %s" % [row.name, row["class"], row.talents]
		if not session.roster.has(id):
			title += " · Desconectado"
		column.add_child(label(title, 17, Color("edcf8d")))
		var rate = maxf(0.001, seconds)
		column.add_child(label("Dano: %d (%.1f/s)     Cura: %d (%.1f/s)     Escudos absorvidos: %d" % [row.damage, row.damage / rate, row.healing, row.healing / rate, row.absorbed], 16))
		var details = label("Dano recebido: %d     Interrupções: %d     Mecânicas: %d     Mortes: %d" % [row.damage_taken, row.interrupts, row.mechanics, row.deaths], 14, Color("c9c4b8"))
		details.tooltip_text = "Mecânicas: Rupturas e Lanças evitadas, Marcas separadas e Vínculos divididos com pelo menos um aliado.\nEscudos contam somente o dano realmente absorvido, atribuído a quem concedeu a proteção."
		details.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(details)
		var badges = BattleReport.highlights(players, id)
		if badges != "":
			column.add_child(label("Destaque · " + badges, 14, Color("a5dbb4")))
	content.add_child(label("Dano e cura efetivos: excesso de dano e sobrecura não contam. A contagem reinicia a cada tentativa.", 13, Color("c9c4b8")))

func rebuild() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var local_id = multiplayer.get_unique_id()
	var member: Dictionary = session.roster.get(local_id, {})
	var is_host = multiplayer.is_server()
	if session.stage == "lobby":
		if talents_open and member.get("class", "") != "":
			add_talents(member)
			return
		content.add_child(label("GRUPO · JEFFERSON, O ARCANISTA", 26, Color("edcf8d")))
		content.add_child(label("Escolha sua classe, marque Pronto e aguarde o host iniciar.", 16))
		add_party()
		var controls = HBoxContainer.new()
		controls.add_theme_constant_override("separation", 12)
		content.add_child(controls)
		var field = LineEdit.new()
		field.placeholder_text = "Seu nome"
		field.text = name_draft if name_draft != "" else str(member.get("name", ""))
		field.custom_minimum_size.x = 210
		field.text_changed.connect(func(value): name_draft = value)
		field.text_submitted.connect(func(value): session.set_player_name.rpc_id(1, value))
		controls.add_child(field)
		controls.add_child(button("Salvar nome", func(): session.set_player_name.rpc_id(1, field.text)))
		var select = button("Aguarde..." if session.transitioning else "Escolher / trocar classe", enter_selection)
		select.disabled = session.transitioning
		controls.add_child(select)
		var ready = button("Cancelar pronto" if member.get("ready", false) else "Estou pronto", func(): session.set_ready.rpc_id(1, not member.get("ready", false)))
		ready.disabled = session.transitioning or member.get("class", "") == ""
		controls.add_child(ready)
		var talents = button("Árvore de talentos · %d/%d pontos" % [TalentTree.spent(member.get("talents", {})), TalentTree.POINTS], func(): show_talents(true))
		talents.disabled = session.transitioning or member.get("class", "") == ""
		content.add_child(talents)
		if is_host:
			var start = button("Iniciar encontro", func(): session.start_match.rpc_id(1))
			start.disabled = not session.can_start()
			content.add_child(start)
		else:
			content.add_child(label("O host inicia quando todos estiverem prontos.", 14, Color("d5c69e")))
	elif session.stage in ["victory", "defeat"]:
		var won = session.stage == "victory"
		content.add_child(label(("VITÓRIA" if won else "DERROTA") + " · COMBATE %d" % session.round_index, 30, Color("edcf8d")))
		var tabs = HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 12)
		content.add_child(tabs)
		tabs.add_child(button("Resumo do combate" + (" ✓" if report_open else ""), func(): report_open = true; rebuild()))
		tabs.add_child(button(("Melhorias e grupo" if won else "Grupo") + (" ✓" if not report_open else ""), func(): report_open = false; rebuild()))
		if report_open:
			add_report()
		var result_tip = "O grupo caiu. Você pode tentar novamente sem fechar o jogo."
		if won:
			result_tip = "Abra Melhorias e grupo para escolher sua melhoria e continuar." if report_open else "Escolha uma melhoria. Ela vale para as próximas tentativas desta expedição."
		content.add_child(label(result_tip, 16))
		if not report_open and won and member.get("reward", "skip") == "":
			var cards = HBoxContainer.new()
			cards.add_theme_constant_override("separation", 12)
			content.add_child(cards)
			for choice in session.UPGRADE_NAMES:
				var card = PanelContainer.new()
				card.custom_minimum_size.x = 250
				card.add_theme_stylebox_override("panel", panel_style())
				cards.add_child(card)
				var column = VBoxContainer.new()
				column.add_theme_constant_override("separation", 12)
				card.add_child(column)
				column.add_child(label(session.UPGRADE_NAMES[choice], 19, Color("edcf8d")))
				var description = label(session.UPGRADE_DESCRIPTIONS[choice], 15)
				description.custom_minimum_size = Vector2(210, 72)
				column.add_child(description)
				column.add_child(button("Escolher", func(): session.choose_upgrade.rpc_id(1, choice)))
		elif not report_open and won:
			content.add_child(label("Melhoria registrada. Aguardando os demais jogadores.", 16, Color("a5dbb4")))
		if not report_open:
			add_party()
		if is_host:
			var retry = button("Próximo combate (+15% vida do boss)" if won else "Tentar novamente", func(): session.retry.rpc_id(1))
			retry.disabled = won and not session.all_rewards_chosen()
			content.add_child(retry)
			content.add_child(button("Voltar à seleção · reiniciar expedição", func(): session.return_to_selection.rpc_id(1)))
		else:
			content.add_child(label("Aguardando o host continuar ou voltar à seleção.", 14))
	else:
		content.add_child(label("ENCONTRO EM ANDAMENTO", 26, Color("edcf8d")))
		content.add_child(label("Você entrou durante a luta e participará da próxima tentativa.", 16))
		if member.get("class", "") == "":
			content.add_child(button("Escolher minha classe", enter_selection))
	content.add_child(button("Sair da sessão", main.leave_session))

func _process(delta: float) -> void:
	if not session.running:
		hud_backplate.hide()
		screen.hide()
		return
	screen.show()
	var hero: Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	var active = session.stage in ["active", "countdown"] and is_instance_valid(hero) and not hero.spectator
	hud_backplate.visible = active
	for node in [resource_text, passive_text, aim_text, interrupt_button]:
		node.visible = active
	for path in ["PlayerHP", "SkillBar"]:
		main.get_node("CombatHUD/" + path).visible = active
	if not active:
		main.get_node("CombatHUD/TargetHP").hide()
	countdown_text.visible = session.stage == "countdown"
	countdown_text.text = "COMEÇA EM\n%d" % maxi(1, ceili(session.countdown))
	if active:
		resource_text.text = "%s: %d / %d" % [hero.resource_name, int(hero.charCurrentMana), int(hero.charTotalMana)]
		resource_text.add_theme_color_override("font_color", hero.resource_color)
		passive_text.text = hero.passive_text()
		var preview = main.get_node("CombatPreview")
		aim_text.text = preview.hint if preview.aiming else "Tab: selecionar · F: interromper · Áreas: clique para confirmar"
		interrupt_button.text = "F · %ds" % ceili(hero.interrupt_remaining) if hero.interrupt_remaining > 0 else "F · Interromper"
	var encounter = main.get_node("BossEncounter")
	speech.text = encounter.speech if encounter.speech_remaining > 0 and session.stage != "lobby" else ""
	if session.stage != last_stage:
		last_stage = session.stage
		talents_open = false
		report_open = true
		result_delay = 0.85 if session.stage in ["victory", "defeat"] else 0
	result_delay = maxf(0, result_delay - delta)
	var member: Dictionary = session.roster.get(multiplayer.get_unique_id(), {})
	overlay.visible = not selecting_class and result_delay <= 0 and (session.stage in ["lobby", "victory", "defeat"] or member.get("spectator", false))
	var current = session.stage + ":" + str(session.revision) + ":" + str(session.roster) + ":" + str(session.report)
	if current != signature:
		signature = current
		rebuild()
