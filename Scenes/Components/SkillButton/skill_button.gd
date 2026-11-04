extends TextureButton

@onready var player_cast_bar: Control = $"../../../../PlayerCastBar"
@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var timer: Timer = $Timer
@onready var time: Label = $Time
@onready var key: Label = $Key
var skillCast: Skill
var skillPlayer: Character
var skillHander
var pending = false
var target_id = 0
var combat_preview: Node
var queue_badge: Label
var cooldown_until_msec = 0
var changeKey = "":
	set(value):
		changeKey = value
		key.text = value
		shortcut = Shortcut.new()
		var events: Array[InputEvent] = []
		for code in ([KEY_R, KEY_4] if value == "R" else [value.unicode_at(0)]):
			for alt in [false, true]:
				var input_key = InputEventKey.new()
				input_key.keycode = code
				input_key.alt_pressed = alt
				events.append(input_key)
		shortcut.events = events

func _ready() -> void:
	skillHander = get_tree().current_scene.get_node("SkillHandler")
	skillHander.cast_confirmed.connect(on_cast_result)
	skillHander.combat_reset.connect(reset_button)
	combat_preview = get_tree().current_scene.get_node("CombatPreview")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_badge = Label.new()
	queue_badge.text = "FILA"
	queue_badge.position = Vector2(6, 2)
	queue_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_badge.add_theme_font_size_override("font_size", 11)
	queue_badge.add_theme_color_override("font_color", Color("ffe299"))
	queue_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	queue_badge.add_theme_constant_override("outline_size", 4)
	queue_badge.hide()
	add_child(queue_badge)
	set_process(false)

func _on_mouse_entered() -> void:
	if is_instance_valid(combat_preview) and is_instance_valid(skillCast):
		combat_preview.hover(skillCast)

func _on_mouse_exited() -> void:
	if is_instance_valid(combat_preview):
		combat_preview.clear_hover()

func _process(_delta: float) -> void:
	if not is_instance_valid(skillCast) or not is_instance_valid(skillPlayer):
		set_process(false)
		return
	time.text = "%d" % ceili(cooldown_remaining())
	progress_bar.value = cooldown_remaining()
	if skillCast.resetCoolDown:
		skillCast.resetCoolDown = false
		reset_cooldown()

func feedback(message: String) -> void:
	var bar = get_parent().get_parent().get_parent()
	bar.show_feedback(message)

func _on_pressed() -> void:
	if not is_instance_valid(skillPlayer) or not is_instance_valid(skillCast):
		return
	var bar = get_parent().get_parent().get_parent()
	bar.clear_buffer()
	if pending:
		return
	if is_busy():
		bar.buffer_action(self)
		return
	execute_request()

func set_queued(value: bool) -> void:
	queue_badge.visible = value

func cooldown_remaining() -> float:
	return maxf(0, (cooldown_until_msec - Time.get_ticks_msec()) / 1000.0)

func busy_seconds() -> float:
	var cooldown = 0.0 if skillCast.resetCoolDown else cooldown_remaining()
	return maxf(cooldown, player_cast_bar.remaining_seconds() if player_cast_bar.is_casting else 0.0)

func is_busy() -> bool:
	return busy_seconds() > 0 or player_cast_bar.is_casting

func can_request(ignore_casting: bool = false, chosen_target: Variant = null) -> bool:
	if skillHander.encounter_finished() or skillPlayer.spectator:
		return false
	if skillCast.targeting() == Skill.TargetMode.GROUND:
		target_id = 0
		return skillPlayer.charCurrentLife > 0 and (ignore_casting or not player_cast_bar.is_casting) and skillPlayer.charCurrentMana >= skillCast.skillManaCost
	return validateCast(ignore_casting, chosen_target)

func execute_request(chosen_target: Variant = null) -> bool:
	if pending or is_busy() or not can_request(false, chosen_target):
		return false
	if skillCast.targeting() == Skill.TargetMode.GROUND:
		combat_preview.begin(skillCast, self)
		return true
	combat_preview.cancel()
	pending = true
	skillHander.loadSkillScene.rpc_id(1, skillCast.skillScenePath, int(skillPlayer.name), target_id)
	return true

func validateCast(ignore_casting: bool = false, chosen_target: Variant = null) -> bool:
	if skillPlayer.charCurrentLife <= 0 or (player_cast_bar.is_casting and not ignore_casting):
		return false
	if skillPlayer.charCurrentMana < skillCast.skillManaCost:
		feedback(skillPlayer.resource_name + " insuficiente")
		return false
	var selected = skillPlayer.charCurrentTarget
	if skillCast.targeting() == Skill.TargetMode.ALLY and (Input.is_key_pressed(KEY_ALT) or not is_instance_valid(selected) or selected.charTeam != skillPlayer.charTeam):
		selected = skillPlayer
	target_id = (int(selected.name) if is_instance_valid(selected) else 0) if chosen_target == null else int(chosen_target)
	var resolved = skillHander.selected_target(skillCast, skillPlayer, target_id)
	if not skillHander.valid_target(skillCast, skillPlayer, resolved):
		feedback("Selecione um inimigo vivo ao alcance" if skillCast.targeting() == Skill.TargetMode.ENEMY else "Alvo fora do alcance")
		return false
	return true

func on_cast_result(caster_id: int, path: String, accepted: bool, duration: float, cooldown: float) -> void:
	if not is_instance_valid(skillPlayer) or not is_instance_valid(skillCast):
		return
	if caster_id != int(skillPlayer.name) or path != skillCast.skillScenePath:
		return
	pending = false
	if not accepted:
		feedback("Habilidade indisponível")
		return
	progress_bar.max_value = cooldown
	cooldown_until_msec = Time.get_ticks_msec() + roundi(cooldown * 1000)
	timer.start(maxf(0.01, cooldown))
	# Keep hover/tooltips active; _on_pressed rejects requests while the timer runs.
	disabled = false
	set_process(true)
	if duration > 0:
		skillHander.castBar(skillCast.skillName, duration)

func _on_timer_timeout() -> void:
	if cooldown_remaining() > 0:
		timer.start(cooldown_remaining())
		return
	reset_cooldown()

func reset_button() -> void:
	pending = false
	reset_cooldown()

func reset_cooldown() -> void:
	timer.stop()
	cooldown_until_msec = 0
	disabled = false
	time.text = ""
	progress_bar.value = 0
	set_process(false)

func _make_custom_tooltip(_for_text: String) -> Object:
	return SkillTooltip.create(skillCast, changeKey) if is_instance_valid(skillCast) else null

func _exit_tree() -> void:
	if is_instance_valid(skillHander):
		if skillHander.cast_confirmed.is_connected(on_cast_result):
			skillHander.cast_confirmed.disconnect(on_cast_result)
		if skillHander.combat_reset.is_connected(reset_button):
			skillHander.combat_reset.disconnect(reset_button)
