extends Control

@onready var cast_bar: ProgressBar = $Bar
@onready var cast_timer: Timer = $CastTime
signal castEnd

var is_casting = false
var cast_time = 2.0 
var cast_until_msec = 0

func remaining_seconds() -> float:
	return maxf(0, (cast_until_msec - Time.get_ticks_msec()) / 1000.0)

func _ready():
	cast_bar.hide()

func start_cast(_skill_name: String, duration: float):
	if is_casting:
		return

	is_casting = true
	cast_time = duration
	cast_until_msec = Time.get_ticks_msec() + roundi(duration * 1000)
	cast_bar.show()

	cast_timer.wait_time = cast_time
	cast_timer.start()

	set_process(true) 

func _process(_delta):
	if is_casting:
		cast_bar.value = (cast_time - remaining_seconds()) / cast_time

func _on_cast_timer_timeout():
	if remaining_seconds() > 0:
		cast_timer.start(remaining_seconds())
		return
	is_casting = false
	cast_bar.value = 1.0
	cast_bar.hide()
	castEnd.emit()
	set_process(false)

func cancel_cast():
	cast_until_msec = 0
	if is_casting:
		is_casting = false
		cast_timer.stop()
		cast_bar.value = 0.0
		cast_bar.hide()
		set_process(false)
