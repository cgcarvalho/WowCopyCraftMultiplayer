extends Node

var targetPlayer : Character

func _process(delta: float) -> void:
	if targetPlayer:
		$ProgressBar.max_value = targetPlayer.charTotalLife
		$ProgressBar.value = targetPlayer.charCurrentLife
		%Portrait.texture = load(targetPlayer.portraitImagePath)
