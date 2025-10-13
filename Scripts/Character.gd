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
var charTotalLife: int
var charCurrentLife: int:
	set(value):
		charCurrentLife = clamp(value, 0, charTotalLife)

#Basic Stats
var charName: String

#Skills
var skillList : Dictionary[String, Skill] 

#Target
var charCurrentTarget : Character

#endregion

func _enter_tree() -> void:
	var main = get_parent().get_parent()
	state_machine = StateStrategy.new($AnimatedSprite2D, self, main)
	ui_handler = UIHandler.new(main)
	
	if is_multiplayer_authority(): 
		ui_handler.showPlayerHPBar(self, true)
	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	state_machine._physics_process(delta)

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
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

	
