extends Node2D

@export var farmable_layer_path: NodePath
@export var tool_switcher_path: NodePath  # To locate ToolSwitcher in the scene
var farmable_layer: TileMapLayer  # The farmable layer to highlight on
var highlight_sprite: Sprite2D  # Visual feedback sprite

@export var highlight_texture: Texture2D
@export var highlight_color: Color = Color(1, 1, 0, 0.5)  # Semi-transparent yellow
@export var tile_size: Vector2 = Vector2(16, 16)  # Adjust to match your tile size

# Use shared ToolConfig Resource to convert texture to tool name
var tool_config: Resource = null
var current_tool: String = "unknown"  # Track current tool for debugging

func _ready() -> void:
	# Load ToolConfig Resource
	tool_config = load("res://resources/data/tool_config.tres")
	
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer

	# Locate ToolSwitcher and connect its signal to update highlighting
	if tool_switcher_path:
		var tool_switcher = get_node_or_null(tool_switcher_path) as Node
		if tool_switcher:
			if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
				tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))

	# Create and configure the highlight sprite
	highlight_sprite = Sprite2D.new()
	add_child(highlight_sprite)
	if highlight_texture:
		highlight_sprite.texture = highlight_texture
	else:
		# Create a simple colored rectangle if no texture is provided
		var image = Image.create(int(tile_size.x), int(tile_size.y), false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 0, 0.5))  # Yellow semi-transparent
		var texture = ImageTexture.create_from_image(image)
		highlight_sprite.texture = texture
	highlight_sprite.modulate = highlight_color
	highlight_sprite.visible = false
	highlight_sprite.z_index = 100

func _on_tool_changed(_slot_index: int, item_texture: Texture) -> void:
	# Signal signature matches tool_changed(slot_index: int, item_texture: Texture)
	# Convert texture to tool name using ToolConfig
	if item_texture and tool_config and tool_config.has_method("get_tool_name"):
		current_tool = tool_config.get_tool_name(item_texture)
	else:
		current_tool = "unknown"

# Cache tile size to avoid recalculating every frame
# Set to zero to force recalculation if needed
var cached_tile_size: Vector2 = Vector2.ZERO
var tile_size_initialized: bool = false

func _get_actual_tile_size() -> Vector2:
	"""Get the actual visual tile size - use texture_region_size directly (no multiplier)"""
	# Return cached value if already calculated
	if tile_size_initialized:
		return cached_tile_size
	
	if not farmable_layer:
		cached_tile_size = tile_size
		tile_size_initialized = true
		return cached_tile_size
	
	# PRIORITY 1: Get texture_region_size from TileSetAtlasSource
	# This tells us the size of each tile in the atlas (in pixels)
	var tile_set = farmable_layer.tile_set
	if tile_set == null:
		# TileSet not yet assigned - use fallback
		cached_tile_size = tile_size
		tile_size_initialized = true
		return cached_tile_size
	
	if tile_set:
		var source_count = tile_set.get_source_count()
		if source_count > 0:
			var source_id = tile_set.get_source_id(0)
			var source = tile_set.get_source(source_id)
			if source and source is TileSetAtlasSource:
				var atlas_source = source as TileSetAtlasSource
				# Get the actual texture and check if we have a tile
				if atlas_source.texture and atlas_source.has_tile(Vector2i(0, 0)):
					# Get the texture region for the first tile - this is the actual pixel size
					var tile_region = atlas_source.get_tile_texture_region(Vector2i(0, 0), 0)
					if tile_region.size.x > 0 and tile_region.size.y > 0:
						cached_tile_size = tile_region.size
						tile_size_initialized = true
						return cached_tile_size
				# Fallback: try texture_region_size if set
				var atlas_size = atlas_source.texture_region_size
				if atlas_size.x > 0 and atlas_size.y > 0:
					cached_tile_size = atlas_size
					tile_size_initialized = true
					return cached_tile_size
				# Last resort for atlas: use full texture size
				if atlas_source.texture:
					var tex_size = atlas_source.texture.get_size()
					if tex_size.x > 0 and tex_size.y > 0:
						cached_tile_size = tex_size
						tile_size_initialized = true
						return cached_tile_size
	
	# FALLBACK: Measure cell spacing from adjacent cells
	# This should match the tile size if tiles don't overlap
	var tile_00_pos = farmable_layer.map_to_local(Vector2i(0, 0))
	var tile_10_pos = farmable_layer.map_to_local(Vector2i(1, 0))
	var tile_01_pos = farmable_layer.map_to_local(Vector2i(0, 1))
	
	var calculated_size_x = abs(tile_10_pos.x - tile_00_pos.x)
	var calculated_size_y = abs(tile_01_pos.y - tile_00_pos.y)
	
	if calculated_size_x > 0 and calculated_size_y > 0:
		cached_tile_size = Vector2(calculated_size_x, calculated_size_y)
		tile_size_initialized = true
		return cached_tile_size
	
	# Ultimate fallback: use the exported tile_size variable
	cached_tile_size = tile_size
	tile_size_initialized = true
	return cached_tile_size

func _process(_delta: float) -> void:
	if not farmable_layer:
		highlight_sprite.visible = false
		return

	if not highlight_sprite:
		return
	
	# Check if tile_set is available - if not, wait for it to be assigned
	var tile_set = farmable_layer.tile_set
	if tile_set == null:
		highlight_sprite.visible = false
		return

	# Restrict to viewport
	var viewport = get_viewport()
	if not viewport:
		highlight_sprite.visible = false
		return
		
	var mouse_position = MouseUtil.get_world_mouse_pos_2d(self)
	var viewport_rect = Rect2(Vector2.ZERO, viewport.size)
	if not viewport_rect.has_point(viewport.get_mouse_position()):
		highlight_sprite.visible = false
		return

	# Calculate tile position
	# IMPORTANT: mouse_position is in world coordinates (from Camera2D via MouseUtil)
	var local_mouse_position = farmable_layer.to_local(mouse_position)
	var tile_position = farmable_layer.local_to_map(local_mouse_position)
	
	# Get actual tile size from TileSet (should be visual size, e.g., 64x64)
	var actual_tile_size = _get_actual_tile_size()
	
	# IMPORTANT: map_to_local returns the CENTER of the cell, not the top-left!
	# According to Godot docs, this is the position of the center of the cell
	var tile_center_local = farmable_layer.map_to_local(tile_position)
	
	# Convert to global position for the sprite
	var tile_center_global = farmable_layer.to_global(tile_center_local)
	
	# Check if tile is within farmable layer bounds
	var used_rect = farmable_layer.get_used_rect()
	if used_rect.has_point(tile_position):
		# Scale sprite to match exact tile size
		# IMPORTANT: actual_tile_size is from map_to_local which gives cell size (16x16)
		# But tiles might render at a different visual size - we need the texture region size
		var sprite_scale = Vector2.ONE
		if highlight_sprite.texture:
			var texture_size = highlight_sprite.texture.get_size()
			if texture_size.x > 0 and texture_size.y > 0:
				# Use actual_tile_size which should match the rendered tile size
				sprite_scale = actual_tile_size / texture_size
			
		highlight_sprite.scale = sprite_scale
		
		# Position sprite at tile center (Sprite2D positions from center)
		highlight_sprite.global_position = tile_center_global
		
		highlight_sprite.visible = true
	else:
		highlight_sprite.visible = false
