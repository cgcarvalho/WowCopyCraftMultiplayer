extends Node2D

const AREA_INTERVAL = 6.0
const AREA_WARNING = 2.0
const AREA_RADIUS = 115.0
const AREA_DAMAGE = 25
@export var status = "waiting"
@export var danger_visible = false
@export var danger_position = Vector2.ZERO
@export var danger_remaining = 0.0
@onready var boss: Jefferson = $"-1"
var area_cooldown = AREA_INTERVAL
var opening_delay = 3.0
var health_bar: ProgressBar
var message: Label
var previous_status = "waiting"

func _ready() -> void:
	# UI ignores mouse input so selecting a combat target remains possible.
	var layer = CanvasLayer.new()
	add_child(layer)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(410, 20)
	health_bar.size = Vector2(320, 26)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(health_bar)
	message = Label.new()
	message.position = Vector2(410, 50)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_font_size_override("font_size", 20)
	layer.add_child(message)

func living_players() -> Array[Character]:
	var result: Array[Character] = []
	for player in MultiplayerManager.playerList.values():
		if is_instance_valid(player) and player.charCurrentLife > 0:
			result.append(player)
	return result

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
			begin_area()

func begin_area() -> void:
	if not multiplayer.is_server() or status != "active" or boss.charCurrentLife <= 0:
		return
	var target = boss.choose_target()
	if not is_instance_valid(target):
		return
	# Position is locked when announced: players can move out before detonation.
	danger_position = target.global_position
	danger_remaining = AREA_WARNING
	danger_visible = true

func resolve_area() -> void:
	if not multiplayer.is_server() or status != "active" or not danger_visible:
		return
	if boss.charCurrentLife > 0:
		for player in living_players():
			if player.global_position.distance_to(danger_position) <= AREA_RADIUS:
				player.deal_damage(AREA_DAMAGE)
	danger_visible = false
	danger_remaining = 0
	area_cooldown = AREA_INTERVAL

func finish(result: String) -> void:
	if not multiplayer.is_server() or status != "active":
		return
	status = result
	danger_visible = false
	danger_remaining = 0
	boss.charCurrentTarget = null
	clear_effects()

func clear_effects() -> void:
	# Stop outstanding projectiles and DoTs when the encounter ends.
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
	match status:
		"victory": message.text = "Vitória! Jefferson foi derrotado."
		"defeat": message.text = "Derrota! Todos os jogadores caíram."
		_: message.text = "Saia do círculo! %.1fs" % danger_remaining if danger_visible else "Jefferson Wizard"
	queue_redraw()

func _draw() -> void:
	if not danger_visible or status != "active":
		return
	var center = to_local(danger_position)
	draw_circle(center, AREA_RADIUS, Color(1.0, 0.15, 0.05, 0.3))
	draw_arc(center, AREA_RADIUS, 0, TAU, 64, Color(1, 0.35, 0.1), 4, true)
	var fraction = clampf(1.0 - danger_remaining / AREA_WARNING, 0, 1)
	draw_arc(center, AREA_RADIUS - 8, -PI / 2, -PI / 2 + TAU * fraction, 64, Color.YELLOW, 5, true)
