class_name Jefferson
extends Character

const BOSS_ID = -1
const MAX_HEALTH = 480
const MOVE_SPEED = 130.0
const ACCELERATION = 360.0
const MELEE_RANGE = 130.0
const MELEE_DAMAGE = 8
const MELEE_INTERVAL = 1.6
const ARENA = Rect2(130, 125, 890, 400)
const TREE_CENTERS = [Vector2(850, 185), Vector2(850, 475)]
var attack_cooldown = 0.0
var velocity = Vector2.ZERO
@export var facing_left = false
var threat: Dictionary = {}
var target_hold = 0.0
var movement_time = 0.0
var previous_positions: Dictionary = {}
var player_velocities: Dictionary = {}
var presentation_position = Vector2.ZERO
var visual_ready = false

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Jefferson, o Arcanista"
	charTeam = Teams.RED
	charTotalLife = MAX_HEALTH
	charCurrentLife = MAX_HEALTH
	charBaseDamage = MELEE_DAMAGE
	charCritChance = 0
	portraitImagePath = "res://Art/Chars/Jefferson - The Wizard/Jefferson.png"

func _ready() -> void:
	ui_handler = UIHandler.new(get_parent().get_parent())
	MultiplayerManager.enemies[BOSS_ID] = self
	$AnimatedSprite2D.play("walk")
	var config = SceneReplicationConfig.new()
	for property in ["position", "facing_left", "velocity"]:
		var path = NodePath(".:" + property)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MovementSynchronizer"
	sync.replication_config = config
	add_child(sync)
	presentation_position = global_position

func _exit_tree() -> void:
	if MultiplayerManager.enemies.get(BOSS_ID) == self:
		MultiplayerManager.enemies.erase(BOSS_ID)

func _process(delta: float) -> void:
	visible = get_parent().status != "waiting"
	var dead = charCurrentLife <= 0
	modulate = Color(0.45, 0.45, 0.45, 0.6) if dead else Color.WHITE
	# Only the sprite interpolates. Gameplay and hit detection use server position.
	if not visual_ready or presentation_position.distance_to(global_position) > 180:
		presentation_position = global_position
		visual_ready = true
	presentation_position = presentation_position.lerp(global_position, 1.0 - exp(-18.0 * delta))
	var bob = 0.0 if dead else sin(Time.get_ticks_msec() * 0.003) * 5.0
	$AnimatedSprite2D.position = presentation_position - global_position + Vector2(0, bob)
	$AnimatedSprite2D.flip_h = facing_left
	var pulse = 1.0 + (sin(Time.get_ticks_msec() * 0.008) * 0.025 if get_parent().danger_visible else 0.0)
	$AnimatedSprite2D.scale = Vector2.ONE * 0.30 * pulse
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 90), 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, 68, Color(0.05, 0.01, 0.1, 0.38))
	draw_set_transform(Vector2.ZERO)

func choose_target() -> Character:
	var best: Character
	var best_score = -INF
	for id in MultiplayerManager.playerList:
		var player: Character = MultiplayerManager.playerList[id]
		if not is_instance_valid(player) or player.charCurrentLife <= 0:
			continue
		var distance = global_position.distance_to(player.global_position)
		var score = 600.0 / (distance + 100.0) + float(threat.get(id, 0)) * 0.06
		if player == charCurrentTarget:
			score += 0.6 # Hysteresis prevents flickering between nearby players.
		if score > best_score:
			best = player
			best_score = score
	if target_hold > 0 and is_instance_valid(charCurrentTarget) and charCurrentTarget.charCurrentLife > 0:
		if charCurrentTarget in MultiplayerManager.playerList.values():
			return charCurrentTarget
	return best

func deal_damage(damage: int, source: Character = null) -> void:
	var before = charCurrentLife + charShield
	super.deal_damage(damage, source)
	if multiplayer.is_server() and is_instance_valid(source) and source.charTeam != charTeam:
		var id = int(source.name)
		if MultiplayerManager.playerList.get(id) == source:
			threat[id] = float(threat.get(id, 0)) + maxf(0, before - charCurrentLife - charShield)

func sample_players(delta: float) -> void:
	for id in previous_positions.keys():
		if not MultiplayerManager.playerList.has(id):
			previous_positions.erase(id)
			player_velocities.erase(id)
			threat.erase(id)
	for id in MultiplayerManager.playerList:
		var player: Character = MultiplayerManager.playerList[id]
		if not is_instance_valid(player):
			continue
		var previous: Vector2 = previous_positions.get(id, player.global_position)
		var measured = (player.global_position - previous) / maxf(delta, 0.001)
		player_velocities[id] = measured.limit_length(300)
		previous_positions[id] = player.global_position
		threat[id] = maxf(0, float(threat.get(id, 0)) - delta * 1.5)

func predict_target(player: Character) -> Vector2:
	var estimate: Vector2 = player_velocities.get(int(player.name), Vector2.ZERO)
	return player.global_position + (estimate * 0.35).limit_length(90)

func safe_position(point: Vector2) -> Vector2:
	var result = point.clamp(ARENA.position, ARENA.end)
	for center in TREE_CENTERS:
		var away = result - center
		if away.length() < 118:
			var projected = center + (away.normalized() if away.length() > 0.1 else Vector2.LEFT) * 118
			result = projected.clamp(ARENA.position, ARENA.end)
			if result.distance_to(center) < 117.9:
				# A wall can invalidate a radial push: route around a side instead.
				var left = (center + Vector2.LEFT * 118).clamp(ARENA.position, ARENA.end)
				var right = (center + Vector2.RIGHT * 118).clamp(ARENA.position, ARENA.end)
				result = left if left.distance_to(point) <= right.distance_to(point) else right
	return result.clamp(ARENA.position, ARENA.end)

func blink_destination(target: Character) -> Vector2:
	var away = (global_position - target.global_position).normalized()
	if away.length_squared() < 0.1:
		away = Vector2.LEFT
	var best = safe_position(global_position + away * 300)
	var best_distance = -1.0
	# Check several escape directions and maximize distance from the nearest enemy.
	for angle in [-PI / 2, -PI / 4, 0, PI / 4, PI / 2]:
		var candidate = safe_position(global_position + away.rotated(angle) * 300)
		var nearest = INF
		for player in get_parent().living_players():
			nearest = minf(nearest, candidate.distance_to(player.global_position))
		if nearest > best_distance:
			best_distance = nearest
			best = candidate
	return best

func desired_velocity(target: Character) -> Vector2:
	var difference = target.global_position - global_position
	var distance = difference.length()
	var direction = difference.normalized()
	var phase = get_parent().phase
	var preferred = 260.0 if phase == 1 else 220.0
	var desired = Vector2.ZERO
	if distance > preferred + 55:
		desired = direction
	elif distance < preferred - 55:
		desired = -direction
	else:
		desired = direction.orthogonal() * (1.0 if int(movement_time / 4.0) % 2 == 0 else -1.0) * 0.7
	# Steer around the two map trees; avoid walking through their visible trunks.
	for center in TREE_CENTERS:
		var ahead = global_position + desired * 90
		if ahead.distance_to(center) < 140:
			var outward = (global_position - center).normalized()
			var tangent = outward.orthogonal()
			if tangent.dot(direction) < 0:
				tangent = -tangent
			desired += outward * 1.5 + tangent
	# Keep space between players and avoid lingering in their ground spells.
	for player in get_parent().living_players():
		var away = global_position - player.global_position
		if away.length() < 140 and away.length() > 0.1:
			desired += away.normalized()
	for node in get_parent().get_parent().get_children():
		if node is AreaDamage and is_instance_valid(node.casterCharacter) and node.casterCharacter.charTeam != charTeam:
			var away = global_position - node.global_position
			if away.length() < 180:
				desired += away.normalized() * 1.5 if away.length() > 1 else Vector2.LEFT
	if global_position.x < ARENA.position.x + 15 and desired.x < 0:
		desired.x = -desired.x
	if global_position.x > ARENA.end.x - 15 and desired.x > 0:
		desired.x = -desired.x
	if global_position.y < ARENA.position.y + 15 and desired.y < 0:
		desired.y = -desired.y
	if global_position.y > ARENA.end.y - 15 and desired.y > 0:
		desired.y = -desired.y
	return desired.limit_length(1) * (MOVE_SPEED if phase == 1 else MOVE_SPEED * 1.2)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if get_parent().status != "active" or charCurrentLife <= 0:
		velocity = Vector2.ZERO
		return
	sample_players(delta)
	movement_time += delta
	target_hold = maxf(0, target_hold - delta)
	var selected = choose_target()
	if selected != charCurrentTarget:
		charCurrentTarget = selected
		target_hold = 1.5
	if not is_instance_valid(charCurrentTarget):
		velocity = Vector2.ZERO
		return
	facing_left = charCurrentTarget.global_position.x < global_position.x
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if get_parent().danger_visible:
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(charCurrentTarget.global_position) <= MELEE_RANGE and attack_cooldown <= 0:
		charCurrentTarget.deal_damage(MELEE_DAMAGE, self)
		attack_cooldown = MELEE_INTERVAL
	velocity = velocity.move_toward(desired_velocity(charCurrentTarget), ACCELERATION * delta)
	var next = safe_position(global_position + velocity * delta)
	global_position = next

func die() -> void:
	velocity = Vector2.ZERO
	$AnimatedSprite2D.stop()
