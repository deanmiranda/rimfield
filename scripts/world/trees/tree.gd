@tool
extends Node2D

# Tree - Reusable tree scene with type and growth stage support

enum TreeType {
	MAPLE,
	OAK,
	PINE
}

enum TreeStage {
	SAPLING,
	MID,
	ADULT,
	FULLY_GROWN
}

const TILE_SIZE: int = 16

const STAGE_SIZE_TILES := {
	TreeStage.SAPLING: Vector2i(1, 1),
	TreeStage.MID: Vector2i(1, 1),
	TreeStage.ADULT: Vector2i(2, 2), # Phase 1.5 temporary until real adult art is provided
	TreeStage.FULLY_GROWN: Vector2i(2, 2),
}

const STAGE_ORIGINS := {
	TreeStage.SAPLING: {
		TreeType.MAPLE: Vector2i(8, 432),
		TreeType.OAK: Vector2i(40, 432),
		TreeType.PINE: Vector2i(72, 432),
	},
	TreeStage.MID: {
		# Phase 1.5 placeholder: use sapling origins for now (same size 1x1)
		TreeType.MAPLE: Vector2i(8, 432),
		TreeType.OAK: Vector2i(40, 432),
		TreeType.PINE: Vector2i(72, 432),
	},
	TreeStage.ADULT: {
		# Phase 1.5 placeholder: use fully grown origins BUT only after ensuring size matches
		TreeType.MAPLE: Vector2i(0, 24),
		TreeType.OAK: Vector2i(2, 24),
		TreeType.PINE: Vector2i(4, 24),
	},
	TreeStage.FULLY_GROWN: {
		TreeType.MAPLE: Vector2i(0, 24),
		TreeType.OAK: Vector2i(2, 24),
		TreeType.PINE: Vector2i(4, 24),
	},
}

var _tree_type: TreeType = TreeType.MAPLE
@export var tree_type: TreeType = TreeType.MAPLE:
	get:
		return _tree_type
	set(value):
		if _tree_type != value:
			_tree_type = value
			_apply_visuals()

var _growth_stage: TreeStage = TreeStage.SAPLING
@export var growth_stage: TreeStage = TreeStage.SAPLING:
	get:
		return _growth_stage
	set(value):
		if _growth_stage != value:
			_growth_stage = value
			_apply_visuals()

@export var grid_position: Vector2i = Vector2i(-1, -1) # Optional metadata, -1 means not set

@onready var sprite: Sprite2D = $TreeSprite


func _ready() -> void:
	_apply_visuals()


func _apply_visuals() -> void:
	# Update sprite region based on tree type and growth stage
	if not sprite:
		return
	
	# Ensure texture is assigned
	if sprite.texture == null:
		sprite.texture = load("res://assets/tilesets/full version/tiles/tiles.png")
	
	# Force region enabled
	sprite.region_enabled = true
	
	# Ensure sprite is not centered (for proper anchoring)
	sprite.centered = false
	
	# Compute region rect
	var origin: Vector2i = _get_atlas_origin_for(tree_type, growth_stage)
	var size_tiles: Vector2i = STAGE_SIZE_TILES.get(growth_stage, Vector2i(1, 1))
	var region_rect: Rect2 = _build_region_rect(origin, size_tiles)
	
	# Protective check for zero-size rects
	if region_rect.size.x <= 0 or region_rect.size.y <= 0:
		return
	
	sprite.region_rect = region_rect
	
	# Apply stage-based offset for trunk anchoring
	sprite.position = _get_stage_sprite_offset(size_tiles)


func _get_atlas_origin_for(type: TreeType, stage: TreeStage) -> Vector2i:
	"""Get the atlas origin coordinates for the given tree type and stage."""
	var stage_origins = STAGE_ORIGINS.get(stage, {})
	if stage_origins.has(type):
		return stage_origins[type]
	else:
		# Fallback to sapling if stage/type combo not found
		var sapling_origins = STAGE_ORIGINS.get(TreeStage.SAPLING, {})
		return sapling_origins.get(type, Vector2i.ZERO)


func _build_region_rect(origin: Vector2i, size_tiles: Vector2i) -> Rect2:
	"""Convert atlas origin and size in tiles to a region rect in pixels.
	Sapling origins are stored as pixel coordinates, fully grown as tile coordinates."""
	# Check if origin is already in pixel coordinates (sapling row at y=432)
	if origin.y >= 400:
		# Origin is already in pixels (sapling coordinates)
		return Rect2(
			origin.x,
			origin.y,
			size_tiles.x * TILE_SIZE,
			size_tiles.y * TILE_SIZE
		)
	else:
		# Origin is in tile coordinates (fully grown)
		return Rect2(
			origin.x * TILE_SIZE,
			origin.y * TILE_SIZE,
			size_tiles.x * TILE_SIZE,
			size_tiles.y * TILE_SIZE
		)


func _get_stage_sprite_offset(size_tiles: Vector2i) -> Vector2:
	"""Get sprite offset for trunk-tile anchoring.
	The Tree node position is the trunk/spawn tile.
	We want the sprite:
	- horizontally centered over trunk tile (for 2x2)
	- baseline aligned so trunk sits on the tile"""
	if size_tiles == Vector2i(1, 1):
		return Vector2(-TILE_SIZE / 2, -TILE_SIZE) # small sprite sits on tile
	elif size_tiles == Vector2i(2, 2):
		# Place sprite so its bottom center aligns with trunk tile.
		# This may need minor tuning later.
		return Vector2(-TILE_SIZE, -TILE_SIZE * 2)
	else:
		return Vector2(-TILE_SIZE / 2, -TILE_SIZE)


func get_tree_type() -> TreeType:
	"""Get the tree type."""
	return tree_type


func get_growth_stage() -> TreeStage:
	"""Get the growth stage."""
	return growth_stage


func get_grid_position() -> Vector2i:
	"""Get the grid position metadata."""
	return grid_position


func set_tree_type(new_type: TreeType) -> void:
	"""Set the tree type and update visuals."""
	_tree_type = new_type
	_apply_visuals()


func set_growth_stage(new_stage: TreeStage) -> void:
	"""Set the growth stage and update visuals."""
	_growth_stage = new_stage
	_apply_visuals()


func set_grid_position(new_position: Vector2i) -> void:
	"""Set the grid position metadata."""
	grid_position = new_position
