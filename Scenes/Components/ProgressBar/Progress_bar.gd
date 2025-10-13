extends Node

var targetPlayer : Character
var targetSelf : bool

func _process(delta: float) -> void:
	if targetPlayer:
		$ProgressBar.max_value = targetPlayer.charTotalLife
		$ProgressBar.value = targetPlayer.charCurrentLife
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
