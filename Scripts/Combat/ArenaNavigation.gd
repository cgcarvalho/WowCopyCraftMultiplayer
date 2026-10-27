class_name ArenaNavigation
extends RefCounted

const WORLD_SIZE = Vector2(1536, 864)
const BOUNDS = Rect2(50, 145, 1400, 500)
const BOSS_BOUNDS = Rect2(130, 125, 1240, 540)
const TRUNKS = [Vector2(850, 185), Vector2(850, 475)]
const COLLISION_RADIUS = 76.0

static func allowed(point: Vector2) -> bool:
	if not point.is_finite() or not BOUNDS.has_point(point):
		return false
	for center in TRUNKS:
		if point.distance_to(center) < COLLISION_RADIUS - 0.1:
			return false
	return true

static func constrain(point: Vector2) -> Vector2:
	var result = point.clamp(BOUNDS.position, BOUNDS.end - Vector2.ONE)
	for center in TRUNKS:
		var offset = result - center
		if offset.length() < COLLISION_RADIUS:
			var direction = offset.normalized() if offset.length() > 0.1 else Vector2.LEFT
			result = center + direction * COLLISION_RADIUS
			result = result.clamp(BOUNDS.position, BOUNDS.end - Vector2.ONE)
			if result.distance_to(center) < COLLISION_RADIUS - 0.1:
				result = center + Vector2.LEFT * COLLISION_RADIUS
	return result

static func move(start: Vector2, displacement: Vector2) -> Vector2:
	# Small swept steps prevent fast charges from crossing tree trunks.
	var point = constrain(start)
	var steps = maxi(1, ceili(displacement.length() / 10.0))
	var step = displacement / steps
	for index in steps:
		point = constrain(point + step)
	return point
