@tool
extends EditorScript

# Auto-tag farming tiles using color detection
# Scans tilesheet and creates FarmingTerrain.tres with terrain assignments

func _run():
	print("[AUTOTAG] Starting farming tiles auto-tagging...")
	
	# Load tilesheet texture
	var tex_path = "res://assets/tilesets/full version/tiles/tiles.png"
	var tex = load(tex_path) as Texture2D
	
	if tex == null:
		print("[AUTOTAG] ERROR: Failed to load texture: ", tex_path)
		return
	
	var img = tex.get_image()
	if img == null:
		print("[AUTOTAG] ERROR: Failed to get image from texture")
		return
	
	var tile_size = 16
	var width = img.get_width()
	var height = img.get_height()
	var tiles_x = width / tile_size
	var tiles_y = height / tile_size
	
	print("[AUTOTAG] Texture size: %dx%d" % [width, height])
	print("[AUTOTAG] Tile size: %dx%d" % [tile_size, tile_size])
	print("[AUTOTAG] Grid: %dx%d tiles" % [tiles_x, tiles_y])
	
	# Classify tiles by color
	var grass_tiles: Array[Vector2i] = []
	var soil_tiles: Array[Vector2i] = []
	var wetsoil_tiles: Array[Vector2i] = []
	
	for y in range(tiles_y):
		for x in range(tiles_x):
			# Restrict scanning to farming region: x in 0..11, y in 0..15
			if x > 11 or y > 15:
				continue
			
			var tile_x = x * tile_size
			var tile_y = y * tile_size
			var region = Rect2i(tile_x, tile_y, tile_size, tile_size)
			var tile_img = img.get_region(region)
			
			# Skip completely transparent/empty tiles
			if _is_tile_empty(tile_img):
				continue
			
			var avg_color = _get_average_color(tile_img)
			var terrain_type = _classify_tile(avg_color)
			
			var atlas_coords = Vector2i(x, y)
			if terrain_type == "grass":
				grass_tiles.append(atlas_coords)
			elif terrain_type == "soil":
				soil_tiles.append(atlas_coords)
			elif terrain_type == "wetsoil":
				wetsoil_tiles.append(atlas_coords)
	
	print("[AUTOTAG] Classification complete:")
	print("[AUTOTAG]   Grass tiles: %d" % grass_tiles.size())
	print("[AUTOTAG]   Soil tiles: %d" % soil_tiles.size())
	print("[AUTOTAG]   WetSoil tiles: %d" % wetsoil_tiles.size())
	
	# Create new TileSet resource
	var tileset = TileSet.new()
	
	# Create terrain set (terrain set 0)
	var terrain_set_id = 0
	tileset.add_terrain_set(terrain_set_id)
	tileset.set_terrain_set_mode(terrain_set_id, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	
	# Add terrains
	tileset.add_terrain(terrain_set_id, 0)
	tileset.set_terrain_name(terrain_set_id, 0, "Grass")
	tileset.set_terrain_color(terrain_set_id, 0, Color(0.2, 0.8, 0.2, 1))
	
	tileset.add_terrain(terrain_set_id, 1)
	tileset.set_terrain_name(terrain_set_id, 1, "Soil")
	tileset.set_terrain_color(terrain_set_id, 1, Color(0.6, 0.4, 0.2, 1))
	
	tileset.add_terrain(terrain_set_id, 2)
	tileset.set_terrain_name(terrain_set_id, 2, "WetSoil")
	tileset.set_terrain_color(terrain_set_id, 2, Color(0.4, 0.3, 0.15, 1))
	
	# Create TileSetAtlasSource
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = tex
	atlas_source.texture_region_size = Vector2i(tile_size, tile_size)
	
	# Add source to tileset
	var source_id = tileset.add_source(atlas_source, 0)
	
	# Assign terrains to tiles
	print("[AUTOTAG] Assigning terrains to tiles...")
	
	# Assign Grass tiles (terrain 0)
	for coords in grass_tiles:
		# Create tile at coordinates
		atlas_source.create_tile(coords)
		var tile_data = atlas_source.get_tile_data(coords, 0)
		if tile_data:
			tile_data.set_terrain_set(terrain_set_id)
			tile_data.set_terrain(0)
	
	# Assign Soil tiles (terrain 1)
	for coords in soil_tiles:
		atlas_source.create_tile(coords)
		var tile_data = atlas_source.get_tile_data(coords, 0)
		if tile_data:
			tile_data.set_terrain_set(terrain_set_id)
			tile_data.set_terrain(1)
	
	# Assign WetSoil tiles (terrain 2)
	for coords in wetsoil_tiles:
		atlas_source.create_tile(coords)
		var tile_data = atlas_source.get_tile_data(coords, 0)
		if tile_data:
			tile_data.set_terrain_set(terrain_set_id)
			tile_data.set_terrain(2)
	
	# Save TileSet resource
	var output_path = "res://assets/tilesets/FarmingTerrain.tres"
	var error = ResourceSaver.save(tileset, output_path)
	
	if error != OK:
		print("[AUTOTAG] ERROR: Failed to save TileSet: ", error)
		return
	
	print("[AUTOTAG] TileSet saved to: ", output_path)
	print("[AUTOTAG] ========================================")
	print("[AUTOTAG] SUMMARY:")
	print("[AUTOTAG]   Grass tiles (%d): " % grass_tiles.size(), grass_tiles)
	print("[AUTOTAG]   Soil tiles (%d): " % soil_tiles.size(), soil_tiles)
	print("[AUTOTAG]   WetSoil tiles (%d): " % wetsoil_tiles.size(), wetsoil_tiles)
	print("[AUTOTAG] ========================================")

func _is_tile_empty(img: Image) -> bool:
	"""Check if tile is completely transparent/empty"""
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			if img.get_pixel(x, y).a > 0.1:
				return false
	return true

func _get_average_color(img: Image) -> Color:
	"""Calculate average color of an image, ignoring transparent pixels"""
	var r = 0.0
	var g = 0.0
	var b = 0.0
	var count = 0
	
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var pixel = img.get_pixel(x, y)
			if pixel.a > 0.1: # Only count non-transparent pixels
				r += pixel.r
				g += pixel.g
				b += pixel.b
				count += 1
	
	if count > 0:
		return Color(r / count, g / count, b / count, 1.0)
	return Color.BLACK

func _classify_tile(color: Color) -> String:
	"""Classify tile based on color heuristics"""
	var r = color.r
	var g = color.g
	var b = color.b
	
	# Calculate average values
	var avg_red_green = (r + g) / 2.0
	var brightness = (r + g + b) / 3.0
	
	# Calculate saturation
	var max_component = max(r, max(g, b))
	var min_component = min(r, min(g, b))
	var saturation = 0.0
	if max_component > 0.0:
		saturation = (max_component - min_component) / max_component
	
	# Rule 1: Grass - green channel > both red and blue
	if g > r and g > b and g > 0.2:
		return "grass"
	
	# Rule 2: Soil - red and green > blue, low saturation (brown/tan)
	if avg_red_green > b and saturation < 0.5:
		# Rule 3: WetSoil - soil but darker
		if brightness < 0.4:
			return "wetsoil"
		else:
			return "soil"
	
	# Fallback classification
	# If somewhat green, likely grass
	if g > 0.25 and g > r * 0.8:
		return "grass"
	# Otherwise, classify as soil (most common fallback)
	return "soil"
