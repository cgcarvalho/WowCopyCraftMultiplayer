extends State
class_name Attack

var elapsed = 0.0
var released = false

func enter() -> void:
	state_machine.animatedSprite.play("auto_attack")
	state_machine.animatedSprite.frame = 0

func physics_process(delta: float) -> void:
	var player = state_machine.statePlayer
	var target = player.charCurrentTarget
	if not is_instance_valid(target) or target.charCurrentLife <= 0 or target.spectator or target.charTeam == player.charTeam:
		state_machine.set_state(Idle.new())
		return
	if player.global_position.distance_to(target.global_position) > player.charRange:
		state_machine.set_state(Idle.new())
		return
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0:
		state_machine.set_state(Walk.new())
		return
	if player.ability_animation_time > 0:
		state_machine.set_state(Idle.new())
		return
	var preview = state_machine.mainScene.get_node("CombatPreview")
	if preview.aiming or preview.suppress_attack:
		state_machine.set_state(Idle.new())
		return
	elapsed += delta
	if not released and elapsed >= player.attack_interval * 0.35:
		state_machine.mainScene.get_node("SkillHandler").basic_attack.rpc_id(1, int(player.name), int(target.name))
		released = true
	if elapsed >= player.attack_interval:
		elapsed = 0.0
		released = false

func exit() -> void:
	state_machine.animatedSprite.stop()
