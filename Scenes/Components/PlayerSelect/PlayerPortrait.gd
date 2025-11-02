extends Control

@onready var characterPicture: TextureRect = $Character
@onready var button: Button = $Button

signal playerSelected

var character : Character

func _ready() -> void:
	character._enter_tree()
	
	button.tooltip_text = character.charName
	characterPicture.texture = load(character.portraitImagePath)

func _on_button_pressed() -> void:
	playerSelected.emit(character)

func _on_button_mouse_entered() -> void:
	button.modulate.a = 0

func _on_button_mouse_exited() -> void:
	button.modulate.a = 1
