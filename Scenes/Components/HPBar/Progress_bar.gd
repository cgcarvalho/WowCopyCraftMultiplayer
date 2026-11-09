extends Node

var targetPlayer : Character
var targetSelf : bool
var resource_fill: StyleBoxFlat
@onready var portrait: Sprite2D = %Portrait
@onready var character_portrait_transform = portrait.transform

func _process(_delta: float) -> void:
	if is_instance_valid(targetPlayer):
		$HPBar.max_value = targetPlayer.charTotalLife
		$HPBar.value = targetPlayer.charCurrentLife
		if targetPlayer.charTotalMana > 0:
			$ManaBar.visible = true
			$ManaBar.max_value = targetPlayer.charTotalMana
			$ManaBar.value = targetPlayer.charCurrentMana
			if resource_fill == null:
				resource_fill = StyleBoxFlat.new()
				$ManaBar.add_theme_stylebox_override("fill", resource_fill)
			resource_fill.bg_color = targetPlayer.resource_color
		else:
			$ManaBar.visible = false
		
		if targetPlayer.portrait_icon != null:
			portrait.texture = targetPlayer.portrait_icon
			portrait.position = Vector2.ZERO
			portrait.scale = Vector2(1.85, 1.85)
		else:
			portrait.texture = load(targetPlayer.portraitImagePath)
			portrait.transform = character_portrait_transform
		$RichTextLabel.text = targetPlayer.charName
		
		if targetSelf:
			$HpBarNameAlly.visible = true
			$HpBarNameEnemy.visible = false
			$RichTextLabel.self_modulate = Color.BLACK
		else:
			$HpBarNameAlly.visible = false
			$HpBarNameEnemy.visible = true
			$RichTextLabel.self_modulate = Color.WHITE
