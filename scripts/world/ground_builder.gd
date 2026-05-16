extends TileMapLayer
## Fills the play area with uniform grass tiles from FLOORS.png. The dirt
## farmyard is a separate soft-edged DirtPatch sprite layered on top — a tiled
## dirt region produces a hard staircase edge, so the dirt is painted instead.
## Visual-only, no collision. Attach as the first child of a y-sorted World.

@export var paint_from: Vector2i = Vector2i(-4, -4)
@export var paint_to: Vector2i = Vector2i(44, 26)

const FLOORS_PATH := "res://assets/sprites/tileset/FLOORS.png"
const GRASS := Vector2i(1, 9)

var _source_id: int = -1


func _ready() -> void:
	var tex: Texture2D = load(FLOORS_PATH)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(32, 32)
	src.create_tile(GRASS)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	_source_id = ts.add_source(src)
	tile_set = ts
	for r in range(paint_from.y, paint_to.y + 1):
		for c in range(paint_from.x, paint_to.x + 1):
			set_cell(Vector2i(c, r), _source_id, GRASS)
