extends Control
@onready var h_box_container: HBoxContainer = $Panel/HBoxContainer

signal playerSelected

var frame : PackedScene = preload("res://Scenes/Components/PlayerSelect/PlayerPortrait.tscn")
var charList : Array[Character]


func _ready() -> void:
	
	loadCharList() 
	for character in charList:
		var frameChar = frame.instantiate()
		frameChar.character = character

		h_box_container.add_child(frameChar)
		frameChar.connect("playerSelected", playerPortraitSelected)

func loadCharList() -> void:
	charList.append(Aurora.new())
	charList.append(SirGura.new())
	charList.append(Lulu.new())
	charList.append(Charger.new())


func playerPortraitSelected(character : Character) -> void:
	playerSelected.emit(character)
