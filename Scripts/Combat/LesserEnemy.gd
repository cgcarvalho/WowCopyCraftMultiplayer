class_name LesserEnemy
extends Character

const STATS = {
	"acolyte": {"name": "Acólito do Vazio", "life": 50, "speed": 105.0},
	"guard": {"name": "Guarda Rúnico", "life": 80, "speed": 100.0},
	"hound": {"name": "Sabueso Arcano", "life": 35, "speed": 255.0}
}
var enemy_kind = "acolyte"
var velocity := Vector2.ZERO
var target_id = 0
var cast_remaining = 0.0
var cast_total = 0.0
var cast_point := Vector2.ZERO
var cast_origin := Vector2.ZERO
var attack_remaining = 1.0
var shield_remaining = 0.0
var target_hold = 0.0
var born_remaining = 1.2
var life_scale = 1.0
var action_time = 0.0
var death_time = 0.0
var reaction_remaining = 0.0
var protected_id = 0
var protection_remaining = 0.0
var sprite: AnimatedSprite2D
var arena_main: Node

func _enter_tree() -> void:
	charTeam = Teams.RED
	charClass = "Enemy"
	charName = STATS[enemy_kind].name
	charTotalLife = roundi(int(STATS[enemy_kind].life) * life_scale)
	charCurrentLife = charTotalLife
	spectator = true
	super._enter_tree()

func _ready() -> void:
	arena_main = get_tree().current_scene
	z_index = Constants.PLAYER_Z_INDEX
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	var file = "res://Art/Enemies/Ludo/EnemyClips.tres"
	if ResourceLoader.exists(file):
		sprite.sprite_frames = load(file)
		var clip = enemy_kind + "_idle"
		sprite.play(clip)
		portrait_icon = sprite.sprite_frames.get_frame_texture(clip, 0)
		sprite.position.y = -106
	add_child(sprite)
	var selection = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(86, 85) if enemy_kind == "hound" else Vector2(68, 126)
	selection.shape = shape
	selection.position.y = -35 if enemy_kind == "hound" else -58
	add_child(selection)
	MultiplayerManager.enemies[int(name)] = self
	var sync = MultiplayerSynchronizer.new()
	sync.name = "EnemySynchronizer"
	sync.set_multiplayer_authority(1)
	var config = SceneReplicationConfig.new()
	for property in ["position", "velocity", "target_id", "cast_remaining", "cast_total", "cast_point", "cast_origin", "born_remaining", "action_time", "protected_id", "protection_remaining"]:
		var path = NodePath(".:" + property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	add_child(sync)

func living_players() -> Array[Character]:
	var players: Array[Character] = []
	for player in MultiplayerManager.playerList.values():
		if is_instance_valid(player) and player.charCurrentLife > 0 and not player.spectator:
			players.append(player)
	return players

func select_victim() -> Character:
	var previous = MultiplayerManager.get_character(target_id)
	if target_hold > 0 and is_instance_valid(previous) and previous.charCurrentLife > 0 and not previous.spectator:
		return previous
	var players = living_players()
	players.sort_custom(func(a, b):
		var first = a.global_position.distance_squared_to(global_position)
		var second = b.global_position.distance_squared_to(global_position)
		if is_equal_approx(first, second):
			return int(a.name) < int(b.name)
		return first > second if enemy_kind == "hound" else first < second)
	var result: Character = players[0] if not players.is_empty() else null
	target_id = int(result.name) if result else 0
	target_hold = 4.0 if enemy_kind == "hound" else 1.5
	return result

func interrupt_cast(caster: Character) -> bool:
	if not multiplayer.is_server() or enemy_kind != "acolyte" or cast_remaining <= 0 or charCurrentLife <= 0 or born_remaining > 0:
		return false
	cast_remaining = 0
	attack_remaining = 1.5
	action_time = 0
	var report = caster.battle_report()
	if report:
		report.add(int(caster.name), "interrupts", 1)
	CombatFeedback.show_skill_effect(&"interrupt", global_position, caster, 95)
	return true

func start_cast(target: Character) -> void:
	cast_total = 2.0 if enemy_kind == "acolyte" else 0.8
	cast_remaining = cast_total
	cast_origin = global_position
	cast_point = target.global_position
	if enemy_kind == "hound":
		cast_point = cast_origin + (cast_point - cast_origin).limit_length(180)
	action_time = cast_total + 0.35

func finish_cast() -> void:
	var victims = living_players()
	if enemy_kind == "acolyte":
		for player in victims:
			if player.global_position.distance_to(cast_point) <= 60:
				player.deal_damage(10, self)
		CombatFeedback.show_skill_effect(&"reap", cast_point, self, 124)
		attack_remaining = 6.0
	else:
		var destination = ArenaNavigation.move(cast_origin, cast_point - cast_origin)
		global_position = destination
		for player in victims:
			var nearest = Geometry2D.get_closest_point_to_segment(player.global_position, cast_origin, destination)
			if player.global_position.distance_to(nearest) <= 24:
				player.deal_damage(8, self)
		CombatFeedback.show_skill_effect(&"slash", destination, self, 85, (destination - cast_origin).angle())
		attack_remaining = 6.0
		action_time = 1.0

func protect_ally() -> void:
	if protected_id != 0:
		var previous = MultiplayerManager.get_character(protected_id)
		if is_instance_valid(previous):
			previous.remove_sourced_shield(int(name), "runic_guard")
	protected_id = 0
	var allies = MultiplayerManager.enemies.values()
	allies.sort_custom(func(a, b): return int(a.name) < int(b.name))
	for ally in allies:
		if ally is LesserEnemy and ally != self and ally.enemy_kind != "guard" and ally.charCurrentLife > 0 and not ally.spectator and global_position.distance_to(ally.global_position) <= 200:
			protected_id = int(ally.name)
			ally.upsert_shield(20, self, 4, "runic_guard")
			protection_remaining = 4.0
			shield_remaining = 4.0
			action_time = 0.65
			break

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if charCurrentLife <= 0:
		return
	expire_shields()
	protection_remaining = maxf(0, protection_remaining - delta)
	if protection_remaining == 0 and protected_id != 0:
		var protected = MultiplayerManager.get_character(protected_id)
		if is_instance_valid(protected):
			protected.remove_sourced_shield(int(name), "runic_guard")
		protected_id = 0
	born_remaining = maxf(0, born_remaining - delta)
	spectator = born_remaining > 0
	if spectator:
		return
	if arena_main.get_node("Session").stage != "active":
		return
	action_time = maxf(0, action_time - delta)
	target_hold = maxf(0, target_hold - delta)
	attack_remaining = maxf(0, attack_remaining - delta)
	if cast_remaining > 0:
		velocity = Vector2.ZERO
		cast_remaining = maxf(0, cast_remaining - delta)
		if cast_remaining == 0:
			finish_cast()
		return
	var target = select_victim()
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	if enemy_kind == "guard":
		shield_remaining -= delta
		if shield_remaining <= 0:
			protect_ally()
			shield_remaining = 8.0
		if global_position.distance_to(target.global_position) <= 84 and attack_remaining <= 0:
			target.deal_damage(6, self)
			attack_remaining = 1.8
			action_time = 0.55
	elif attack_remaining <= 0 and global_position.distance_to(target.global_position) <= (550 if enemy_kind == "acolyte" else 220):
		start_cast(target)
		return
	if enemy_kind == "hound" and action_time > 0:
		velocity = Vector2.ZERO
		return
	var preferred = 360 if enemy_kind == "acolyte" else 65
	var difference = target.global_position - global_position
	var desired = difference.normalized() * float(STATS[enemy_kind].speed) if difference.length() > preferred else Vector2.ZERO
	for obstacle in ArenaNavigation.obstacles():
		if (global_position + desired.normalized() * 95).distance_to(obstacle) < 125:
			var away = global_position - obstacle
			desired += away.normalized() * 140 + away.normalized().orthogonal() * 95
	velocity = velocity.move_toward(desired.limit_length(float(STATS[enemy_kind].speed)), delta * 650)
	global_position = ArenaNavigation.move(global_position, velocity * delta)

func _process(delta: float) -> void:
	flash_time = maxf(0, flash_time - delta)
	reaction_remaining = maxf(0, reaction_remaining - delta)
	if flash_time > 0:
		reaction_remaining = 0.25
	input_pickable = charCurrentLife > 0 and born_remaining <= 0
	if charCurrentLife <= 0:
		MultiplayerManager.enemies.erase(int(name))
		death_time += delta
		if multiplayer.is_server() and death_time > 0.85:
			queue_free()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(enemy_kind + "_idle"):
		var clip = "idle"
		if charCurrentLife <= 0:
			clip = "death"
		elif reaction_remaining > 0:
			clip = "hit"
		elif enemy_kind == "guard" and action_time > 0 and protection_remaining > 3.3:
			clip = "protect"
		elif cast_remaining > 0 or action_time > 0:
			clip = "action"
		elif velocity.length() > 8:
			clip = "walk"
		sprite.play(enemy_kind + "_" + clip)
		if clip in ["action", "protect"]:
			var progress = 0.0
			if clip == "protect":
				progress = 1.0 - action_time / 0.65
			elif enemy_kind == "guard":
				progress = 1.0 - action_time / 0.55
			elif cast_remaining > 0:
				var preparation = 0.7 if enemy_kind == "acolyte" else 0.55
				progress = preparation * (1.0 - cast_remaining / maxf(0.01, cast_total))
			else:
				progress = 0.7 + 0.3 * (1.0 - action_time / 0.35) if enemy_kind == "acolyte" else 0.55 + 0.45 * (1.0 - action_time)
			var frames = sprite.sprite_frames.get_frame_count(enemy_kind + "_" + clip)
			var frame_position = clampf(progress, 0.0, 0.999) * frames
			sprite.set_frame_and_progress(int(frame_position), fposmod(frame_position, 1.0))
			sprite.pause()
		if velocity.length() > 4:
			sprite.flip_h = velocity.x < 0
		if cast_remaining > 0:
			sprite.flip_h = cast_point.x < global_position.x
		sprite.modulate = flash_color if flash_time > 0 else Color.WHITE
		modulate.a = clampf(1.0 - death_time, 0, 1) if death_time > 0 else clampf(1.2 - born_remaining, 0.25, 1)
	queue_redraw()

func _draw() -> void:
	if born_remaining > 0:
		SkillFX.rim(self, Vector2.ZERO, 40, Color(0.83, 0.65, 1, 0.7), 4, born_remaining)
	if charCurrentLife <= 0:
		return
	var bar_y = -94 if enemy_kind == "hound" else -142
	draw_rect(Rect2(-30, bar_y, 60, 6), Color("201b28"))
	draw_rect(Rect2(-28, bar_y + 2, 56 * float(charCurrentLife) / charTotalLife, 3), Color("cf89e7"))
	if charShield > 0:
		draw_arc(Vector2(0, -37), 44, 0, TAU, 32, Color("a9d9ff"), 2, true)
	if not sprite.sprite_frames:
		draw_circle(Vector2(0, -35), 25, Color("9167ba"))
	if cast_remaining > 0:
		var fraction = 1 - cast_remaining / maxf(0.01, cast_total)
		if enemy_kind == "acolyte":
			var point = to_local(cast_point)
			draw_circle(point, 60, Color(0.7, 0.16, 0.6, 0.11))
			SkillFX.rim(self, point, 60, Color("f4a8ea"), 4)
			draw_arc(point, 54, -PI / 2, -PI / 2 + fraction * TAU, 40, Color("ffe9b6"), 3, true)
		else:
			var start = to_local(cast_origin)
			var end = to_local(cast_point)
			draw_line(start, end, Color(0.82, 0.61, 1, 0.30), 48, true)
			draw_line(start, end, Color("ead0ff"), 2, true)
			SkillFX.arrow(self, end - (end - start).normalized() * 12, (end - start).normalized(), Color("ead0ff"))
		draw_rect(Rect2(-30, bar_y + 11, 60 * fraction, 4), Color("f5d48a"))
	if protected_id != 0:
		var ally = MultiplayerManager.get_character(protected_id)
		if is_instance_valid(ally) and ally.charCurrentLife > 0 and ally.charShield > 0 and protection_remaining > 0:
			draw_line(Vector2(0, -35), to_local(ally.global_position) + Vector2(0, -35), Color(0.68, 0.82, 1, 0.75), 2.5, true)

func release_protection() -> void:
	for enemy in MultiplayerManager.enemies.values():
		if is_instance_valid(enemy):
			enemy.remove_sourced_shield(int(name), "runic_guard")

func deal_damage(damage: int, source: Character = null, periodic: bool = false, skill_multiplier: float = 1.0) -> void:
	var before = charCurrentLife
	super.deal_damage(damage, source, periodic, skill_multiplier)
	if before > 0 and charCurrentLife <= 0:
		cast_remaining = 0
		velocity = Vector2.ZERO
		release_protection()

func _exit_tree() -> void:
	if multiplayer.is_server():
		release_protection()
	if MultiplayerManager.enemies.get(int(name)) == self:
		MultiplayerManager.enemies.erase(int(name))
