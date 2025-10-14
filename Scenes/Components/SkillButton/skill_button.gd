extends TextureButton

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var timer: Timer = $Timer
@onready var time: Label = $Time
@onready var key: Label = $Key

var changeKey = "":
	set(value):
		changeKey = value
		key.text = value
		
		shortcut = Shortcut.new()
		var input_key = InputEventKey.new()
		input_key.keycode = value.unicode_at(0)
		
		shortcut.events = [input_key]

func _ready() -> void:
	changeKey = "1"
	progress_bar.max_value = timer.wait_time
	set_process(false)
	
func _process(delta: float) -> void:
	time.text = "%3.1f" % timer.time_left
	progress_bar.value = timer.time_left
	

func _on_pressed() -> void:
	timer.start()
	disabled = true
	set_process(true)


func _on_timer_timeout() -> void:
	disabled = false
	time.text = ""
	set_process(false)
