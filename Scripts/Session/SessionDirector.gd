extends Node

const SPAWNS = [Vector2(180, 420), Vector2(180, 250), Vector2(350, 420), Vector2(350, 250)]
const UPGRADE_NAMES = {"offense": "Poder crescente", "endurance": "Vigor renovado", "mastery": "Maestria"}
const UPGRADE_DESCRIPTIONS = {
	"offense": "+12% de dano em ataques e habilidades.",
	"endurance": "+20% da vida base máxima nas próximas tentativas.",
	"mastery": "-12% de recarga (acumula até -55%) e +15% de cura."
}
@export var running = false
@export var stage = "lobby"
@export var roster: Dictionary = {}
@export var upgrades: Dictionary = {}
@export var round_index = 1
@export var countdown = 0.0
@export var revision = 0
@export var transitioning = false
@export var report: Dictionary = {}
var combat_report = BattleReport.new()
@onready var main = get_parent()

func _ready() -> void:
	var config = SceneReplicationConfig.new()
	for property in ["running", "stage", "roster", "upgrades", "round_index", "countdown", "revision", "transitioning"]:
		var path = NodePath(".:" + property)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "SessionSynchronizer"
	sync.replication_config = config
	sync.set_multiplayer_authority(1)
	add_child(sync)

func sender_id() -> int:
	var remote = multiplayer.get_remote_sender_id()
	return remote if remote != 0 else multiplayer.get_unique_id()

func open_lobby() -> void:
	if not multiplayer.is_server():
		return
	running = true
	stage = "lobby"
	register_peer(1)
	main.get_node("BossEncounter").status = "waiting"

func register_peer(id: int) -> void:
	if not multiplayer.is_server() or not running or roster.has(id):
		return
	roster[id] = {"name": "Host" if id == 1 else "Jogador %d" % (roster.size() + 1), "class": "", "talents": {}, "ready": false, "reward": "skip" if stage in ["victory", "defeat"] else "", "spectator": stage != "lobby"}
	if not report.is_empty() and id in multiplayer.get_peers():
		publish_report.rpc_id(id, report)
	revision += 1

@rpc("any_peer", "call_local", "reliable")
func register() -> void:
	if multiplayer.is_server():
		register_peer(sender_id())

func remove_peer(id: int) -> void:
	if not multiplayer.is_server() or not roster.has(id):
		return
	roster.erase(id)
	upgrades.erase(id)
	revision += 1
	if stage == "countdown":
		# A changed party must reconfirm readiness instead of silently starting.
		stage = "lobby"
		countdown = 0
		for member in roster.values():
			member.ready = false

func can_select(id: int) -> bool:
	return not transitioning and (not running or (roster.has(id) and (stage == "lobby" or (stage in ["active", "countdown", "victory", "defeat"] and roster[id].spectator and roster[id]["class"] == ""))))

func selected(id: int, hero: Character) -> void:
	if not running:
		return
	register_peer(id)
	if roster[id]["class"] != hero.charClass:
		roster[id].talents = {}
	roster[id]["class"] = hero.charClass
	roster[id].ready = false
	hero.spectator = roster[id].spectator
	revision += 1

@rpc("any_peer", "call_local", "reliable")
func learn_talent(branch: String, tier: int) -> void:
	var id = sender_id()
	if not multiplayer.is_server() or not running or transitioning or stage != "lobby" or not roster.has(id):
		return
	var member: Dictionary = roster[id]
	var tree = TalentTree.branches(member["class"])
	var choices: Dictionary = member.get("talents", {}).duplicate(true)
	if not tree.has(branch) or tier != int(choices.get(branch, 0)) + 1:
		return
	choices[branch] = tier
	if not TalentTree.valid(member["class"], choices):
		return
	member.talents = choices
	member.ready = false
	revision += 1

@rpc("any_peer", "call_local", "reliable")
func reset_talents() -> void:
	var id = sender_id()
	if not multiplayer.is_server() or not running or transitioning or stage != "lobby" or not roster.has(id):
		return
	roster[id].talents = {}
	roster[id].ready = false
	revision += 1

@rpc("any_peer", "call_local", "reliable")
func set_player_name(value: String) -> void:
	if not multiplayer.is_server() or not roster.has(sender_id()):
		return
	var cleaned = value.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 20)
	if not cleaned.is_empty():
		roster[sender_id()].name = cleaned
		revision += 1

@rpc("any_peer", "call_local", "reliable")
func set_ready(value: bool) -> void:
	if not multiplayer.is_server() or transitioning or stage != "lobby":
		return
	var id = sender_id()
	if not roster.has(id) or not MultiplayerManager.playerList.has(id) or roster[id]["class"] == "":
		return
	roster[id].ready = value
	revision += 1

func can_start() -> bool:
	if not running or transitioning or stage != "lobby" or roster.is_empty():
		return false
	if not main.pending_spawns.is_empty() or not main.retiring.is_empty():
		return false
	for id in roster:
		if not roster[id].ready or roster[id]["class"] == "" or not MultiplayerManager.playerList.has(id):
			return false
	return true

@rpc("any_peer", "call_local", "reliable")
func start_match() -> void:
	if multiplayer.is_server() and sender_id() == 1 and can_start():
		prepare_round()

func all_rewards_chosen() -> bool:
	for id in roster:
		if not roster[id].spectator and roster[id].reward == "":
			return false
	return true

func finished(result: String) -> void:
	if not multiplayer.is_server() or not running or stage != "active" or result not in ["victory", "defeat"]:
		return
	report = combat_report.snapshot(result, round_index)
	# Four detailed rows can exceed an unreliable synchronizer packet's MTU.
	# Reliable RPCs allow ENet fragmentation and deliver a complete final snapshot.
	publish_report.rpc(report)
	stage = result
	for id in roster:
		roster[id].reward = "" if result == "victory" and not roster[id].spectator else "skip"
	revision += 1

@rpc("authority", "call_local", "reliable")
func publish_report(snapshot: Dictionary) -> void:
	report = snapshot.duplicate(true)

@rpc("any_peer", "call_local", "reliable")
func choose_upgrade(choice: String) -> void:
	var id = sender_id()
	if not multiplayer.is_server() or stage != "victory" or not UPGRADE_NAMES.has(choice) or not roster.has(id):
		return
	if roster[id].reward != "" or roster[id].spectator:
		return
	var choices: Dictionary = upgrades.get(id, {})
	choices[choice] = int(choices.get(choice, 0)) + 1
	upgrades[id] = choices
	roster[id].reward = choice
	revision += 1

@rpc("any_peer", "call_local", "reliable")
func retry() -> void:
	if not multiplayer.is_server() or sender_id() != 1 or stage not in ["victory", "defeat"]:
		return
	if stage == "victory":
		if not all_rewards_chosen():
			return
		round_index += 1
	# Late arrivals without a selected class return the entire group to the lobby.
	for id in roster:
		if not MultiplayerManager.playerList.has(id) or roster[id].spectator:
			stage = "lobby"
			for member in roster.values():
				member.ready = false
			revision += 1
			return
	prepare_round()

func prepare_round() -> void:
	stage = "countdown"
	countdown = 3.0
	for id in roster:
		roster[id].spectator = false
		roster[id].reward = ""
	var positions: Dictionary = {}
	var talents_by_peer: Dictionary = {}
	for id in MultiplayerManager.playerList:
		positions[id] = SPAWNS[main.used_slots.get(id, 0)]
		talents_by_peer[id] = roster[id].get("talents", {})
	report = {}
	combat_report.begin(roster)
	reset_round.rpc(round_index, positions, upgrades, talents_by_peer)
	revision += 1

@rpc("authority", "call_local", "reliable")
func reset_round(index: int, positions: Dictionary, choices: Dictionary, talents_by_peer: Dictionary = {}) -> void:
	report = {}
	main.get_node("SkillHandler").reset_combat()
	main.get_node("CombatPreview").cancel()
	main.get_node("PlayerCastBar").cancel_cast()
	main.get_node("TargetCastBar").cancel_cast()
	main.get_node("BossEncounter").reset_encounter(index)
	for id in MultiplayerManager.playerList:
		var hero = MultiplayerManager.playerList[id]
		hero.reset_for_round(positions.get(id, SPAWNS[0]), choices.get(id, {}), talents_by_peer.get(id, {}))
	var local = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if is_instance_valid(local):
		local.ui_handler.showPlayerHPBar(local, true)
		local.ui_handler.createSkillBar()
	main.get_node("TargetHP").hide()

@rpc("any_peer", "call_local", "reliable")
func return_to_selection() -> void:
	if not multiplayer.is_server() or sender_id() != 1 or transitioning or stage not in ["lobby", "victory", "defeat"]:
		return
	transitioning = true
	stage = "lobby"
	round_index = 1
	upgrades = {}
	report = {}
	combat_report.active = false
	for member in roster.values():
		member.ready = false
		member.talents = {}
		member.spectator = false
		member.reward = ""
	revision += 1
	main.get_node("SkillHandler").reset_combat()
	main.get_node("BossEncounter").status = "waiting"
	main.get_node("BossEncounter").clear_effects()
	for id in MultiplayerManager.playerList.keys():
		if await main.retire_character(id):
			if roster.has(id):
				roster[id]["class"] = ""
	transitioning = false
	selection_reset.rpc()
	revision += 1

@rpc("authority", "call_local", "reliable")
func selection_reset() -> void:
	report = {}
	main.get_node("SessionUI").selecting_class = false
	main.get_node("CombatPreview").cancel()
	main.get_node("PlayerCastBar").cancel_cast()
	main.get_node("TargetCastBar").cancel_cast()
	main.get_node("PlayerHP").hide()
	main.get_node("TargetHP").hide()
	main.get_node("SkillBar").hide()

func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and running and stage == "active":
		combat_report.elapsed += delta
	if multiplayer.is_server() and running and stage == "countdown":
		countdown = maxf(0, countdown - delta)
		if countdown <= 0:
			stage = "active"
			combat_report.active = true
			main.get_node("BossEncounter").status = "active"
			revision += 1
