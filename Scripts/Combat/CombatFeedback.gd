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

func effect_opacity(source: Character) -> float:
	var local: Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
	if not is_instance_valid(source) or not is_instance_valid(local) or source == local or source.charTeam != local.charTeam:
		return 1.0
	return 0.4

func play_sound(kind: String, intensity: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now = Time.get_ticks_msec()
	var channel = kind + ("_party" if intensity < 1 else "_personal")
	if players.is_empty() or not sounds.has(kind) or now - int(last_sound.get(channel, -1000)) < 65:
		return
	last_sound[channel] = now
	var player = players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stop()
	player.stream = sounds[kind]
	player.volume_db = -13 + linear_to_db(maxf(0.05, intensity))
	player.pitch_scale = 1.04 if kind == "hit" else 1.0
	player.play()

@rpc("authority", "call_local", "unreliable")
func impact(victim_id: int, point: Vector2, kind: String, source_id: int = 0, periodic: bool = false) -> void:
	events += 1
	var personal = source_id == multiplayer.get_unique_id() or victim_id == multiplayer.get_unique_id()
	var source = MultiplayerManager.get_character(source_id)
	var intensity = 1.0 if personal else effect_opacity(source)
	if periodic:
		intensity *= 0.35
	var effect = ImpactBurst.new()
	effect.kind = kind
	effect.intensity = intensity
	effect.periodic = periodic
	effect.position = point
	if is_instance_valid(source):
		effect.direction = (point - source.global_position).normalized()
	add_child(effect)
	var victim = MultiplayerManager.get_character(victim_id)
	if is_instance_valid(victim) and not periodic and intensity >= 1:
		victim.flash_time = 0.07 if periodic else 0.11
		victim.flash_color = Color.WHITE.lerp(ImpactBurst.COLORS.get(kind, Color.WHITE), intensity * 0.5)
	if not periodic:
		play_sound(kind, intensity)

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
	sounds.clear()
