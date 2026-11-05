class_name ArenaCatalog
extends RefCounted

const IDS = ["forest", "ruins", "glacier"]
const ARENAS = {
	"forest": {
		"name": "Clareira Verdejante",
		"description": "Centro aberto · Árvores nas bordas",
		"scene": "res://Scenes/Maps/MapForest.tscn",
		"floor": "",
		"color": Color("526b43"), "rim": Color("a69a69"), "outside": Color("34565b"),
		"obstacles": [Vector2(1230, 185), Vector2(1230, 595)],
		"spawns": [Vector2(180, 420), Vector2(180, 250), Vector2(350, 420), Vector2(350, 250)],
		"boss": Vector2(880, 300)
	},
	"ruins": {
		"name": "Ruínas Arcanas",
		"description": "Pedras nos flancos · Corredor central livre",
		"scene": "res://Scenes/Maps/MapRuins.tscn",
		"floor": "res://Art/Terrain/Arenas/Ruins.png",
		"color": Color("465460"), "rim": Color("a39978"), "outside": Color("202d37"),
		"obstacles": [Vector2(580, 185), Vector2(1100, 185), Vector2(580, 595), Vector2(1100, 595)],
		"spawns": [Vector2(180, 300), Vector2(180, 480), Vector2(340, 300), Vector2(340, 480)],
		"boss": Vector2(1080, 390)
	},
	"glacier": {
		"name": "Santuário Glacial",
		"description": "Campo livre · Espaço para desviar em grupo",
		"scene": "res://Scenes/Maps/MapGlacier.tscn",
		"floor": "res://Art/Terrain/Arenas/Glacier.png",
		"color": Color("4d7180"), "rim": Color("9cbfc6"), "outside": Color("1e3546"),
		"obstacles": [],
		"spawns": [Vector2(300, 550), Vector2(500, 550), Vector2(300, 370), Vector2(500, 370)],
		"boss": Vector2(1050, 310)
	}
}

static func definition(id: String) -> Dictionary:
	return ARENAS.get(id, ARENAS.forest)
