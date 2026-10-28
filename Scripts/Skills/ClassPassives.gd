class_name ClassPassives
extends RefCounted

const DOT_CHANCE = 0.05
const MOMENTUM_MAX = 5
const MOMENTUM_DAMAGE = 0.03
const MOMENTUM_SECONDS = 4.0
const AURA_RADIUS = 220.0
const AURA_HEAL = 0.15
const AURA_REDUCTION = 0.05
const STEADY_SECONDS = 1.0
const STEADY_DAMAGE = 0.15
const STEADY_TALENT_DAMAGE = 0.25

static func definition(hero_class: String, talents: Dictionary = {}) -> Dictionary:
	match hero_class:
		"Warlock":
			return {"name": "Dot Master", "summary": "Ticks de DoT: %d%% de chance de liberar Shadow Bolt instantâneo." % roundi(DOT_CHANCE * 100),
				"description": "Cada tick de Corruption ou Curse of Death tem %d%% de chance de liberar seu próximo Shadow Bolt instantaneamente, mesmo durante a recarga. O bônus não acumula e só é consumido ao lançar Shadow Bolt com sucesso. O custo de mana permanece." % roundi(DOT_CHANCE * 100)}
		"Warrior":
			return {"name": "Ímpeto", "summary": "Autoataques: +%d%% de dano por acúmulo. Máx. %d; dura %.0fs." % [roundi(MOMENTUM_DAMAGE * 100), MOMENTUM_MAX, MOMENTUM_SECONDS],
				"description": "Cada acerto de autoataque concede 1 acúmulo: +%d%% em todo o dano causado. Máximo de %d acúmulos (+%d%%). Cada acerto renova a duração de %.0fs; sem acertar nesse período, todos os acúmulos são perdidos." % [roundi(MOMENTUM_DAMAGE * 100), MOMENTUM_MAX, roundi(MOMENTUM_MAX * MOMENTUM_DAMAGE * 100), MOMENTUM_SECONDS]}
		"Paladin":
			return {"name": "Aura Sagrada", "summary": "Você e aliados a até %.0f: +%d%% de cura recebida e -%d%% de dano." % [AURA_RADIUS, roundi(AURA_HEAL * 100), roundi(AURA_REDUCTION * 100)],
				"description": "Enquanto Charger estiver vivo e participando da luta, ele e aliados a até %.0f de distância recebem +%d%% de cura e sofrem %d%% menos dano. Sair do alcance remove o benefício. Auras de vários paladinos não acumulam." % [AURA_RADIUS, roundi(AURA_HEAL * 100), roundi(AURA_REDUCTION * 100)]}
		"Hunter":
			var bonus = STEADY_TALENT_DAMAGE if TalentTree.has(talents, "marksman", 3) else STEADY_DAMAGE
			return {"name": "Mira firme", "summary": "Fique parada por %.0fs para ganhar +%d%% de dano. Mover remove o bônus." % [STEADY_SECONDS, roundi(bonus * 100)],
				"description": "Após %.0fs sem se mover, Lulu causa +%d%% em todo o dano, incluindo habilidades e veneno. Mover remove o bônus e reinicia a preparação. O talento Precisão absoluta aumenta o bônus para +%d%%." % [STEADY_SECONDS, roundi(bonus * 100), roundi(STEADY_TALENT_DAMAGE * 100)]}
	return {"name": "Sem passiva", "summary": "Este personagem não possui passiva.", "description": "Este personagem não possui passiva."}

static func state(hero) -> Dictionary:
	if hero.spectator or hero.charCurrentLife <= 0:
		return {"text": "Inativa · espectador" if hero.spectator else "Inativa · personagem derrotado", "value": 0.0, "active": false}
	match hero.charClass:
		"Warlock":
			return {"text": "PRONTO · Shadow Bolt instantâneo · tecla 1" if hero.shadow_bolt_ready else "Aguardando ativação · %d%% por tick de DoT" % roundi(DOT_CHANCE * 100), "value": 1.0 if hero.shadow_bolt_ready else 0.0, "active": hero.shadow_bolt_ready}
		"Warrior":
			return {"text": "%d/%d acúmulos · +%d%% de dano · %.1fs restantes" % [hero.momentum, MOMENTUM_MAX, roundi(hero.momentum * MOMENTUM_DAMAGE * 100), hero.momentum_time] if hero.momentum > 0 else "0/%d acúmulos · acerte um autoataque para ativar" % MOMENTUM_MAX, "value": float(hero.momentum) / MOMENTUM_MAX, "active": hero.momentum > 0}
		"Paladin":
			var active = hero.has_paladin_aura()
			return {"text": "ATIVA · +%d%% cura recebida · -%d%% dano · raio %.0f" % [roundi(AURA_HEAL * 100), roundi(AURA_REDUCTION * 100), AURA_RADIUS] if active else "Inativa · fora do alcance da aura", "value": 1.0 if active else 0.0, "active": active}
		"Hunter":
			var ready = hero.steady_time >= STEADY_SECONDS
			var bonus = STEADY_TALENT_DAMAGE if TalentTree.has(hero.talents, "marksman", 3) else STEADY_DAMAGE
			return {"text": "ATIVA · +%d%% de dano · mover remove o bônus" % roundi(bonus * 100) if ready else "Preparando · %.1f/%.0fs sem mover" % [hero.steady_time, STEADY_SECONDS], "value": clampf(hero.steady_time / STEADY_SECONDS, 0, 1), "active": ready}
	return {"text": "Sem passiva", "value": 0.0, "active": false}
