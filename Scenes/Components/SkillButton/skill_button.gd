extends TextureButton

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var timer: Timer = $Timer
@onready var time: Label = $Time
@onready var key: Label = $Key

var skillCast : Skill
var skillPlayer : Character
var skillHander
var selfCast = false

var changeKey = "":
	set(value):
		changeKey = value
		key.text = value
		
		shortcut = Shortcut.new()
		var input_key = InputEventKey.new()
		input_key.keycode = value.unicode_at(0)
		
		var input_keyAuto = InputEventKey.new()
		input_keyAuto.keycode = value.unicode_at(0)
		input_keyAuto.alt_pressed = true
		shortcut.events = [input_key, input_keyAuto]

func _ready() -> void:
	skillHander = get_tree().current_scene.get_node("SkillHandler")
	changeKey = "1"
	progress_bar.max_value = timer.wait_time
	set_process(false)
	
	
func _process(_delta: float) -> void:
	time.text = "%3.1f" % timer.time_left
	progress_bar.value = timer.time_left
	

func _on_pressed() -> void:
	selfCast = Input.is_key_pressed(KEY_ALT)
		
	if validateCast():
		timer.start()
		disabled = true
		set_process(true)
		castSkill()
	
	
func _on_timer_timeout() -> void:
	disabled = false
	time.text = ""
	set_process(false)

func castSkill() -> void:
	var path = skillCast.skillScenePath
	var idPlayer = int(skillPlayer.name)
	var idTarget = int(skillPlayer.charCurrentTarget.name) if skillPlayer.charCurrentTarget else 0

	if selfCast:
		skillHander.loadSkillScene.rpc(path, idPlayer, idPlayer)
	else:
		skillHander.loadSkillScene.rpc(path, idPlayer, idTarget)

func validateCast() -> bool:
	if skillCast is AreaDamage:
		return skillPlayer.charCurrentMana >= skillCast.skillManaCost
	
	var idTarget = int(skillPlayer.charCurrentTarget.name) if skillPlayer.charCurrentTarget else 0
	
	
	return (idTarget > 0 or selfCast) and skillPlayer.charCurrentMana >= skillCast.skillManaCost
	
