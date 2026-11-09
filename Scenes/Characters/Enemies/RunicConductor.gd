class_name RunicConductor
extends Character

const MAX_HEALTH = 80

@onready var rune: AnimatedSprite2D = $AnimatedSprite2D

func _enter_tree() -> void:
	# The encounter synchronizes both conductors together, including their presence.
	charName = "Condutor Rúnico"
	charTeam = Teams.RED
	charTotalLife = MAX_HEALTH

func _ready() -> void:
	portrait_icon = rune.sprite_frames.get_frame_texture("orb", 0)
	set_physics_process(false)
	set_process(false)

func _exit_tree() -> void:
	var id = int(name)
	if MultiplayerManager.enemies.get(id) == self:
		MultiplayerManager.enemies.erase(id)

func apply_health(value: int) -> void:
	charCurrentLife = value
	var active = charCurrentLife > 0
	var id = int(name)
	if active != visible:
		visible = active
		input_pickable = active
		set_process(active)
		if active:
			MultiplayerManager.enemies[id] = self
			flash_time = 0
			rune.play("orb")
		else:
			MultiplayerManager.enemies.erase(id)
			rune.stop()
			for effect in debuffList:
				if is_instance_valid(effect):
					effect.queue_free()
			debuffList.clear()
	queue_redraw()

func deal_damage(damage: int, source: Character = null, periodic: bool = false, skill_multiplier: float = 1.0) -> void:
	var before = charCurrentLife
	super.deal_damage(damage, source, periodic, skill_multiplier)
	if charCurrentLife != before:
		get_parent().conductor_damaged(self)

func _draw() -> void:
	draw_arc(Vector2.ZERO, 39, 0, TAU, 48, Color("dfb7ff"), 3, true)
	draw_rect(Rect2(-31, 43, 62, 8), Color("23182d"))
	draw_rect(Rect2(-29, 45, 58.0 * charCurrentLife / MAX_HEALTH, 4), Color("dfb7ff"))
