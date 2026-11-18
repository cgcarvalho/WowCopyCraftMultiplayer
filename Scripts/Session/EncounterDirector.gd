class_name EncounterDirector
extends Node2D

const MODES = {"boss": "Jefferson", "expedition": "Ondas e Jefferson", "reinforcements": "Jefferson com reforços"}
var phase = "idle"
var wave_index = 0
var pause_remaining = 0.0
var participants = 1
var next_enemy_id = -100
var reinforced: Array[int] = []
var spawner: MultiplayerSpawner
@onready var main = get_parent()
@onready var session = main.get_node("Session")
@onready var encounter = main.get_node("BossEncounter")

func _ready() -> void:
	var units = Node2D.new()
	units.name = "Enemies"
	add_child(units)
	spawner = MultiplayerSpawner.new()
	spawner.name = "EnemySpawner"
	spawner.spawn_path = NodePath("../Enemies")
	spawner.spawn_function = create_enemy
	add_child(spawner)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "DirectorSynchronizer"
	var config = SceneReplicationConfig.new()
	for property in ["phase", "wave_index", "pause_remaining", "participants"]:
		var path = NodePath(".:" + property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	add_child(sync)

func create_enemy(data: Dictionary) -> Node:
	if not LesserEnemy.STATS.has(str(data.get("kind", ""))) or int(data.get("id", 0)) > -100:
		return null
	var enemy = LesserEnemy.new()
	enemy.name = str(int(data.id))
	enemy.enemy_kind = str(data.kind)
	enemy.life_scale = float(data.get("scale", 1))
	enemy.position = Vector2(data.point)
	return enemy

func living_enemies() -> Array[LesserEnemy]:
	var result: Array[LesserEnemy] = []
	for child in $Enemies.get_children():
		if child is LesserEnemy and child.charCurrentLife > 0:
			result.append(child)
	return result

func spawn_enemy(kind: String, point: Vector2) -> LesserEnemy:
	if not multiplayer.is_server():
		return null
	var id = next_enemy_id
	next_enemy_id -= 1
	return spawner.spawn({"id": id, "kind": kind, "scale": 1.0 + 0.15 * (participants - 1), "point": ArenaNavigation.constrain(point)}) as LesserEnemy

func spawn_pack(kinds: Array) -> void:
	for index in kinds.size():
		var angle = TAU * index / maxi(1, kinds.size())
		var point = Vector2(940, 390) + Vector2.from_angle(angle) * 138
		spawn_enemy(str(kinds[index]), point)

func mixed_pack() -> Array:
	match participants:
		1: return ["acolyte", "hound"]
		2: return ["acolyte", "guard", "hound"]
		3: return ["acolyte", "guard", "hound", "hound"]
		_: return ["acolyte", "guard", "hound", "hound", "acolyte"]

func begin() -> void:
	clear_units()
	participants = maxi(1, encounter.living_players().size())
	reinforced.clear()
	wave_index = 0
	pause_remaining = 0
	if session.encounter_mode == "expedition":
		phase = "waves"
		wave_index = 1
		encounter.status = "prelude"
		encounter.boss.spectator = true
		spawn_pack(["acolyte"])
	else:
		begin_boss()

func begin_boss() -> void:
	phase = "boss"
	encounter.boss.spectator = false
	encounter.status = "active"

func clear_units() -> void:
	if multiplayer.is_server():
		for child in $Enemies.get_children():
			$Enemies.remove_child(child)
			child.queue_free()

func reset() -> void:
	clear_units()
	phase = "idle"
	wave_index = 0
	pause_remaining = 0
	reinforced.clear()
	encounter.boss.spectator = false

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not session.running:
		return
	if session.stage != "active":
		if phase != "idle" and session.stage in ["lobby", "victory", "defeat"]:
			reset()
		return
	if phase == "waves":
		if encounter.living_players().is_empty():
			session.finished("defeat")
			encounter.status = "defeat"
			reset()
		elif living_enemies().is_empty():
			phase = "rest"
			pause_remaining = 2.0 if wave_index == 1 else 6.0
			encounter.clear_effects()
	elif phase == "rest":
		pause_remaining = maxf(0, pause_remaining - delta)
		if pause_remaining == 0:
			if wave_index == 1:
				wave_index = 2
				phase = "waves"
				spawn_pack(mixed_pack())
			else:
				session.restore_for_boss.rpc()
				begin_boss()
	elif phase == "boss" and session.encounter_mode == "reinforcements":
		for threshold in [75, 35]:
			if reinforced.has(threshold) or encounter.boss.charCurrentLife > encounter.boss.charTotalLife * threshold / 100.0:
				continue
			if encounter.has_runic_conductors() or (encounter.danger_visible and encounter.spell_kind in ["bond", "spread", "channel"]):
				continue
			var limit = mini(3, participants)
			if living_enemies().size() >= limit:
				continue
			reinforced.append(threshold)
			var pack = ["hound", "acolyte", "guard"]
			for index in mini(limit - living_enemies().size(), 3):
				spawn_enemy(pack[index], Vector2(1120, 255 + index * 100))
			break

func caption() -> String:
	if phase == "waves":
		return "Onda %d/2 · %d inimigos" % [wave_index, living_enemies().size()]
	if phase == "rest":
		return ("Jefferson em " if wave_index == 2 else "Próxima onda em ") + "%.1fs" % pause_remaining
	return ""
