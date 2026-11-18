class_name MasteryCatalog
extends RefCounted

const DEFINITIONS = {
	"contagion": {"class": "Warlock", "branch": "affliction", "name": "Contágio Sombrio", "text": "Soul Reap espalha seus DoTs para até 2 inimigos em raio 130, por até 6 s.", "icon": 0},
	"echo": {"class": "Warlock", "branch": "destruction", "name": "Eco Voraz", "text": "Shadow Bolt lança até 2 ecos de 35% do dano em inimigos a até 180 do impacto.", "icon": 1},
	"drag": {"class": "Warrior", "branch": "berserker", "name": "Tempestade de Arrasto", "text": "Bladestorm puxa inimigos menores 35 unidades, uma vez a cada 2 s por inimigo.", "icon": 2},
	"shared_guard": {"class": "Warrior", "branch": "guardian", "name": "Guarda Compartilhada", "text": "Second Wind concede ao aliado mais próximo a até 220 metade do seu escudo por 3 s.", "icon": 3},
	"chain_light": {"class": "Paladin", "branch": "light", "name": "Luz em Cadeia", "text": "Holy Light cura outro aliado a até 200 do alvo por 35% da cura base, priorizando menor porcentagem de vida.", "icon": 4},
	"protective_ground": {"class": "Paladin", "branch": "bulwark", "name": "Piso Protetor", "text": "Cada tick de Consecration renova 4 de proteção por 1,2 s nos aliados da área.", "icon": 5},
	"infection": {"class": "Hunter", "branch": "venom", "name": "Infecção Residual", "text": "A morte de um inimigo com seu veneno original espalha até 4 s restantes para até 2 inimigos em raio 160.", "icon": 6},
	"piercing": {"class": "Hunter", "branch": "marksman", "name": "Linha Perfurante", "text": "Aimed Shot atravessa mais 180 unidades depois do alvo e atinge até 2 outros inimigos por 45% do dano.", "icon": 7},
	"conductive_rivet": {"class": "Engineer", "branch": "workshop", "name": "Rebite Condutor", "text": "Circuito Fechado lança um rebite de 7 de dano em outro inimigo a até 180 do atingido.", "icon": 8},
	"shelter_circuit": {"class": "Engineer", "branch": "safeguard", "name": "Circuito de Amparo", "text": "Circuito Fechado renova 6 de proteção por 2 s nos aliados vivos dentro da sua Baliza.", "icon": 9}
}

static func valid(hero_class: String, talents: Dictionary, id: String) -> bool:
	if id.is_empty():
		return true
	if not DEFINITIONS.has(id) or not TalentTree.valid(hero_class, talents):
		return false
	var definition: Dictionary = DEFINITIONS[id]
	return definition["class"] == hero_class and int(talents.get(definition.branch, 0)) >= 2

static func active(hero: Character, id: String) -> bool:
	return is_instance_valid(hero) and hero.mastery == id and valid(hero.charClass, hero.talents, id)

static func for_branch(hero_class: String, branch: String) -> String:
	for id in DEFINITIONS:
		if DEFINITIONS[id]["class"] == hero_class and DEFINITIONS[id].branch == branch:
			return id
	return ""

static func summary(id: String) -> String:
	return str(DEFINITIONS[id].name) if DEFINITIONS.has(id) else "Escolha uma maestria com 2 pontos na trilha"

static func affects(id: String, skill: Skill) -> bool:
	var abilities = {
		"contagion": ["soul_reap"], "shared_guard": ["second_wind"],
		"drag": ["bladestorm"], "chain_light": ["holy_light"],
		"protective_ground": ["consecration"], "infection": ["poison_arrow"],
		"piercing": ["aimed_shot"], "conductive_rivet": ["field_beacon"],
		"shelter_circuit": ["field_beacon"]
	}
	if id == "echo":
		return skill is ShadowBolt
	return skill is HeroAbility and skill.ability_id in abilities.get(id, [])

static func icon(id: String) -> Texture2D:
	var path = "res://Art/Enemies/Ludo/MasteryIcons.webp"
	if not DEFINITIONS.has(id) or not ResourceLoader.exists(path):
		return null
	var atlas = load(path) as Texture2D
	var index: int = DEFINITIONS[id].icon
	var texture = AtlasTexture.new()
	texture.atlas = atlas
	var cell = Vector2(atlas.get_size()) / Vector2(2, 5)
	texture.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
	return texture
