class_name PiercingArrow
extends Node2D

var source: Character
var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var excluded_id := 0
var power := 0
var travelled := 0.0
var hit_ids: Array[int] = []

func _ready() -> void:
	global_position = origin
	z_index = 3
	CombatFeedback.show_skill_effect(&"pierce", origin + direction * 90, source, 180, direction.angle())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.charCurrentLife <= 0 or source.get_tree().current_scene.get_node("SkillHandler").encounter_finished():
		queue_free()
		return
	var previous = global_position
	var step = minf(180 - travelled, 850 * delta)
	global_position += direction * step
	travelled += step
	var targets = MasteryEffects.enemies_near(source, previous, step + 24)
	for target in targets:
		var id = int(target.name)
		if id == excluded_id or hit_ids.has(id):
			continue
		var along = (target.global_position - origin).dot(direction)
		if along < 0 or along > 180:
			continue
		var nearest = Geometry2D.get_closest_point_to_segment(target.global_position, previous, global_position)
		if target.global_position.distance_to(nearest) <= 22:
			hit_ids.append(id)
			target.deal_damage(power, source)
			CombatFeedback.show_skill_effect(&"slash", target.global_position, source, 66, direction.angle())
			if hit_ids.size() >= 2:
				break
	if travelled >= 180 or hit_ids.size() >= 2:
		queue_free()
