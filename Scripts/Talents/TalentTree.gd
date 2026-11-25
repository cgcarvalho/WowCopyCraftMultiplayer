class_name TalentTree
extends RefCounted

const POINTS = 3
const TREES = {
	"DualWarrior": {
		"frenzy": {"name": "Frenesi", "nodes": [
			["Cruzamento brutal", "+25% de dano de Corte Cruzado, incluindo o bônus de Cadência."],
			["Ritmo persistente", "Ritmo de Combate: Cadência dura 6 s em vez de 4 s."],
			["Lâminas incessantes", "Dança das Lâminas causa 8 por pulso em vez de 6."]]},
		"duelist": {"name": "Duelista", "nodes": [
			["Aço firme", "Guarda de Lâminas concede 32 de proteção em vez de 24."],
			["Passo disciplinado", "Passo de Aço: recarga reduzida de 10 para 8 s."],
			["Retomada de fôlego", "Guarda de Lâminas também recupera 12 de vida ao ativar."]]}
	},
	"Warlock": {
		"affliction": {"name": "Aflição", "nodes": [
			["Sombras persistentes", "+20% de dano periódico causado por Aurora."],
			["Fonte obscura", "+2 de regeneração de mana por segundo."],
			["Colheita profunda", "Soul Reap: bônus por DoT próprio aumenta de 12 para 18."]]},
		"destruction": {"name": "Destruição", "nodes": [
			["Projétil voraz", "+25% de dano de Shadow Bolt."],
			["Conjuração sombria", "Shadow Bolt: conjuração reduzida de 1s para 0,7s."],
			["Almas em ruína", "+25% de dano de Soul Reap, incluindo o bônus por DoTs."]]}
	},
	"Warrior": {
		"berserker": {"name": "Berserker", "nodes": [
			["Lâmina feroz", "+25% de dano de Cleave."],
			["Fúria crescente", "Ataques básicos geram 16 de raiva, em vez de 12."],
			["Tempestade de aço", "+25% de dano de Bladestorm."]]},
		"guardian": {"name": "Guardião", "nodes": [
			["Postura defensiva", "Recebe 10% menos dano. Acumula com a aura do paladino."],
			["Fôlego de ferro", "Second Wind concede 30 de proteção, em vez de 15."],
			["Inabalável", "+20% da vida base máxima. Soma com as melhorias da expedição."]]}
	},
	"Paladin": {
		"light": {"name": "Luz", "nodes": [
			["Mãos luminosas", "+20% de cura realizada."],
			["Prece breve", "Holy Light: conjuração reduzida de 1,2s para 0,8s."],
			["Amanhecer radiante", "Divine Dawn: cura base aumenta de 40 para 60."]]},
		"bulwark": {"name": "Bastião", "nodes": [
			["Armadura sagrada", "Recebe 10% menos dano. Acumula com sua aura."],
			["Solo abençoado", "Consecration: raio aumenta de 155 para 185."],
			["Égide da aurora", "Divine Dawn concede 50 de proteção, em vez de 35."]]}
	},
	"Hunter": {
		"venom": {"name": "Veneno", "nodes": [
			["Peçonha concentrada", "Poison Arrow: dano periódico base aumenta de 4 para 6."],
			["Toxina duradoura", "Poison Arrow: duração aumenta de 8s para 10s."],
			["Chuva implacável", "+20% de dano de Arrow Rain."]]},
		"marksman": {"name": "Pontaria", "nodes": [
			["Disparo penetrante", "+25% de dano de Aimed Shot."],
			["Preparação ágil", "Aimed Shot: preparação reduzida de 1s para 0,7s."],
			["Precisão absoluta", "Mira firme concede +25% de dano, em vez de +15%."]]}
	},
	"Engineer": {
		"workshop": {"name": "Oficina", "nodes": [
			["Motor quente", "Tiro de Rebite gera 24 de Pressão dentro da sua Baliza, em vez de 18."],
			["Trinca de campo", "Estouro de Válvula dentro da Baliza atinge o inimigo mais próximo fora da explosão a até 200 do centro por mais 10."],
			["Forno contínuo", "Sobrecarga causa 16 por pulso em raio 135, em vez de 12 em raio 175."]]},
		"safeguard": {"name": "Salvaguarda", "nodes": [
			["Sinal portátil", "Baliza de Campo custa 0 de Pressão e dura 6 s em vez de 10 s."],
			["Válvula de segurança", "Estouro de Válvula dentro da Baliza causa 23 de dano e concede 10 de escudo por 3 s aos aliados na área."],
			["Rede de emergência", "Sobrecarga causa 10 por pulso e concede 6 de escudo por 3 s no primeiro e no último pulso."]]}
	}
}

static func branches(hero_class: String) -> Dictionary:
	return TREES.get(hero_class, {})

static func spent(choices: Dictionary) -> int:
	var total = 0
	for value in choices.values():
		total += int(value)
	return total

static func valid(hero_class: String, choices: Dictionary) -> bool:
	var tree = branches(hero_class)
	for branch in choices:
		if not tree.has(branch) or not choices[branch] is int or choices[branch] < 0 or choices[branch] > tree[branch].nodes.size():
			return false
	return spent(choices) <= POINTS

static func has(choices: Dictionary, branch: String, tier: int) -> bool:
	return int(choices.get(branch, 0)) >= tier

static func summary(hero_class: String, choices: Dictionary) -> String:
	var parts = PackedStringArray()
	for branch in branches(hero_class):
		if int(choices.get(branch, 0)) > 0:
			parts.append("%s %d" % [TREES[hero_class][branch].name, choices[branch]])
	return " / ".join(parts) if not parts.is_empty() else "Sem talentos"

static func configure_skill(skill: Skill, choices: Dictionary) -> void:
	# Restore from definitions first: retries and redistributions never stack changes.
	if skill is ShadowBolt:
		skill.skillBaseDamage = ShadowBolt.damage
		skill.skillCastTime = 0.7 if has(choices, "destruction", 2) else ShadowBolt.castTime
	elif skill is HeroAbility:
		skill.configure(skill.ability_id)
		if skill.ability_id == "holy_light" and has(choices, "light", 2):
			skill.skillCastTime = 0.8
		if skill.ability_id == "aimed_shot" and has(choices, "marksman", 2):
			skill.skillCastTime = 0.7
		if skill.ability_id == "poison_arrow" and has(choices, "venom", 2):
			skill.data.duration = 10
			skill.skillDotSeconds = 10
		if skill.ability_id == "consecration" and has(choices, "bulwark", 2):
			skill.data.radius = 185
		if skill.ability_id == "field_beacon" and has(choices, "safeguard", 1):
			skill.skillManaCost = 0
			skill.data.duration = 6
		if skill.ability_id == "overload" and has(choices, "workshop", 3):
			skill.data.radius = 135
		if skill.ability_id == "steel_step" and has(choices, "duelist", 2):
			skill.skillCoolDownTime = 8
		if skill.ability_id == "blade_guard" and has(choices, "duelist", 1):
			skill.data.power = 32
		if skill.ability_id == "blade_dance" and has(choices, "frenzy", 3):
			skill.data.power = 8
	# Each tooltip lists only the selected effects that can affect this skill.
	var effects = PackedStringArray()
	var hero_class = ""
	for candidate in TREES:
		for branch in TREES[candidate]:
			if choices.has(branch):
				hero_class = candidate
	for branch in branches(hero_class):
		for tier in int(choices.get(branch, 0)):
			var node = TREES[hero_class][branch].nodes[tier]
			var affects = str(node[1]).contains(skill.skillName)
			if branch == "affliction" and tier == 0 and skill is DamageOverTime:
				affects = true
			if branch == "light" and tier == 0 and skill is HeroAbility and skill.ability_id in ["holy_light", "consecration", "divine_dawn"]:
				affects = true
			if branch == "marksman" and tier == 2:
				affects = true
			if affects:
				effects.append(str(node[1]))
	skill.talent_description = "\nTalentos: " + " ".join(effects) if not effects.is_empty() else ""

static func skill_damage(choices: Dictionary, skill: Skill) -> float:
	if skill is ShadowBolt and has(choices, "destruction", 1):
		return 1.25
	if skill is HeroAbility:
		match skill.ability_id:
			"twin_cross": return 1.25 if has(choices, "frenzy", 1) else 1.0
			"soul_reap": return 1.25 if has(choices, "destruction", 3) else 1.0
			"cleave": return 1.25 if has(choices, "berserker", 1) else 1.0
			"bladestorm": return 1.25 if has(choices, "berserker", 3) else 1.0
			"aimed_shot": return 1.25 if has(choices, "marksman", 1) else 1.0
			"arrow_rain": return 1.2 if has(choices, "venom", 3) else 1.0
	return 1.0
