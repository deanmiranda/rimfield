extends Node2D

@export var tilemap_layer: NodePath  # Reference the TileMapLayer node
@export var grass_emitter_scene: Resource
@export var tilled_emitter_scene: Resource
@export var dirt_emitter_scene: Resource
@export var cell_size: Vector2 = Vector2(16, 16)  # Define the size of each cell manually or export for flexibility
@export var debug_disable_dust: bool = true  # Toggle to disable dust emitter
@export var farming_manager_path: NodePath  # farming_manager path

var hud_instance: Node
var pause_menu: Control
var paused = false
var hud_scene_path = preload("res://scenes/ui/hud.tscn")

# Reference to the inventory instance
var inventory_instance: Control = null

func _ready() -> void:
	# Locate the PlayerSpawnPoint node
	var spawn_point = $PlayerSpawnPoint
	if not spawn_point:
		print("Error: PlayerSpawnPoint node not found!")
		return

	# Instantiate and position the player
	var player_scene = preload("res://scenes/characters/player/player.tscn")
	var player_instance = player_scene.instantiate()
	add_child(player_instance)
	player_instance.global_position = spawn_point.global_position  # Use spawn point position

	# Farming logic setup
	GameState.connect("game_loaded", Callable(self, "_on_game_loaded"))  # Proper Callable usage
	_load_farm_state()  # Also run on initial entry

	# Inventory setup
	if UiManager:
		UiManager.instantiate_inventory()
	else:
		print("Error: UiManager singleton not found.")

	# Pause menu setup
	var pause_menu_scene = load("res://scenes/ui/pause_menu.tscn")
	if pause_menu_scene is PackedScene:
		var pause_menu_layer = pause_menu_scene.instantiate()
		add_child(pause_menu_layer)
		# Get the Control child from the CanvasLayer
		pause_menu = pause_menu_layer.get_node("Control")
		pause_menu.visible = false
	else:
		print("Error: Failed to load PauseMenu scene.")

	var farming_manager = $FarmingManager 
	# Instantiate and add the HUD
	if hud_scene_path:
		hud_instance = hud_scene_path.instantiate()
		add_child(hud_instance)
		# Pass HUD instance to the farming manager
		if farming_manager and hud_instance:
			if HUD:
				HUD.set_farming_manager(farming_manager)  # Link FarmingManager to HUD
				HUD.set_hud_scene_instance(hud_instance)  # Inject HUD scene instance to cache references (replaces /root/... paths)
				farming_manager.set_hud(hud_instance)  # Link HUD to FarmingManager
			else:
				print("Error: hud_instance is not an instance of HUD script.")
		else:
			print("Error: Could not link FarmingManager and HUD.")
	else:
		print("Error: HUD scene not assigned!")

	# Spawn a test droppable
	spawn_random_droppables(40)  # Spawn 10 droppables

func spawn_random_droppables(count: int) -> void:
	if not hud_instance:
		print("Error: HUD instance is null! Droppables cannot be spawned.")
		return

	for i in range(count):
		var droppable_name = _get_random_droppable_name()
		var random_position = _get_random_farm_position()
		DroppableFactory.spawn_droppable(droppable_name, random_position, hud_instance)

func _get_random_droppable_name() -> String:
	var droppable_names = ["carrot", "strawberry", "tomato"]  # Add more droppable types
	return droppable_names[randi() % droppable_names.size()]

func _get_random_farm_position() -> Vector2:
	var farm_area = Rect2(Vector2(0, 0), Vector2(-400, 400))  # Define the bounds of your farm
	var random_x = randi() % int(farm_area.size.x) + farm_area.position.x
	var random_y = randi() % int(farm_area.size.y) + farm_area.position.y
	return Vector2(random_x, random_y)

func _on_game_loaded() -> void:
	_load_farm_state()  # Apply loaded state when notified

func _load_farm_state() -> void:
	var farming_manager = get_node_or_null(farming_manager_path)
	if not farming_manager:
		print("Error: Farming Manager not found!")
		return

	var tilemap = get_node_or_null(tilemap_layer)
	if not tilemap:
		print("Error: TileMapLayer not found!")
		return

	for position_key in GameState.farm_state.keys():
		# Ensure position_key is a string before splitting
		var position: Vector2i
		if position_key is String:
			var components = position_key.split(",")
			position = Vector2i(components[0].to_int(), components[1].to_int())
		elif position_key is Vector2i:
			position = position_key
		else:
			print("Invalid position_key format:", position_key)
			continue

		# Get the state and set the tile
		var state = GameState.get_tile_state(position)
		match state:
			"dirt":
				tilemap.set_cell(position, farming_manager.TILE_ID_DIRT, Vector2i(0, 0))
			"tilled":
				tilemap.set_cell(position, farming_manager.TILE_ID_TILLED, Vector2i(0, 0))
			"planted":
				tilemap.set_cell(position, farming_manager.TILE_ID_PLANTED, Vector2i(0, 0))


func trigger_dust(tile_position: Vector2, emitter_scene: Resource) -> void:
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
