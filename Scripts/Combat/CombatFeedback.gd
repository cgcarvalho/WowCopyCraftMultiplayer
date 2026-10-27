extends Node2D

var events = 0
var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_player = 0
var last_sound: Dictionary = {}

func _ready() -> void:
	for kind in ["hit", "crit", "heal", "shield", "cast", "phase", "interrupt", "victory"]:
		sounds[kind] = load("res://Art/Audio/" + kind + ".wav")
	for index in 8:
		var player = AudioStreamPlayer.new()
		player.volume_db = -13
		add_child(player)
		players.append(player)

func play_sound(kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now = Time.get_ticks_msec()
	if players.is_empty() or not sounds.has(kind) or now - int(last_sound.get(kind, -1000)) < 65:
		return
	last_sound[kind] = now
	var player = players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stop()
	player.stream = sounds[kind]
	player.play()

@rpc("authority", "call_local", "unreliable")
func impact(victim_id: int, point: Vector2, kind: String) -> void:
	events += 1
	var effect = ImpactBurst.new()
	effect.kind = kind
	effect.position = point
	add_child(effect)
	var victim = MultiplayerManager.get_character(victim_id)
	if is_instance_valid(victim):
		victim.flash_time = 0.14
		victim.flash_color = ImpactBurst.COLORS.get(kind, Color.WHITE)
	play_sound(kind)

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
	sounds.clear()
