extends Area2D
class_name Character

enum Teams {RED, BLUE}

var state_machine: StateStrategy
var ui_handler: UIHandler
var isCrit : bool = false
@export var speed = 5.0
var portraitImagePath : String
var scenePath : String
var charTeam : Teams

#region Character Properties
#HP
var charTotalLife: int = 0
var charCurrentLife: int:
	set(value):
		charCurrentLife = clamp(value, 0, charTotalLife)

#Mana
var charTotalMana: float = 0
var charCurrentMana:float:
	set(value):
		charCurrentMana = clamp(value, 0, charTotalMana)
var manaRegen : float = 0

#Defense
var charShield : int = 0


#Basic Stats
var charName: String
var charBaseDamage : int
var charCritChance : float = Constants.DEFAULT_CRIT_CHANCE
var charLifeStealPercent : float = Constants.DEFAULT_LIFE_STEAL
var charRange : float

#Skills
var skillList : Array[Skill] 
var buffList : Array[Skill]
var debuffList : Array[Skill]
var passiveSkill : PassiveSkill

#Target
var charCurrentTarget : Character

#endregion

func _enter_tree() -> void:
	if not is_inside_tree():
		return
	var config = SceneReplicationConfig.new()
	for property in ["charCurrentLife", "charCurrentMana", "charShield"]:
		var path = NodePath(".:" + property)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "CombatSynchronizer"
	sync.replication_config = config
	sync.set_multiplayer_authority(1)
	add_child(sync)

func _ready() -> void:
	var main = get_parent().get_parent()
	state_machine = StateStrategy.new($AnimatedSprite2D, self, main)
	ui_handler = UIHandler.new(main)
	
	if is_multiplayer_authority(): 
		ui_handler.showPlayerHPBar(self, true)
		ui_handler.createSkillBar()

	
func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if passiveSkill:
			passiveSkill.physics_process(delta)
		if charTotalMana > 0:
			charCurrentMana += manaRegen * delta
	if not is_multiplayer_authority(): return
	
	if state_machine:
		state_machine._physics_process(delta)
	
	
	if is_instance_valid(charCurrentTarget):
		$AnimatedSprite2D.flip_h = global_position.x < charCurrentTarget.global_position.x
	
	if charCurrentLife <= 0:
		die()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var localPlayer : Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
		
		if not is_instance_valid(localPlayer):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				localPlayer.charCurrentTarget = self
				ui_handler.showTargetHPBar(self, localPlayer == self)
				
		#if event.button_index == MOUSE_BUTTON_RIGHT:
		#	if event.pressed:
		#		ui_handler.hideTargetHPBar()
		#		localPlayer.charCurrentTarget = null

func deal_damage(damage : int) -> void:
	if not multiplayer.is_server() or charCurrentLife <= 0 or damage <= 0:
		return
	damage = apply_crit(damage)
	var absorbed = mini(charShield, damage)
	charShield -= absorbed
	damage -= absorbed
	charCurrentLife -= damage
	DamageNumbers.display_number(damage, global_position, isCrit)
		
	

func apply_heal(heal : int) -> void:
	if not multiplayer.is_server():
		return
	charCurrentLife += heal
	DamageNumbers.display_number(heal, global_position, isCrit, true)	

func apply_shield(shield : int) -> void:
	if not multiplayer.is_server():
		return
	charShield = shield

func apply_crit(damage : int) -> int:
	var random_value = randf()
	var newDamage = damage
	isCrit = random_value < charCritChance

	if isCrit:
		newDamage = damage * Constants.CRIT_MULTIPLIER
	
	return newDamage

func die() -> void:
	set_physics_process(false)
	#visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for skill in skillList:
			if is_instance_valid(skill) and not skill.is_inside_tree():
				skill.free()
		if is_instance_valid(passiveSkill):
			passiveSkill.free()
		if is_instance_valid(state_machine):
			if is_instance_valid(state_machine.current_state):
				state_machine.current_state.free()
			state_machine.free()
		if is_instance_valid(ui_handler):
			ui_handler.free()
