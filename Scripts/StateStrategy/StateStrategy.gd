extends Node
class_name StateStrategy

var current_state: State
var animatedSprite : AnimatedSprite2D
var statePlayer : Character
var mainScene : Node


func _init(sprite : AnimatedSprite2D, player : Character, main : Node) -> void:
	animatedSprite = sprite
	statePlayer = player
	mainScene = main
	set_state(Idle.new())

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process(delta)

func set_state(new_state: State) -> void:
	if current_state:
		current_state.exit()
		current_state.queue_free()
	
	if new_state:
		current_state = new_state
		current_state.state_machine = self
		current_state.enter()
