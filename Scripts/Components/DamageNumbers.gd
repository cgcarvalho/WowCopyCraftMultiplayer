extends CanvasLayer

var sequence = 0
var displayed_events = 0
var displayed_dot_events = 0

func _ready() -> void:
	layer = 3

# Only the server may broadcast combat text. Peers see the same tick feedback.
@rpc("authority", "call_local", "reliable")
func display_number(value: int, position: Vector2, is_critical: bool = false, is_heal: bool = false, periodic: bool = false) -> void:
	displayed_events += 1
	if periodic:
		displayed_dot_events += 1
	var number = Label.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.text = ("+" if is_heal else "−") + str(value)
	if value == 0:
		number.text = "Absorvido"
	var settings = LabelSettings.new()
	settings.font_size = 32 if is_critical else 23
	settings.outline_size = 4
	settings.outline_color = Color("0b0b16")
	settings.shadow_color = Color(0, 0, 0, 0.8)
	settings.shadow_size = 3
	settings.shadow_offset = Vector2(1, 2)
	settings.font_color = Color("dfb2ff") if periodic else Color("fff4df")
	if is_heal:
		settings.font_color = Color("79f1b0")
	elif is_critical:
		settings.font_color = Color("ffb572")
	number.label_settings = settings
	number.z_index = 30
	add_child(number)
	var lane = sequence % 3 - 1
	sequence += 1
	var projected = get_viewport().get_canvas_transform() * (position + Vector2(0, -125))
	number.position = projected + Vector2(lane * 30 - 12, -abs(lane) * 12)
	var tween = number.create_tween()
	tween.set_parallel(true)
	tween.tween_property(number, "position:y", number.position.y - 46, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.45).set_delay(0.45)
	tween.finished.connect(number.queue_free)
