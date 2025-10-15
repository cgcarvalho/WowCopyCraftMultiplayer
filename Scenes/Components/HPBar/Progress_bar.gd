extends Node

var targetPlayer : Character
var targetSelf : bool

func _process(_delta: float) -> void:
	if targetPlayer:
		$HPBar.max_value = targetPlayer.charTotalLife
		$HPBar.value = targetPlayer.charCurrentLife
		if targetPlayer.charTotalMana > 0:
			$ManaBar.max_value = targetPlayer.charTotalMana
			$ManaBar.value = targetPlayer.charCurrentMana
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
