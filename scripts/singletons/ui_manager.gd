extends Node2D

# Reference variables for resources and inventory instance
var grass_emitter_scene: PackedScene = preload("res://scenes/effects/particles/grass_particle.tscn")
var tilled_emitter_scene: PackedScene = preload(
	"res://scenes/effects/particles/tilled_particle.tscn"
)
var dirt_emitter_scene: PackedScene = preload("res://scenes/effects/particles/dirt_particle.tscn")
var cell_size: Vector2 = Vector2(16, 16) # Define the size of each cell manually for flexibility
var debug_disable_dust: bool = true # Toggle to disable dust emitter

# Pause Menu specific properties
var pause_menu: Control
var paused = false
signal scene_changed(new_scene_name: String)

# Chest Inventory Panel
var chest_inventory_panel: Control = null

@onready var inventory_scene = preload("res://scenes/ui/inventory_scene.tscn") # Path to the inventory scene
var inventory_instance: Control = null # Reference to the inventory instance

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
	set_process(false) # Disable per-frame polling

	instantiate_inventory() # Call inventory instantiation
	pause_menu_setup()
	chest_panel_setup() # Setup chest inventory panel
	set_process_input(true) # Ensure UiManager can process global inputs
	process_mode = Node.PROCESS_MODE_ALWAYS # Process input even when tree is paused

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
	if inventory_instance: # Prevent duplicates
		if inventory_instance.get_parent(): # Already added to the scene tree
			return

	if inventory_scene is PackedScene:
		inventory_instance = inventory_scene.instantiate()
		add_child(inventory_instance) # Add inventory instance to UI Manager
		inventory_instance.visible = false # Make it hidden by default

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
		return

	if pause_menu_scene is PackedScene:
		var pause_menu_layer = pause_menu_scene.instantiate()
		add_child(pause_menu_layer) # Add the CanvasLayer to this scene
		# Get the Control child from the CanvasLayer
		pause_menu = pause_menu_layer.get_node("Control")
		pause_menu.visible = false


func chest_panel_setup() -> void:
	"""Setup chest inventory panel."""
	var chest_panel_scene = load("res://scenes/ui/chest_inventory_panel.tscn")
	if not chest_panel_scene:
		return
	
	if chest_panel_scene is PackedScene:
		var chest_panel_layer = chest_panel_scene.instantiate()
		add_child(chest_panel_layer)
		# Get the Control child from the CanvasLayer
		chest_inventory_panel = chest_panel_layer.get_node("Control")
		chest_inventory_panel.visible = false
		
		# Connect to chest signals globally
		_connect_to_chest_signals()


func _connect_to_chest_signals() -> void:
	"""Connect to all chest signals in the scene."""
	# This will be called when chests are created
	# For now, we'll connect dynamically when chests are registered
	pass


func open_chest_ui(chest: Node) -> void:
	"""Open the chest UI for the specified chest."""
	if chest_inventory_panel and chest_inventory_panel.has_method("open_chest_ui"):
		# Get chest_id from chest node
		var chest_id = ""
		if chest.has_method("get_chest_id"):
			chest_id = chest.get_chest_id()
		elif "chest_id" in chest:
			chest_id = chest.chest_id
		
		chest_inventory_panel.open_chest_ui(chest, chest_id)


func _input(event: InputEvent) -> void:
	# Don't process ESC or inventory on main menu - only during gameplay
	var current_scene = get_tree().current_scene
	if current_scene:
		# Check both scene name and scene file path to be safe
		var scene_name = current_scene.name
		var scene_file = current_scene.scene_file_path
		if scene_name == "Main_Menu" or (scene_file and scene_file.ends_with("main_menu.tscn")):
			return

	if event.is_action_pressed("ui_cancel"):
		if inventory_instance and inventory_instance.visible:
			toggle_inventory() # Close inventory first
		elif pause_menu and not pause_menu.visible:
			toggle_pause_menu() # Open pause menu if inventory is closed
		elif pause_menu and pause_menu.visible:
			toggle_pause_menu() # Close pause menu

	# Handle E key (ui_interact) - toggle menu like ESC (works even when menu is open)
	elif event.is_action_pressed("ui_interact"):
		# Get SleepController instance from current scene
		var sc = _get_sleep_controller()
		
		# Guard logic: check sleep state before opening inventory
		if sc:
			if sc.is_sleep_prompt_open():
				# Sleep prompt is open - don't open inventory
				return
			if sc.is_sleep_sequence_running():
				# Sleep sequence is running - don't open inventory
				return
			if sc.is_player_in_bed_area():
				# Player is in bed area - request sleep and don't open inventory
				sc.request_sleep_from_bed()
				return
		
		# First, check if there are any interactable objects nearby
		# If there are, let them handle the interaction instead of opening inventory
		if _has_nearby_interactables():
			# NOTE: Chest now opens on right-click (handled in chest.gd), not "E" key
			# Don't open chest UI here anymore - just block inventory opening
			# There are interactables nearby - don't open inventory, let them handle it
			return

		# No interactables nearby - toggle inventory (pause menu) with E key (like ESC)
		toggle_pause_menu()

	elif event.is_action_pressed("ui_inventory"):
		# Disabled - inventory is now accessed via ESC pause menu
		# toggle_inventory()
		pass


# NOTE: E key handling moved to _input() so it works even when pause menu is open
# _unhandled_input() only fires if input wasn't handled, but pause menu handles input


func _has_nearby_interactables() -> bool:
	"""Check if there are any interactable objects nearby the player"""
	# Find the player
	# CRITICAL: Player is instantiated as Node2D root with CharacterBody2D child
	# Structure: player_instance (Node2D "Player") -> "Player" (CharacterBody2D)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try alternative methods to find player
		var current_scene = get_tree().current_scene
		if current_scene:
			# Search for Node2D roots that have a CharacterBody2D child named "Player"
			for child in current_scene.get_children():
				if child is Node2D and child.name == "Player":
					# Found the player root - get the CharacterBody2D child
					var player_body = child.get_node_or_null("Player")
					if player_body and player_body is CharacterBody2D and player_body.has_method("start_interaction"):
						player = player_body
						break
				elif child is CharacterBody2D and child.has_method("start_interaction"):
					# Fallback: direct CharacterBody2D (shouldn't happen with current structure)
					player = child
					break

	if not player:
		return false # No player found, can't check for interactables

	# Check if player has nearby pickables
	# NOTE: Pickables are now picked up with right-click, not E key
	# So we don't need to check for pickables when determining if E should open inventory
	# (Right-click is handled separately in player.gd)
	# if "nearby_pickables" in player:
	# 	var nearby_pickables = player.get("nearby_pickables")
	# 	if nearby_pickables is Array and nearby_pickables.size() > 0:
	# 		# Filter out invalid entries
	# 		var valid_pickables = []
	# 		for pickable in nearby_pickables:
	# 			if is_instance_valid(pickable):
	# 				valid_pickables.append(pickable)
	# 		if valid_pickables.size() > 0:
	# 			return true  # Has nearby pickable items

	# Check if player has an active interaction (e.g., house door, chest)
	# CRITICAL: Check if player is null before accessing properties to prevent null reference error
	if player and "current_interaction" in player:
		var current_interaction = player.get("current_interaction")
		if current_interaction != null and current_interaction != "":
			return true # Has an active interaction (including chest)

	return false # No interactables nearby


func _get_player() -> Node:
	"""Get the player node."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		var current_scene = get_tree().current_scene
		if current_scene:
			for child in current_scene.get_children():
				if child is Node2D and child.name == "Player":
					var player_body = child.get_node_or_null("Player")
					if player_body and player_body is CharacterBody2D and player_body.has_method("start_interaction"):
						player = player_body
						break
				elif child is CharacterBody2D and child.has_method("start_interaction"):
					player = child
					break
	return player


func _find_nearby_chest(player: Node) -> Node:
	"""Find a chest near the player."""
	if not player or not player is Node2D:
		return null
	
	var player_pos = (player as Node2D).global_position
	var chests = get_tree().get_nodes_in_group("chest")
	
	for chest in chests:
		if not is_instance_valid(chest):
			continue
		if chest is Node2D:
			var distance = player_pos.distance_to(chest.global_position)
			if distance < 64.0: # Within interaction range
				return chest
	
	return null


# Function to toggle pause menu visibility
func toggle_pause_menu() -> void:
	# Toggle the pause menu visibility in the gameplay scene
	if not pause_menu:
		return

	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false # Unpause the entire game
		paused = false
		# Resume game time when inventory panel closes
		if GameTimeManager:
			GameTimeManager.set_paused(false)
	else:
		pause_menu.show()
		get_tree().paused = true # Pause the entire game, but leave UI active
		paused = true
		# Pause game time when inventory panel opens
		if GameTimeManager:
			GameTimeManager.set_paused(true)

		# Ensure inventory UI reflects latest data when opening the menu
		if InventoryManager:
			InventoryManager.sync_inventory_ui()


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


# Helper function to get SleepController instance from current scene
func _get_sleep_controller() -> Node:
	"""Find SleepController node in the current scene
	
	Returns:
		SleepController node if found, null otherwise
	"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# Search for node with sleep_controller script
	for child in current_scene.get_children():
		var found_controller = _find_sleep_controller_in_children(child)
		if found_controller:
			return found_controller
	
	# Try direct node path
	var direct_controller = current_scene.get_node_or_null("SleepController")
	if direct_controller:
		return direct_controller
	
	return null


func _find_sleep_controller_in_children(node: Node) -> Node:
	"""Recursively search for node with sleep_controller script"""
	var script = node.get_script()
	if script:
		var script_path = script.resource_path
		if script_path and "sleep_controller" in script_path:
			return node
	
	for child in node.get_children():
		var result = _find_sleep_controller_in_children(child)
		if result:
			return result
	
	return null


# Helper function to check if we're in a game scene
func _is_not_game_scene() -> bool:
	var current_scene = get_tree().current_scene
	return current_scene and current_scene.name.begins_with("Main_")


# Helper function to handle main scene not toggling pause/inventory
func update_input_processing() -> void:
	# Get the current scene
	var current_scene = get_tree().current_scene

	if current_scene and current_scene.name != "Main_Menu": # Enable input only in game scenes
		set_process_input(true)
	else:
		# Disable input processing in non-game scenes
		set_process_input(false)

		# Hide inventory and pause menu when switching to non-game scenes
		if inventory_instance:
			inventory_instance.visible = false
		if pause_menu:
			pause_menu.visible = false
