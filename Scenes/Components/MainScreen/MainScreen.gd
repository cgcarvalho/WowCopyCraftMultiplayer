extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var timer: Timer = $Timer

func _ready() -> void:
	resized.connect(fit_video)
	visibility_changed.connect(sync_playback)
	fit_video()
	timer.start()

func fit_video() -> void:
	# Cover the viewport without stretching the original aspect ratio.
	var texture = video_player.get_video_texture()
	var source = Vector2(texture.get_width(), texture.get_height()) if texture != null else Vector2(1920, 1080)
	if source.x <= 0 or source.y <= 0:
		source = Vector2(1920, 1080)
	var factor = maxf(size.x / source.x, size.y / source.y)
	video_player.size = source * factor
	video_player.position = (size - video_player.size) / 2

func _on_timer_timeout() -> void:
	video_player.play()
	fit_video()

func _on_video_stream_player_finished() -> void:
	video_player.stop()
	timer.start()

func sync_playback() -> void:
	if not is_visible_in_tree():
		timer.stop()
		video_player.stop()
	elif is_node_ready():
		timer.start()
