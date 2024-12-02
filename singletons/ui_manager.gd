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

@onready var inventory_scene = preload("res://scenes/ui/inventory_scene.tscn")  # Path to the inventory scene

# Reference to the inventory instance
var inventory_instance: Control = null

func _ready() -> void:

	# Farming logic setup
	GameState.connect("game_loaded", Callable(self, "_on_game_loaded"))  # Proper Callable usage
	_load_farm_state()  # Also run on initial entry
	instantiate_inventory()  # Call inventory instantiation
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

# Function to instantiate the inventory scene globally
func instantiate_inventory() -> void:
	if inventory_instance:  # Prevent duplicates
		print("returning because inventory_instance already exists.");
		return
	var inventory_scene_instance = load("res://scenes/ui/inventory_scene.tscn")
	if inventory_scene_instance is PackedScene:
		inventory_instance = inventory_scene_instance.instantiate()
		print("Current self:", self.name)
		add_child(inventory_instance)  # Add inventory instance to UiManager (just like pause menu)
		inventory_instance.visible = false  # Make it hidden by default

		# Set layout properties for proper anchoring and centering
		inventory_instance.anchor_left = 0.5
		inventory_instance.anchor_right = 0.5
		inventory_instance.anchor_top = 0.5
		inventory_instance.anchor_bottom = 0.5
		inventory_instance.offset_left = -200
		inventory_instance.offset_top = -200
		inventory_instance.offset_right = 200
		inventory_instance.offset_bottom = 200

		print("Inventory instance successfully instantiated and added to UiManager.")
	else:
		print("Error: Failed to instantiate inventory scene.")

func toggle_inventory() -> void:
	if not inventory_instance:
		print("Error: Inventory instance not found.")
		return

	inventory_instance.visible = not inventory_instance.visible

	if inventory_instance.visible:
		print("Inventory opened.")
	else:
		print("Inventory closed.")

	_debug_inventory_info()  # Print inventory information after toggling

# Helper function to check if we're in a game scene
func is_in_game_scene() -> bool:
	# Assuming game scenes start with "farm_", adjust as per your project convention
	var current_scene = get_tree().current_scene
	return current_scene and current_scene.name.begins_with("farm_")

func _input(event: InputEvent) -> void:
	# Only handle input if in-game scene
	if is_in_game_scene():
		# Handle ESC key input specifically in farm_scene
		if event.is_action_pressed("ui_cancel"):
			toggle_pause_menu()

		# Handle 'i' input to toggle inventory
		if event.is_action_pressed("ui_inventory"):
			print("Input detected: 'i' pressed - attempting to toggle inventory.")
			toggle_inventory()

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
	print("game loaded")
		
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


# Helper function to add the inventory instance to UiManager
func _add_inventory_instance() -> void:
	if inventory_instance:
		var ui_manager = get_node("/root/UiManager")  # Explicitly get UiManager node
		if ui_manager:
			ui_manager.add_child(inventory_instance)  # Add inventory as a child to UiManager
			_center_inventory_instance()
			inventory_instance.visible = false  # Make sure it starts off hidden
			print("Inventory instance added to UiManager.")

			# Debug: Print out children of UiManager to confirm addition
			print("--- UiManager Children ---")
			for child in ui_manager.get_children():
				print("Child: ", child.name)
			print("--------------------------")


# Function to center the inventory instance on the screen
func _center_inventory_instance() -> void:
	if inventory_instance:
		inventory_instance.set_position(Vector2(0, 0))
		print("Inventory centered on screen.")

# Force inventory to update visibility properly
func force_update_visibility() -> void:
	if inventory_instance:
		inventory_instance.show() if inventory_instance.visible else inventory_instance.hide()

# Debug function to print inventory information
func _debug_inventory_info() -> void:
	if inventory_instance:
		print("--- Inventory Debug Info ---")
		print("Visible: ", inventory_instance.visible)
		print("Position: ", inventory_instance.position)
		print("Minimum Size: ", inventory_instance.get_minimum_size())
		print("Parent Node: ", inventory_instance.get_parent())
		print("Anchors: ", inventory_instance.anchor_left, inventory_instance.anchor_right, inventory_instance.anchor_top, inventory_instance.anchor_bottom)
		print("Offsets: ", inventory_instance.offset_left, inventory_instance.offset_right, inventory_instance.offset_top, inventory_instance.offset_bottom)
		print("----------------------------")
