extends TextureButton

#@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var timer: Timer = $Timer
@onready var time: Label = $Time


var skillCast : Skill
var skillPlayer : Character
var skillHander


func _ready() -> void:
	set_process(false)
	
	
func _process(_delta: float) -> void:
	time.text = "%3.1f" % timer.time_left
	

func _on_pressed() -> void:
	pass
	
	
func _on_timer_timeout() -> void:
	pass
