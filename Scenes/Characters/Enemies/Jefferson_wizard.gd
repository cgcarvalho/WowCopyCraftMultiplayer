class_name Jefferson
extends Character

const BOSS_ID = -1
const MAX_HEALTH = 300
const MOVE_SPEED = 85.0
const MELEE_RANGE = 100.0
const MELEE_DAMAGE = 8
const MELEE_INTERVAL = 1.6
var attack_cooldown = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	charName = "Jefferson Wizard"
	charTeam = Teams.RED
	charTotalLife = MAX_HEALTH
	charCurrentLife = MAX_HEALTH
	charBaseDamage = MELEE_DAMAGE
	charCritChance = 0
	portraitImagePath = "res://Art/Chars/Jefferson - The Wizard/Jefferson.png"

func _ready() -> void:
	# NPCs have no player input state machine or local-player skill bar.
	ui_handler = UIHandler.new(get_parent().get_parent())
	MultiplayerManager.enemies[BOSS_ID] = self
	$AnimatedSprite2D.play("walk")
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.property_set_replication_mode(NodePath(".:position"), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MovementSynchronizer"
	sync.replication_config = config
	add_child(sync)

func _exit_tree() -> void:
	if MultiplayerManager.enemies.get(BOSS_ID) == self:
		MultiplayerManager.enemies.erase(BOSS_ID)

func _process(_delta: float) -> void:
	visible = get_parent().status != "waiting"
	modulate = Color(0.45, 0.45, 0.45, 0.6) if charCurrentLife <= 0 else Color.WHITE
	if is_instance_valid(charCurrentTarget):
		$AnimatedSprite2D.flip_h = charCurrentTarget.global_position.x < global_position.x

func choose_target() -> Character:
	var nearest: Character
	var distance = INF
	for player in MultiplayerManager.playerList.values():
		if not is_instance_valid(player) or player.charCurrentLife <= 0:
			continue
		var candidate = global_position.distance_squared_to(player.global_position)
		if candidate < distance:
			nearest = player
			distance = candidate
	return nearest

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or get_parent().status != "active" or charCurrentLife <= 0:
		return
	charCurrentTarget = choose_target()
	if not is_instance_valid(charCurrentTarget):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	# Jefferson stands still while announcing the area attack.
	if get_parent().danger_visible:
		return
	var target_position = charCurrentTarget.global_position
	if global_position.distance_to(target_position) > MELEE_RANGE:
		global_position = global_position.move_toward(target_position, MOVE_SPEED * delta)
	elif attack_cooldown <= 0:
		charCurrentTarget.deal_damage(MELEE_DAMAGE)
		attack_cooldown = MELEE_INTERVAL

func die() -> void:
	$AnimatedSprite2D.stop()
