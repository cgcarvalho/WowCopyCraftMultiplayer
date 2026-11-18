class_name Engineer
extends Character

const SCENE_PATH = "res://Scenes/Characters/Heroes/Teo.tscn"
const BEACON_RADIUS = 165.0
const CIRCUIT_HITS = 3
const OVERLOAD_DURATION = 5.0
const PULSE_INTERVAL = 1.25
const DEVICE_COLOR = Color("ffa965")

var beacon_position := Vector2.ZERO
var beacon_remaining := 0.0
var circuit_hits := 0
var overload_position := Vector2.ZERO
var overload_remaining := 0.0
var overload_pulses := 0
var beacon_lifetime := 10.0

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Téo"
	charClass = "Engineer"
	portraitImagePath = "res://Art/Chars/Teo/Idle.png"
	portrait_icon = preload("res://Art/Chars/Teo/Portrait.webp")
	scenePath = SCENE_PATH
	base_life = 115
	charTotalLife = base_life
	charCurrentLife = charTotalLife
	charBaseDamage = 7
	charRange = 520
	attack_interval = 1.1
	attack_style = "rivet"
	if skillList.is_empty():
		for id in ["rivet_shot", "field_beacon", "valve_burst", "overload"]:
			skillList.append(HeroAbility.create(id))
	configure_resource()
	if not is_inside_tree():
		return
	var config = SceneReplicationConfig.new()
	for property in ["beacon_position", "beacon_remaining", "beacon_lifetime", "circuit_hits", "overload_position", "overload_remaining"]:
		var property_path = NodePath(".:" + property)
		config.add_property(property_path)
		config.property_set_replication_mode(property_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "DeviceSynchronizer"
	sync.replication_config = config
	sync.set_multiplayer_authority(1)
	add_child(sync)

func configure_resource() -> void:
	resource_name = "Pressão"
	resource_color = DEVICE_COLOR
	charTotalMana = 100
	charCurrentMana = 20
	manaRegen = 0
	super.configure_resource()

func _ready() -> void:
	super._ready()
	SkillFX.install_pose($AnimatedSprite2D, &"pose_device")

func reset_for_round(point: Vector2, choices: Dictionary, selected_talents: Dictionary = {}, selected_mastery: String = "") -> void:
	clear_devices()
	super.reset_for_round(point, choices, selected_talents, selected_mastery)

func clear_devices() -> void:
	beacon_remaining = 0
	circuit_hits = 0
	overload_remaining = 0
	overload_pulses = 0

func in_beacon(point: Vector2) -> bool:
	return beacon_remaining > 0 and point.distance_to(beacon_position) <= BEACON_RADIUS

func deploy_beacon(point: Vector2, duration: float) -> void:
	if beacon_remaining > 0 and beacon_position.distance_squared_to(point) > 4.0:
		CombatFeedback.show_skill_effect(&"beacon_exit", beacon_position, self, 110)
	beacon_position = point
	beacon_lifetime = duration
	beacon_remaining = duration
	circuit_hits = 0

func on_basic_hit(target: Character = null) -> void:
	if not multiplayer.is_server():
		return
	gain_resource(7)
	if not is_instance_valid(target) or not in_beacon(target.global_position):
		return
	circuit_hits += 1
	if circuit_hits == CIRCUIT_HITS:
		circuit_hits = 0
		target.deal_damage(14, self)
		gain_resource(5)
		CombatFeedback.show_skill_effect(&"spark", target.global_position, self, 130)
		MasteryEffects.circuit(self, target)

func on_rivet_hit(target: Character) -> void:
	if multiplayer.is_server():
		var hot_motor = TalentTree.has(talents, "workshop", 1) and in_beacon(target.global_position)
		gain_resource(24 if hot_motor else 18)

func start_overload() -> void:
	overload_position = beacon_position
	overload_pulses = 0
	overload_remaining = OVERLOAD_DURATION

func overload_radius() -> float:
	return 135.0 if TalentTree.has(talents, "workshop", 3) else 175.0

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		var handler = get_parent().get_parent().get_node_or_null("SkillHandler")
		if charCurrentLife <= 0 or spectator or (handler != null and handler.encounter_finished()):
			clear_devices()
		else:
			update_devices(delta)
	super._physics_process(delta)

func update_devices(delta: float) -> void:
	if beacon_remaining > 0:
		beacon_remaining = maxf(0.0, beacon_remaining - delta)
		if beacon_remaining == 0:
			circuit_hits = 0
			CombatFeedback.show_skill_effect(&"beacon_exit", beacon_position, self, 110)
	if overload_remaining <= 0:
		return
	overload_remaining = maxf(0.0, overload_remaining - delta)
	var elapsed = OVERLOAD_DURATION - overload_remaining
	while overload_pulses < 4 and elapsed >= (overload_pulses + 1) * PULSE_INTERVAL:
		overload_pulses += 1
		pulse_overload()

func pulse_overload() -> void:
	var emergency = TalentTree.has(talents, "safeguard", 3)
	var power = 16 if TalentTree.has(talents, "workshop", 3) else (10 if emergency else 12)
	var radius = overload_radius()
	CombatFeedback.show_skill_effect(&"coil", overload_position, self, radius * 2)
	for target in MultiplayerManager.enemies.values():
		if is_instance_valid(target) and target.global_position.distance_to(overload_position) <= radius:
			target.deal_damage(power, self, true)
	if emergency and overload_pulses in [1, 4]:
		for ally in MultiplayerManager.playerList.values():
			if is_instance_valid(ally) and ally.charCurrentLife > 0 and not ally.spectator and ally.global_position.distance_to(overload_position) <= radius:
				ally.apply_shield(6, self, 3.0)
				CombatFeedback.show_skill_effect(&"shield", ally.global_position, self, 96, 0, 0, ally)

func _process(delta: float) -> void:
	super._process(delta)
	queue_redraw()

func _draw() -> void:
	super._draw()
	if charCurrentLife <= 0 or spectator:
		return
	var opacity = CombatFeedback.effect_opacity(self)
	if beacon_remaining > 0:
		var center = to_local(beacon_position)
		var tint = Color(DEVICE_COLOR, opacity * 0.90)
		var phase = clampf((beacon_lifetime - beacon_remaining) / 0.65, 0, 1)
		var retiring = clampf(beacon_remaining / 0.5, 0.0, 1.0)
		for mark in 24:
			var angle = TAU * mark / 24.0
			draw_arc(center, BEACON_RADIUS, angle, angle + 0.13, 3, tint, 2.5, true)
		var art_point = center + Vector2(0, -41)
		var art_size = Vector2.ONE * 116 * lerpf(0.5, 1.0, retiring)
		if not SkillFX.draw_clip(self, &"beacon", art_point, art_size, phase, 0, Color(1, 1, 1, opacity * retiring)):
			for dx in [-23, 0, 23]:
				draw_line(art_point, center + Vector2(dx, 0), tint, 4, true)
			draw_circle(art_point, 10, tint)
		for light in 3:
			var slot = center + Vector2((light - 1) * 11, 12)
			draw_rect(Rect2(slot - Vector2(4, 4), Vector2(8, 8)), Color(0.16, 0.10, 0.08, opacity))
			if light < circuit_hits:
				draw_circle(slot, 3, Color("fff3b7") * Color(1, 1, 1, opacity))
	if overload_remaining > 0:
		var center = to_local(overload_position)
		var radius = overload_radius()
		var cycle = fposmod(OVERLOAD_DURATION - overload_remaining, PULSE_INTERVAL) / PULSE_INTERVAL
		var rim_color = Color(0.99, 0.78, 0.48, opacity * 0.72)
		SkillFX.rim(self, center, radius, rim_color, 12, PI / 12)
		SkillFX.draw_clip(self, &"coil", center + Vector2(0, -49), Vector2.ONE * 138, cycle, 0, Color(1, 1, 1, opacity))
		for i in 4:
			var unit = Vector2.from_angle(i * TAU / 4 + PI / 4)
			SkillFX.arrow(self, center + unit * lerpf(42.0, radius - 21.0, cycle), unit, rim_color)
