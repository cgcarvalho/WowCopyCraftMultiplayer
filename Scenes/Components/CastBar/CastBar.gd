extends Control

@onready var cast_bar: ProgressBar = $Bar
@onready var cast_timer: Timer = $CastTime
signal castEnd

var is_casting = false
var cast_time = 2.0 

func _ready():
	cast_bar.hide()

func start_cast(_skill_name: String, duration: float):
	if is_casting:
		return

	is_casting = true
	cast_time = duration
	cast_bar.show()

	cast_timer.wait_time = cast_time
	cast_timer.start()

	set_process(true) 

func _process(_delta):
	if is_casting:
		cast_bar.value = (cast_time - cast_timer.time_left) / cast_time

func _on_cast_timer_timeout():
	is_casting = false
	cast_bar.value = 1.0
	cast_bar.hide()
	castEnd.emit()
	set_process(false)

func cancel_cast():
	if is_casting:
		is_casting = false
		cast_timer.stop()
		cast_bar.value = 0.0
		cast_bar.hide()
		set_process(false)
