extends Node2D

@export var tilemap_layer: NodePath  # Reference the TileMapLayer node
@export var grass_emitter_scene: Resource
@export var tilled_emitter_scene: Resource
@export var dirt_emitter_scene: Resource
@export var cell_size: Vector2 = Vector2(16, 16)  # Define the size of each cell manually or export for flexibility
@export var debug_disable_dust: bool = true  # Toggle to disable dust emitter
@export var farming_manager_path: NodePath # farming_manager path

func _ready():
	_load_farm_state()

func _load_farm_state():
	# Access the farming manager
	var farming_manager = get_node_or_null(farming_manager_path)
	if not farming_manager:
		print("Error: Farming Manager not found!")
		return

	# Access the tilemap layer
	var tilemap = get_node(tilemap_layer)
	
	# Iterate through saved farm states and restore tiles
	for position in GameState.farm_state.keys():
		var state = GameState.get_tile_state(position)
		match state:
			"dirt":
				tilemap.set_cell(position, farming_manager.TILE_ID_DIRT, Vector2i(0, 0))
			"tilled":
				tilemap.set_cell(position, farming_manager.TILE_ID_TILLED, Vector2i(0, 0))
			"planted":
				tilemap.set_cell(position, farming_manager.TILE_ID_PLANTED, Vector2i(0, 0))



func trigger_dust(tile_position: Vector2, emitter_scene: Resource):

	var particle_emitter = emitter_scene.instantiate()
	add_child(particle_emitter)

	# Ensure particles render on top
	particle_emitter.z_index = 100
	particle_emitter.z_as_relative = true

	var tile_world_position = tile_position * cell_size + cell_size / 2
	particle_emitter.global_position = tile_world_position
	particle_emitter.emitting = true

	await get_tree().create_timer(particle_emitter.lifetime).timeout
	particle_emitter.queue_free()
