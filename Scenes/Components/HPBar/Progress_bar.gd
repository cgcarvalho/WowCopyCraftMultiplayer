extends Node

var targetPlayer : Character
var targetSelf : bool
var resource_fill: StyleBoxFlat

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
		
		%Portrait.texture = load(targetPlayer.portraitImagePath)
		$RichTextLabel.text = targetPlayer.charName
		
		if targetSelf:
			$HpBarNameAlly.visible = true
			$HpBarNameEnemy.visible = false
			$RichTextLabel.self_modulate = Color.BLACK
		else:
			$HpBarNameAlly.visible = false
			$HpBarNameEnemy.visible = true
			$RichTextLabel.self_modulate = Color.WHITE
