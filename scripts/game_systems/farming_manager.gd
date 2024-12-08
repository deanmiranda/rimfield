### farming_manager.gd ###
extends Node

@export var farmable_layer_path: NodePath
@export var farm_scene_path: NodePath  # Reference the farm scene
var hud_instance: Node
var hud_path: Node
var farmable_layer: TileMapLayer
var tool_switcher: Node
const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2
const TILE_ID_PLANTED = 3
const TILE_ID_GROWN = 4  # Assuming "grown" is the next state after planting

var current_tool: String = "hoe"  # Default starting tool

func _ready() -> void:
	# Get the farmable layer for tile interactions
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer
		if not farmable_layer:
			print("Error: Farmable layer not found!")
	 
func set_hud(hud_instance: Node) -> void:
	hud_path = hud_instance
	tool_switcher = hud_instance.get_node("ToolSwitcher")
	
	if tool_switcher:
		# Connect the tool_changed signal
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
		
		# Ensure a valid tool is set on load
		var first_slot_tool = tool_switcher.get("current_tool")
	else:
		print("Error: ToolSwitcher not found as a child of HUD.")



func _on_tool_changed(slot_index: int, item_texture: Texture, tool_name: String = "unknown") -> void:
	if item_texture:
		# Dynamically map the tool name using texture or metadata
		current_tool = tool_name
	else:
		print("Error: Tool texture is null. Cannot update tool.")

func _get_tool_name_from_texture(item_texture: Texture) -> String:
	var tool_map = {
		preload("res://assets/tiles/tools/shovel.png"): "hoe",
		preload("res://assets/tiles/tools/rototiller.png"): "till",
		preload("res://assets/tiles/tools/pick-axe.png"): "pickaxe",
		preload("res://assets/tilesets/full version/tiles/FartSnipSeeds.png"): "seed"
	}
	return tool_map.get(item_texture, "unknown")  # Default to "unknown" if not found

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	
	if not farmable_layer:
		#print("Farmable layer is null.")
		return

	var target_cell = farmable_layer.local_to_map(target_pos)
	#print("Target cell:", target_cell)

	if target_cell.distance_to(farmable_layer.local_to_map(player_pos)) > 1.5:
		#print("Target cell too far from player.")
		return

	var tile_data = farmable_layer.get_cell_tile_data(target_cell)
	#if tile_data:
		#print("Tile data found for cell:", target_cell)
		##print("Custom data:", tile_data.get_custom_data())
	#else:
		##print("No tile data found for cell:", target_cell)
		#return

	if tile_data:
		var is_grass = tile_data.get_custom_data("grass") == true
		var is_dirt = tile_data.get_custom_data("dirt") == true
		var is_tilled = tile_data.get_custom_data("tilled") == true
		#print("Tile states - Grass:", is_grass, "Dirt:", is_dirt, "Tilled:", is_tilled)
		
		match current_tool:
			"hoe":
				if is_grass:
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
			"till":
				if is_dirt:
					_set_tile_custom_state(target_cell, TILE_ID_TILLED, "tilled")
			"pickaxe":
				if is_tilled or is_dirt:
					_set_tile_custom_state(target_cell, TILE_ID_GRASS, "grass")
			"seed":
				if is_tilled:  # Only allow planting on tilled soil
					_set_tile_custom_state(target_cell, TILE_ID_PLANTED, "planted")
					#_start_growth_cycle(target_cell)

func _get_emitter_scene(state: String) -> Resource:
	# Fetch the correct emitter based on the state
	var farm_scene = get_node_or_null(farm_scene_path)
	if farm_scene:
		match state:
			"dirt":
				return farm_scene.dirt_emitter_scene
			"tilled":
				return farm_scene.tilled_emitter_scene
			"grass":
				return farm_scene.grass_emitter_scene
	return null

func _trigger_dust_at_tile(cell: Vector2i, emitter_scene: Resource) -> void:
	var farm_scene = get_node_or_null(farm_scene_path)
	if farm_scene and farm_scene.has_method("trigger_dust"):
		farm_scene.trigger_dust(cell, emitter_scene)

func _set_tile_custom_state(cell: Vector2i, tile_id: int, _state: String) -> void:
	#print("Setting tile state at:", cell, "to state:", _state, "with tile_id:", tile_id)

	# Update the visual state
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0))

	# Update the GameState for persistence
	if GameState:
		GameState.update_tile_state(cell, _state)
	else:
		print("Error: GameState is null!")

	# Trigger the corresponding emitter for the updated state
	var emitter_scene = _get_emitter_scene(_state)
	if emitter_scene:
		_trigger_dust_at_tile(cell, emitter_scene)
