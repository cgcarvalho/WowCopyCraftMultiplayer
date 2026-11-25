class_name DualBasicAttack
extends Node

var caster: Character
var target: Character
var power = 5
var elapsed = 0.0
var round_token = 0
var handler: Node
var first_landed = false
var resolved = false

func _ready() -> void:
	handler = get_parent().get_node("SkillHandler")
	round_token = handler.round_token
	first_landed = strike(false)

func valid_strike() -> bool:
	if not multiplayer.is_server() or not is_instance_valid(caster) or not is_instance_valid(target):
		return false
	if caster.is_queued_for_deletion() or target.is_queued_for_deletion() or MultiplayerManager.playerList.get(int(caster.name)) != caster:
		return false
	return caster.charCurrentLife > 0 and target.charCurrentLife > 0 and not caster.spectator and not target.spectator and caster.charTeam != target.charTeam and caster.global_position.distance_to(target.global_position) <= caster.charRange and not handler.encounter_finished() and round_token == handler.round_token

func strike(second_hand: bool) -> bool:
	if not valid_strike():
		return false
	var before = target.charCurrentLife + target.charShield
	target.deal_damage(power, caster)
	if before <= target.charCurrentLife + target.charShield:
		return false
	caster.dual_basic_hit(second_hand)
	CombatFeedback.show_skill_effect(&"slash", target.global_position, caster, 86, 0.65 if second_hand else -0.65)
	return true

func _physics_process(delta: float) -> void:
	if resolved:
		return
	elapsed += delta
	if not first_landed or elapsed >= 0.18:
		resolved = true
		if first_landed:
			strike(true)
		queue_free()
