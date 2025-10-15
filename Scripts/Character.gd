extends Area2D
class_name Character

enum Teams {RED, BLUE}

var state_machine: StateStrategy
var ui_handler: UIHandler
@export var speed = 5.0
var portraitImagePath : String
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

#Skills
var skillList : Dictionary[String, Skill] 

#Target
var charCurrentTarget : Character

#endregion

func _ready() -> void:
	var main = get_parent().get_parent()
	state_machine = StateStrategy.new($AnimatedSprite2D, self, main)
	ui_handler = UIHandler.new(main)
	
	if is_multiplayer_authority(): 
		ui_handler.showPlayerHPBar(self, true)
		ui_handler.createSkillBar()

	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	state_machine._physics_process(delta)
	
	if charTotalMana > 0:
		charCurrentMana += manaRegen * delta
	
	if charCurrentTarget:
		$AnimatedSprite2D.flip_h = global_position.x > charCurrentTarget.global_position.x
		


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var localPlayer : Character = MultiplayerManager.playerList.get(multiplayer.get_unique_id())
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				localPlayer.charCurrentTarget = self
				ui_handler.showTargetHPBar(self, localPlayer == self)
				
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				ui_handler.hideTargetHPBar()
				localPlayer.charCurrentTarget = null

func deal_damage(damage : int) -> void:
	if charShield - damage < 0:
		charShield = 0
		damage = damage - charShield
		charCurrentLife -= damage
		DamageNumbers.display_number(damage, global_position, false)
	else:
		charShield -= damage

func apply_heal(heal : int) -> void:
	charCurrentLife += heal
	DamageNumbers.display_number(heal, global_position, false, true)	

func apply_shield(shield : int) -> void:
	charShield = shield
