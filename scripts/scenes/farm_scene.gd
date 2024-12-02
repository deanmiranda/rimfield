### Updated ui_manager.gd
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
var ui_manager = UiManager

@onready var inventory_scene = preload("res://scenes/ui/inventory_scene.tscn")  # Path to the inventory scene

# Reference to the inventory instance
var inventory_instance: Control = null

func _ready() -> void:
	# Farming logic setup
	GameState.connect("game_loaded", Callable(self, "_on_game_loaded"))  # Proper Callable usage
	_load_farm_state()  # Also run on initial entry

	# UI Manager instantiated
	instantiate_inventory()

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

	var tilemap = get_node(tilemap_layer)
	if not tilemap:
		print("Error: TileMapLayer not found!")
		return

	for position_key in GameState.farm_state.keys():
		# Convert the position_key from String to Vector2i
		var position = Vector2i(position_key.split(",")[0].to_int(), position_key.split(",")[1].to_int())

		var state = GameState.get_tile_state(position)
		match state:
			"dirt":
				tilemap.set_cell(position, farming_manager.TILE_ID_DIRT, Vector2i(0, 0))
			"tilled":
				tilemap.set_cell(position, farming_manager.TILE_ID_TILLED, Vector2i(0, 0))
			"planted":
				tilemap.set_cell(position, farming_manager.TILE_ID_PLANTED, Vector2i(0, 0))

# Function to instantiate the inventory scene globally
func instantiate_inventory() -> void:
	if inventory_instance:  # Prevent duplicates
		return

	inventory_instance = inventory_scene.instantiate()  # Create the inventory
	if inventory_instance:
		# Directly add inventory instance to the root or a known node
		get_tree().root.add_child(inventory_instance)  # Add it to the root as a fallback
		inventory_instance.visible = false  # Hidden by default
		inventory_instance.position = Vector2(0, 0)  # Explicitly set position to ensure visibility
		print("Inventory instance successfully instantiated.")
	else:
		print("Error: Failed to instantiate inventory scene!")

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
