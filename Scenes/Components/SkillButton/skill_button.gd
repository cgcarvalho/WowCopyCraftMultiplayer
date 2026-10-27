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
	skillHander.combat_reset.connect(_on_timer_timeout)
	combat_preview = get_tree().current_scene.get_node("CombatPreview")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
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
	time.text = "%d" % ceili(timer.time_left)
	progress_bar.value = timer.time_left
	if skillCast.resetCoolDown:
		skillCast.resetCoolDown = false
		timer.stop()
		_on_timer_timeout()

func feedback(message: String) -> void:
	var bar = get_parent().get_parent().get_parent()
	bar.show_feedback(message)

func _on_pressed() -> void:
	if pending or not timer.is_stopped():
		return
	if skillCast.targeting() == Skill.TargetMode.GROUND:
		if skillPlayer.charCurrentMana < skillCast.skillManaCost:
			feedback(skillPlayer.resource_name + " insuficiente")
			return
		if skillPlayer.charCurrentLife > 0 and not player_cast_bar.is_casting and skillPlayer.charCurrentMana >= skillCast.skillManaCost:
			get_tree().current_scene.get_node("CombatPreview").begin(skillCast, self)
		return
	if validateCast():
		pending = true
		skillHander.loadSkillScene.rpc_id(1, skillCast.skillScenePath, int(skillPlayer.name), target_id)

func validateCast() -> bool:
	if skillPlayer.charCurrentLife <= 0 or player_cast_bar.is_casting:
		return false
	if skillPlayer.charCurrentMana < skillCast.skillManaCost:
		feedback(skillPlayer.resource_name + " insuficiente")
		return false
	var selected = skillPlayer.charCurrentTarget
	if skillCast.targeting() == Skill.TargetMode.ALLY and (Input.is_key_pressed(KEY_ALT) or not is_instance_valid(selected) or selected.charTeam != skillPlayer.charTeam):
		selected = skillPlayer
	target_id = int(selected.name) if is_instance_valid(selected) else 0
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
	timer.start(maxf(0.01, cooldown))
	# Keep hover/tooltips active; _on_pressed rejects requests while the timer runs.
	disabled = false
	set_process(true)
	if duration > 0:
		skillHander.castBar(skillCast.skillName, duration)

func _on_timer_timeout() -> void:
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
		if skillHander.combat_reset.is_connected(_on_timer_timeout):
			skillHander.combat_reset.disconnect(_on_timer_timeout)
