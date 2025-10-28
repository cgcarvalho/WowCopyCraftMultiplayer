extends Control

@onready var video_player = $VideoStreamPlayer
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.start()

func _on_timer_timeout() -> void:
	video_player.play()
	timer.stop()
	

func _on_video_stream_player_finished() -> void:
	video_player.stop()
	timer.start()
