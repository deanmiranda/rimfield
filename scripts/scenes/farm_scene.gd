extends Node2D

@export var tilemap_layer: NodePath  # Reference the TileMapLayer node
@export var grass_emitter_scene: Resource
@export var tilled_emitter_scene: Resource
@export var dirt_emitter_scene: Resource
@export var cell_size: Vector2 = Vector2(16, 16)  # Define the size of each cell manually or export for flexibility
@export var debug_disable_dust: bool = true  # Toggle to disable dust emitter
@export var farming_manager_path: NodePath  # farming_manager path

# Pause Menu specific properties
var pause_menu: Control
var paused = false

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

	# Example: Spawn a carrot at a specific position
	var droppable = DroppableFactory.spawn_droppable("carrot", Vector2(100, 200))
	if droppable:
		print("Droppable successfully spawned:", droppable.name)
	else:
		print("Error: Failed to spawn droppable.")

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
	if not pause_menu_scene:
		print("Error: Failed to load PauseMenu scene.")
		return

	if pause_menu_scene is PackedScene:
		pause_menu = pause_menu_scene.instantiate()
		add_child(pause_menu)  # Add the pause menu to this scene
		pause_menu.visible = false
		print("Pause menu added to farm_scene.")
	else:
		print("Error: Loaded resource is not a PackedScene.")

func _input(event: InputEvent) -> void:
	# Handle ESC key input specifically in farm_scene
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

	# Handle inventory toggle with "i"
	if event.is_action_pressed("ui_inventory"):
		_toggle_inventory()

func toggle_pause_menu() -> void:
	# Toggle the pause menu visibility in the gameplay scene
	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false  # Unpause the entire game
		paused = false
		print("Pause menu hidden.")
	else:
		pause_menu.show()
		get_tree().paused = true  # Pause the entire game, but leave UI active
		paused = true
		print("Pause menu shown.")

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

# Function to toggle inventory visibility
func _toggle_inventory() -> void:
	if inventory_instance:
		inventory_instance.visible = !inventory_instance.visible
		if inventory_instance.visible:
			print("Inventory opened.")
		else:
			print("Inventory closed.")

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
