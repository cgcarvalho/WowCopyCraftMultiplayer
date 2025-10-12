extends Node

const font_size : int = 18
const outline_size : int = 1
const color_damage : String = "#FFF"
const color_critical : String =  "#B22"
const color_fail : String = "#FFF8"
const outline_color : String = "#000"

var number : Label

func display_number(value : int, position : Vector2, is_critical : bool) -> void:
	create_number(value, position, is_critical)
	animate_number()

func create_number(value : int, position : Vector2, is_critical : bool) -> void:
	number = Label.new()
	number.global_position = position
	number.text = str(value)
	number.z_index = 5
	number.label_settings = LabelSettings.new()
	
	var color = color_damage
	if is_critical:
		color = color_critical
	if value == 0: 
		color = color_fail
		
	number.label_settings.font_color = color
	number.label_settings.font_size = font_size
	number.label_settings.outline_color = outline_color
	number.label_settings.outline_size = outline_size
	
	call_deferred("add_child", number)
	
	
	await number.resized
	number.pivot_offset = Vector2(number.size / 2)

func animate_number() -> void:
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(
		number, "position:y", number.position.y - 24, 0.25
	).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(
		number, "position:y", number.position.y, 0.5
	).set_ease(Tween.EASE_IN).set_delay(0.25)
	
	tween.tween_property(
		number, "scale", Vector2.ZERO, 0.25
	).set_ease(Tween.EASE_IN).set_delay(0.5)
	
	await tween.finished
	number.queue_free()
	
	
	
