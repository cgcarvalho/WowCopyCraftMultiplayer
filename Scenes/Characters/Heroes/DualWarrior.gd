class_name DualWieldWarrior
extends Character

const SCENE_PATH = "res://Scenes/Characters/Heroes/DualWarrior.tscn"
const DISPLAY_NAME = "Tiagolas"
const CADENCE_MAX = 3
var cadence = 0
var cadence_remaining = 0.0
var riposte_remaining = 0.0
var dance_effect: HeroAbility
var death_started = false
var reaction_remaining = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	charName = DISPLAY_NAME
	charClass = "DualWarrior"
	scenePath = SCENE_PATH
	portraitImagePath = "res://Art/Chars/DualWarrior/Reference.png"
	portrait_icon = preload("res://Art/Chars/DualWarrior/Portrait.webp")
	base_life = 140
	charTotalLife = base_life
	charCurrentLife = charTotalLife
	charBaseDamage = 5
	charRange = 155
	attack_interval = 1.0
	attack_style = "dual_melee"
	if skillList.is_empty():
		for id in ["twin_cross", "steel_step", "blade_guard", "blade_dance"]:
			skillList.append(HeroAbility.create(id))
	configure_resource()
	if not is_inside_tree():
		return
	var sync = MultiplayerSynchronizer.new()
	sync.name = "DualWarriorSynchronizer"
	sync.set_multiplayer_authority(1)
	var config = SceneReplicationConfig.new()
	for property in ["cadence", "cadence_remaining", "riposte_remaining"]:
		var property_path = NodePath(".:" + property)
		config.add_property(property_path)
		config.property_set_spawn(property_path, true)
		config.property_set_replication_mode(property_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	add_child(sync)

func configure_resource() -> void:
	resource_name = "Fúria"
	resource_color = Color("dc8b55")
	charTotalMana = 100
	charCurrentMana = 0
	manaRegen = 0
	super.configure_resource()

func cadence_duration() -> float:
	return 6.0 if TalentTree.has(talents, "frenzy", 2) else 4.0

func dual_basic_hit(second_hand: bool) -> void:
	if not multiplayer.is_server() or charCurrentLife <= 0 or spectator:
		return
	gain_resource(5)
	if second_hand:
		cadence = mini(CADENCE_MAX, cadence + 1)
		cadence_remaining = cadence_duration()

func consume_cadence() -> int:
	var result = cadence
	cadence = 0
	cadence_remaining = 0
	return result

func update_class_passive(delta: float) -> void:
	super.update_class_passive(delta)
	cadence_remaining = maxf(0, cadence_remaining - delta)
	riposte_remaining = maxf(0, riposte_remaining - delta)
	if cadence_remaining == 0:
		cadence = 0

func clear_dual_state() -> void:
	cadence = 0
	cadence_remaining = 0
	riposte_remaining = 0
	dance_effect = null
	reaction_remaining = 0

func reset_for_round(point: Vector2, choices: Dictionary, selected_talents: Dictionary = {}, selected_mastery: String = "") -> void:
	clear_dual_state()
	death_started = false
	super.reset_for_round(point, choices, selected_talents, selected_mastery)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and (charCurrentLife <= 0 or spectator or get_tree().current_scene.get_node("SkillHandler").encounter_finished()):
		clear_dual_state()
	super._physics_process(delta)

func guard_balance() -> int:
	for contribution in shield_sources:
		if int(contribution.id) == int(name) and contribution.get("key", "") == "blade_guard":
			return int(contribution.amount)
	return 0

func deal_damage(amount: int, source: Character = null, periodic: bool = false, skill_multiplier: float = 1.0) -> void:
	if multiplayer.is_server():
		expire_shields()
	var guard_before = guard_balance()
	super.deal_damage(amount, source, periodic, skill_multiplier)
	if not multiplayer.is_server() or charCurrentLife <= 0 or riposte_remaining <= 0 or guard_balance() >= guard_before:
		return
	riposte_remaining = 0
	gain_resource(12)
	var targets = MasteryEffects.enemies_near(self, global_position, 180)
	var empowered = MasteryCatalog.active(self, "vengeful_guard")
	if not targets.is_empty():
		targets[0].deal_damage(16 if empowered else 8, self)
		CombatFeedback.show_skill_effect(&"slash", targets[0].global_position, self, 105)
	if empowered:
		var allies = MasteryEffects.allies_near(self, global_position, 220, self)
		allies.sort_custom(func(a, b):
			var first = a.global_position.distance_squared_to(global_position)
			var second = b.global_position.distance_squared_to(global_position)
			return int(a.name) < int(b.name) if is_equal_approx(first, second) else first < second)
		if not allies.is_empty():
			allies[0].upsert_shield(12, self, 3, "vengeful_guard")
			CombatFeedback.show_skill_effect(&"shield", allies[0].global_position, self, 95, 0, 0, allies[0])
	CombatFeedback.show_skill_effect(&"shield", global_position, self, 115, 0, 0, self)

func play_ability(duration: float, path: String = "") -> void:
	super.play_ability(duration, path)
	var pose = {"twin_cross": &"cross", "steel_step": &"dash", "blade_guard": &"guard", "blade_dance": &"spin"}.get(path.get_file().get_basename(), &"cast")
	if $AnimatedSprite2D.sprite_frames.has_animation(pose):
		ability_pose = pose
		ability_animation_length = maxf(duration, 0.55)
		ability_animation_time = ability_animation_length
		$AnimatedSprite2D.play(pose)
		$AnimatedSprite2D.set_frame_and_progress(0, 0)

func play_skill_animation(skill: Skill) -> void:
	if skill is HeroAbility and skill.ability_id == "blade_dance":
		dance_effect = skill

func die() -> void:
	if not death_started:
		super.die()
		death_started = true
		clear_dual_state()
		if $AnimatedSprite2D.sprite_frames.has_animation(&"death"):
			$AnimatedSprite2D.play(&"death")

func update_presentation(delta: float) -> void:
	if charCurrentLife <= 0:
		death_progress = minf(1, death_progress + delta)
		modulate = Color(0.75, 0.75, 0.75, 1.0 - death_progress * 0.35)
		return
	super.update_presentation(delta)
	reaction_remaining = maxf(0, reaction_remaining - delta)
	if flash_time > 0 and reaction_remaining <= 0:
		reaction_remaining = 0.25
	if is_instance_valid(dance_effect) and not dance_effect.is_queued_for_deletion() and dance_effect.living() and not spectator:
		show_timed_pose(&"spin", dance_effect.elapsed)
	elif reaction_remaining > 0 and ability_animation_time <= 0 and basic_animation_remaining <= 0:
		show_timed_pose(&"hit", 0.25 - reaction_remaining)

func show_timed_pose(clip: StringName, elapsed: float) -> void:
	# Movement/attack states can change the body animation every physics tick.
	# Keep these overlays on their own clock so they still advance in combat.
	var body: AnimatedSprite2D = $AnimatedSprite2D
	var frames = body.sprite_frames
	var count = frames.get_frame_count(clip)
	var position = elapsed * frames.get_animation_speed(clip)
	position = fposmod(position, count) if frames.get_animation_loop(clip) else minf(position, count - 0.001)
	body.play(clip)
	body.set_frame_and_progress(int(position), fposmod(position, 1))

func _draw() -> void:
	super._draw()
	if spectator or charCurrentLife <= 0:
		return
	if riposte_remaining > 0:
		draw_arc(Vector2(0, 40), 68, -PI, 0, 28, Color(0.76, 0.87, 1, 0.65), 3, true)
	if is_multiplayer_authority():
		for index in CADENCE_MAX:
			var point = Vector2(-14 + 14 * index, -111)
			draw_circle(point, 4, Color("f4c079") if index < cadence else Color("453d3b"))
