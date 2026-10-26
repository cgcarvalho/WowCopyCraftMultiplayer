extends Node2D

const AREA_INTERVAL = 6.0
const AREA_WARNING = 2.0
const AREA_RADIUS = 115.0
const AREA_DAMAGE = 25
const LANCE_LENGTH = 700.0
const LANCE_RADIUS = 32.0
const LANCE_DAMAGE = 22
const ORB_SPEED = 260.0
const ORB_DAMAGE = 12
const ORB_RADIUS = 22.0
const SPELL_NAMES = {"rupture": "Ruptura Sombria", "volley": "Orbes do Vazio", "lance": "Lança Arcana", "blink": "Passo Astral", "ward": "Égide Rúnica"}
const SPELL_TIPS = {"rupture": "Saia do círculo", "volley": "Desvie dos orbes", "lance": "Saia da faixa azul", "blink": "Reposicionamento astral", "ward": "Jefferson está criando um escudo"}
const WARNINGS = {"rupture": 2.0, "volley": 1.0, "lance": 1.6, "blink": 1.1, "ward": 1.3}
@export var status = "waiting"
@export var danger_visible = false
@export var danger_position = Vector2.ZERO
@export var danger_remaining = 0.0
@export var spell_kind = "rupture"
@export var danger_origin = Vector2.ZERO
@export var danger_direction = Vector2.RIGHT
@export var phase = 1
@export var visual_kind = ""
@export var visual_origin = Vector2.ZERO
@export var visual_position = Vector2.ZERO
@export var visual_direction = Vector2.RIGHT
@export var visual_remaining = 0.0
@export var projectiles: Array = []
@onready var boss: Jefferson = $"-1"
var area_cooldown = AREA_INTERVAL
var opening_delay = 3.0
var health_bar: ProgressBar
var message: Label
var previous_status = "waiting"
var spell_cooldowns: Dictionary = {}
var last_spell = ""
var ward_used = false
var projectile_id = 0

func _ready() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(410, 20)
	health_bar.size = Vector2(340, 26)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(health_bar)
	message = Label.new()
	message.position = Vector2(410, 50)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_shadow_color", Color.BLACK)
	message.add_theme_constant_override("shadow_offset_x", 2)
	message.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(message)

func living_players() -> Array[Character]:
	var result: Array[Character] = []
	for player in MultiplayerManager.playerList.values():
		if is_instance_valid(player) and player.charCurrentLife > 0:
			result.append(player)
	return result

func ready_spell(kind: String) -> bool:
	return float(spell_cooldowns.get(kind, 0)) <= 0

func select_spell() -> String:
	var players = living_players()
	var target = boss.choose_target()
	if not is_instance_valid(target):
		return ""
	if phase == 2 and not ward_used:
		return "ward"
	var close_players = 0
	for player in players:
		if player.global_position.distance_to(boss.global_position) < 170:
			close_players += 1
	if close_players > 0 and ready_spell("blink") and last_spell != "blink":
		return "blink"
	if last_spell == "":
		return "rupture"
	# Punish tightly grouped players with a marked, dodgeable ground eruption.
	for player in players:
		var cluster = 0
		for other in players:
			if player.global_position.distance_to(other.global_position) < AREA_RADIUS:
				cluster += 1
		if cluster >= 2 and ready_spell("rupture") and last_spell != "rupture":
			return "rupture"
	var distance = boss.global_position.distance_to(target.global_position)
	if distance > 340 and ready_spell("lance") and last_spell != "lance":
		return "lance"
	for kind in ["volley", "lance", "rupture"]:
		if ready_spell(kind) and kind != last_spell:
			return kind
	return ""

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if status == "waiting":
		if not living_players().is_empty():
			status = "active"
		return
	if status != "active":
		return
	if boss.charCurrentLife <= 0:
		finish("victory")
		return
	if living_players().is_empty():
		finish("defeat")
		return
	phase = 2 if boss.charCurrentLife <= boss.charTotalLife / 2 else 1
	visual_remaining = maxf(0, visual_remaining - delta)
	for kind in spell_cooldowns:
		spell_cooldowns[kind] = maxf(0, float(spell_cooldowns[kind]) - delta)
	update_projectiles(delta)
	if opening_delay > 0:
		opening_delay -= delta
		return
	if danger_visible:
		danger_remaining = maxf(0.0, danger_remaining - delta)
		if danger_remaining <= 0:
			resolve_area()
	else:
		area_cooldown -= delta
		if area_cooldown <= 0:
			var selected = select_spell()
			if not selected.is_empty():
				begin_spell(selected)

func begin_area() -> void:
	begin_spell("rupture")

func begin_spell(kind: String) -> void:
	if not multiplayer.is_server() or status != "active" or boss.charCurrentLife <= 0 or danger_visible or not WARNINGS.has(kind):
		return
	var target = boss.choose_target()
	if not is_instance_valid(target):
		return
	spell_kind = kind
	danger_origin = boss.global_position
	danger_position = target.global_position
	if kind == "rupture":
		var largest = 0
		for player in living_players():
			var count = 0
			for other in living_players():
				if player.global_position.distance_to(other.global_position) < AREA_RADIUS:
					count += 1
			if count > largest:
				largest = count
				danger_position = player.global_position
	elif kind == "blink":
		danger_position = boss.blink_destination(target)
	elif kind == "ward":
		danger_position = boss.global_position
	elif kind == "volley":
		danger_position = boss.predict_target(target)
	# All offensive aim is locked at the start of the warning; it never tracks a dodging player.
	danger_direction = (danger_position - danger_origin).normalized()
	if danger_direction.length_squared() < 0.1:
		danger_direction = Vector2.RIGHT
	danger_remaining = WARNINGS[kind]
	danger_visible = true

func resolve_area() -> void:
	if not multiplayer.is_server() or status != "active" or not danger_visible:
		return
	if boss.charCurrentLife > 0:
		match spell_kind:
			"rupture":
				for player in living_players():
					if player.global_position.distance_to(danger_position) <= AREA_RADIUS:
						player.deal_damage(AREA_DAMAGE, boss)
			"lance":
				var end = danger_origin + danger_direction * LANCE_LENGTH
				for player in living_players():
					var nearest = Geometry2D.get_closest_point_to_segment(player.global_position, danger_origin, end)
					if player.global_position.distance_to(nearest) <= LANCE_RADIUS:
						player.deal_damage(LANCE_DAMAGE, boss)
			"volley":
				spawn_volley()
			"blink":
				boss.global_position = danger_position
				boss.velocity = Vector2.ZERO
			"ward":
				boss.apply_shield(50)
				ward_used = true
	visual_kind = spell_kind
	visual_origin = danger_origin
	visual_position = danger_position
	visual_direction = danger_direction
	visual_remaining = 0.65
	last_spell = spell_kind
	spell_cooldowns[spell_kind] = {"rupture": 8.0, "volley": 7.0, "lance": 10.0, "blink": 14.0, "ward": 9999.0}[spell_kind]
	danger_visible = false
	danger_remaining = 0
	area_cooldown = AREA_INTERVAL if phase == 1 else AREA_INTERVAL * 0.7

func spawn_volley() -> void:
	var angles = [-0.28, 0.0, 0.28] if phase == 1 else [-0.44, -0.22, 0.0, 0.22, 0.44]
	for angle in angles:
		projectile_id += 1
		var direction = danger_direction.rotated(angle)
		projectiles.append({"id": projectile_id, "position": danger_origin + direction * 75, "velocity": direction * ORB_SPEED, "life": 4.0})

func update_projectiles(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var remaining: Array = []
	for projectile in projectiles:
		var start: Vector2 = projectile["position"]
		var end: Vector2 = start + projectile["velocity"] * delta
		var hit = false
		for player in living_players():
			var nearest = Geometry2D.get_closest_point_to_segment(player.global_position, start, end)
			if player.global_position.distance_to(nearest) <= ORB_RADIUS:
				player.deal_damage(ORB_DAMAGE, boss)
				hit = true
				break
		var life: float = projectile["life"] - delta
		if not hit and life > 0:
			var moved: Dictionary = projectile.duplicate()
			moved["position"] = end
			moved["life"] = life
			remaining.append(moved)
	projectiles = remaining

func finish(result: String) -> void:
	if not multiplayer.is_server() or status != "active":
		return
	status = result
	danger_visible = false
	danger_remaining = 0
	projectiles = []
	visual_remaining = 0
	boss.velocity = Vector2.ZERO
	boss.charCurrentTarget = null
	clear_effects()

func clear_effects() -> void:
	for node in get_parent().get_children():
		if node is Skill:
			node.queue_free()
	for player in MultiplayerManager.playerList.values():
		if is_instance_valid(player):
			player.charCurrentTarget = null

func _process(_delta: float) -> void:
	if status != previous_status:
		previous_status = status
		if status in ["victory", "defeat"]:
			clear_effects()
	health_bar.visible = status != "waiting"
	health_bar.max_value = boss.charTotalLife
	health_bar.value = boss.charCurrentLife
	message.visible = status != "waiting"
	var caption = "Jefferson • Fase %d" % phase
	if boss.charShield > 0:
		caption += " • Escudo %d" % boss.charShield
	match status:
		"victory": message.text = "Vitória! Jefferson foi derrotado."
		"defeat": message.text = "Derrota! Todos os jogadores caíram."
		_: message.text = "%s • %.1fs\n%s" % [SPELL_NAMES.get(spell_kind, ""), danger_remaining, SPELL_TIPS.get(spell_kind, "")] if danger_visible else caption
