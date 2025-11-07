extends Node2D

# Reference variables for resources and inventory instance
var grass_emitter_scene: PackedScene = preload("res://scenes/effects/particles/grass_particle.tscn")
var tilled_emitter_scene: PackedScene = preload("res://scenes/effects/particles/tilled_particle.tscn")
var dirt_emitter_scene: PackedScene = preload("res://scenes/effects/particles/dirt_particle.tscn")
var cell_size: Vector2 = Vector2(16, 16)  # Define the size of each cell manually for flexibility
var debug_disable_dust: bool = true  # Toggle to disable dust emitter

# Pause Menu specific properties
var pause_menu: Control
var paused = false
signal scene_changed(new_scene_name: String)

@onready var inventory_scene = preload("res://scenes/ui/inventory_scene.tscn")  # Path to the inventory scene
var inventory_instance: Control = null  # Reference to the inventory instance

var last_scene_name: String = ""

func _ready() -> void:
	update_input_processing()
	# Use timer instead of per-frame polling (more efficient than _process())
	# Check scene changes every 0.1 seconds instead of every frame
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_check_scene_change)
	timer.autostart = true
	add_child(timer)
	set_process(false)  # Disable per-frame polling
	
	instantiate_inventory()  # Call inventory instantiation
	pause_menu_setup()
	set_process_input(true)  # Ensure UiManager can process global inputs
	
	# Check initial scene
	var current_scene = get_tree().current_scene
	if current_scene:
		last_scene_name = current_scene.name
	
	# Validation check for paths and resources
	#validate_paths_and_resources()

func _check_scene_change() -> void:
	# Timer-based scene change detection (replaces per-frame _process() polling)
	var current_scene = get_tree().current_scene
	if current_scene:
		var current_scene_name = current_scene.name
		if current_scene_name != last_scene_name:
			last_scene_name = current_scene_name
			update_input_processing()
			emit_signal("scene_changed", current_scene_name)
			
# Function to instantiate the inventory scene globally
func instantiate_inventory() -> void:
	if inventory_instance:  # Prevent duplicates
		if inventory_instance.get_parent():  # Already added to the scene tree
			return

	if inventory_scene is PackedScene:
		inventory_instance = inventory_scene.instantiate()
		add_child(inventory_instance)  # Add inventory instance to UI Manager
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

		# Set the inventory_instance in InventoryManager
		InventoryManager.set_inventory_instance(inventory_instance)

		# Populate with test items
		#populate_test_inventory_items()
	else:
		print("Error: Failed to instantiate inventory scene!")

#func populate_test_inventory_items() -> void:
	#var slots = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	#if not slots:
		#return
#
	#var shovel_texture = preload("res://assets/tiles/tools/shovel.png")  # Example texture path
	#for slot in slots.get_children():
		#if slot is TextureButton and slot.slot_index == 1:  # First slot has `slot_index: 1`
			#slot.set_item(shovel_texture)
	#


# Debugging all slots in inventory
#func debug_all_slots() -> void:
	#var slots = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	#if not slots:
		#print("Error: GridContainer not found in inventory instance.")
		#return
#
	#for slot in slots.get_children():
		#if slot is TextureButton:
			#print("Slot", slot.slot_index, "item_texture:", slot.item_texture)

func pause_menu_setup() -> void:
		# Pause menu setup
	var pause_menu_scene = load("res://scenes/ui/pause_menu.tscn")
	if not pause_menu_scene:
		print("Error: Failed to load PauseMenu scene.")
		return

	if pause_menu_scene is PackedScene:
		var pause_menu_layer = pause_menu_scene.instantiate()
		add_child(pause_menu_layer)  # Add the CanvasLayer to this scene
		# Get the Control child from the CanvasLayer
		pause_menu = pause_menu_layer.get_node("Control")
		pause_menu.visible = false
	else:
		print("Error: Loaded resource is not a PackedScene.")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if inventory_instance and inventory_instance.visible:
			toggle_inventory()  # Close inventory first
		elif pause_menu and not pause_menu.visible:
			toggle_pause_menu()  # Open pause menu if inventory is closed
		elif pause_menu and pause_menu.visible:
			toggle_pause_menu()  # Close pause menu

	elif event.is_action_pressed("ui_inventory"):
		toggle_inventory()

# Function to toggle pause menu visibility
func toggle_pause_menu() -> void:
	# Toggle the pause menu visibility in the gameplay scene
	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false  # Unpause the entire game
		paused = false
	else:
		pause_menu.show()
		get_tree().paused = true  # Pause the entire game, but leave UI active
		paused = true

# Function to toggle inventory visibility
func toggle_inventory() -> void:
	if inventory_instance:
		inventory_instance.visible = !inventory_instance.visible

# Function to validate paths and resources
func validate_paths_and_resources() -> void:
	if not inventory_scene:
		print("Warning: Inventory scene is not assigned properly.")

## Enhanced debugging function with null checks and robust output
#func _debug_inventory_info() -> void:
	#if not inventory_instance:
		#print("Error: Inventory instance is null. Cannot perform debug.")
		#return
#
	## Using global transform to better inspect positioning
	#if inventory_instance.get_parent():
		#print("Inventory Global Position:", inventory_instance.get_global_transform().origin)
		#print("Inventory Size:", inventory_instance.get_rect().size)
#
	## Checking Parent Node Status
	#var parent = inventory_instance.get_parent()
	#if parent:
		#print("Parent Node: ", parent.name)
	#else:
		#print("Warning: Inventory instance has no parent assigned.")
#
	## Checking Each Slot in Inventory for Debugging Purposes
	#var slots = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	#if slots:
		#for slot in slots.get_children():
			#if slot is TextureButton:
				#var slot_index = slot.slot_index
				#print("Slot Index:", slot_index,
					  #" Item Texture Assigned:", slot.texture_normal,
					  #" Slot Visibility:", slot.visible)
			#else:
				#print("Warning: Unexpected node found in inventory slots. Expected 'TextureButton'. Node name:", slot.name)
	#else:
		#print("Error: 'GridContainer' node not found in inventory instance.")
#
	#print("--- End of Enhanced Inventory Debug Info ---")

# Helper functions

# Helper function to check if we're in a game scene
func _is_not_game_scene() -> bool:
	var current_scene = get_tree().current_scene
	return current_scene and current_scene.name.begins_with("Main_")

# Helper function to handle main scene not toggling pause/inventory
func update_input_processing() -> void:
	# Get the current scene
	var current_scene = get_tree().current_scene

	if current_scene and current_scene.name != "Main_Menu":  # Enable input only in game scenes
		set_process_input(true)
	else:
		# Disable input processing in non-game scenes
		set_process_input(false)
		
		# Hide inventory and pause menu when switching to non-game scenes
		if inventory_instance:
			inventory_instance.visible = false
		if pause_menu:
			pause_menu.visible = false
