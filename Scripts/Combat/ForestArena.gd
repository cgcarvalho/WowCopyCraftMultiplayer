extends Node

const ORIGINAL_CELLS = Vector2i(72, 40)
const INSERT_AT = Vector2i(56, 32)

func _ready() -> void:
	var grass: TileMapLayer = $Grass
	var size_in_cells = Vector2i(ArenaNavigation.WORLD_SIZE / Vector2(grass.tile_set.tile_size))
	var extra = size_in_cells - ORIGINAL_CELLS
	var bounds = grass.get_used_rect()
	var original: Dictionary = {}
	for cell in grass.get_used_cells():
		original[cell] = [grass.get_cell_source_id(cell), grass.get_cell_atlas_coords(cell), grass.get_cell_alternative_tile(cell)]
	grass.clear()
	# Extend flat strips after both trees; retain the painted shoreline and obstacles.
	for y in range(bounds.position.y, bounds.end.y + extra.y):
		for x in range(bounds.position.x, bounds.end.x + extra.x):
			var source = Vector2i(source_axis(x, INSERT_AT.x, extra.x), source_axis(y, INSERT_AT.y, extra.y))
			if original.has(source):
				var tile: Array = original[source]
				grass.set_cell(Vector2i(x, y), tile[0], tile[1], tile[2])
	# Overscan water also fills taller/wider windows outside the island.
	var water: TileMapLayer = $Water
	for y in range(-32, size_in_cells.y + 32):
		for x in range(-32, size_in_cells.x + 32):
			water.set_cell(Vector2i(x, y), 0, Vector2i(posmod(x, 4), posmod(y, 4)))

func source_axis(value: int, insertion: int, extra: int) -> int:
	if value < insertion:
		return value
	if value >= insertion + extra:
		return value - extra
	return insertion + posmod(value - insertion, 4)
