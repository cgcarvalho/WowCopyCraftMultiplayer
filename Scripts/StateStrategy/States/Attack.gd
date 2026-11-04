extends State
class_name Attack

var elapsed = 0.0
var released = false

func enter() -> void:
	state_machine.animatedSprite.play("walk" if moving() else "auto_attack")
	state_machine.animatedSprite.frame = 0

func moving() -> bool:
	return not Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx()

func stop_attack() -> void:
	state_machine.set_state(Walk.new() if moving() else Idle.new())

func physics_process(delta: float) -> void:
	var player = state_machine.statePlayer
	# Walking and the attack clock advance together, once per physics tick.
	StateHelper.canMove(delta, state_machine, false)
	var target = player.charCurrentTarget
	if not is_instance_valid(target) or target.charCurrentLife <= 0 or target.spectator or target.charTeam == player.charTeam:
		stop_attack()
		return
	if player.global_position.distance_to(target.global_position) > player.charRange:
		stop_attack()
		return
	if player.ability_animation_time > 0:
		stop_attack()
		return
	var preview = state_machine.mainScene.get_node("CombatPreview")
	if preview.aiming or preview.suppress_attack:
		stop_attack()
		return
	state_machine.animatedSprite.play("walk" if moving() and player.basic_animation_remaining <= 0 else "auto_attack")
	elapsed += delta
	if not released and elapsed >= player.attack_interval * 0.35:
		state_machine.mainScene.get_node("SkillHandler").basic_attack.rpc_id(1, int(player.name), int(target.name))
		released = true
	if elapsed >= player.attack_interval:
		elapsed = 0.0
		released = false

func exit() -> void:
	state_machine.animatedSprite.stop()
