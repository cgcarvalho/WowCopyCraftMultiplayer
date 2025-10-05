extends Node




func show(totalLife : int, currentLife : int, portraitPath : String) -> void:
	$ProgressBar.max_value = totalLife
	$ProgressBar.value = currentLife
	%Portrait.texture = load(portraitPath)
