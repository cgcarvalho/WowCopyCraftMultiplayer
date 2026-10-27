class_name BattleReport
extends RefCounted

var rows: Dictionary = {}
var elapsed = 0.0
var active = false

func begin(roster: Dictionary) -> void:
	rows = {}
	elapsed = 0
	active = false
	for id in roster:
		var member: Dictionary = roster[id]
		if member.spectator or member["class"] == "":
			continue
		rows[id] = {"name": member.name, "class": member["class"], "talents": TalentTree.summary(member["class"], member.get("talents", {})),
			"damage": 0, "healing": 0, "absorbed": 0, "damage_taken": 0, "interrupts": 0, "mechanics": 0, "deaths": 0}

func add(id: int, metric: String, amount: int) -> void:
	if active and rows.has(id) and rows[id].has(metric) and amount > 0:
		rows[id][metric] += amount

func damage(target: Character, source: Character, effective: int, died: bool) -> void:
	if is_instance_valid(source) and target.charTeam != source.charTeam:
		add(int(source.name), "damage", effective)
	add(int(target.name), "damage_taken", effective)
	if died:
		add(int(target.name), "deaths", 1)

func heal(source: Character, effective: int) -> void:
	if is_instance_valid(source):
		add(int(source.name), "healing", effective)

func snapshot(result: String, round_index: int) -> Dictionary:
	active = false
	return {"result": result, "round": round_index, "duration": elapsed, "players": rows.duplicate(true)}

static func highlights(players: Dictionary, id: int) -> String:
	var titles = {"damage": "Dano", "healing": "Cura", "absorbed": "Proteção", "interrupts": "Interrupções", "mechanics": "Mecânicas"}
	var badges = PackedStringArray()
	for metric in titles:
		var best = 0
		for row in players.values():
			best = maxi(best, int(row[metric]))
		if best > 0 and int(players[id][metric]) == best:
			badges.append(titles[metric])
	return " · ".join(badges)
