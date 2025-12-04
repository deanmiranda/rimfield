# player.gd
# Handles basic player movements.

extends CharacterBody2D

# Use GameConfig Resource instead of magic number (follows .cursor/rules/godot.md)
var game_config: Resource = null
var speed: float = 200 # Default (will be overridden by GameConfig)
var direction: Vector2 = Vector2.ZERO # Tracks input direction
var interactable: Node = null # Stores the interactable object the player is near
var farming_manager: Node = null # Reference to the farming system
var current_interaction: String = "" # Track the current interaction

# Interaction system - signal-based sets (no polling)
# REMOVED: nearby_pickables array (now using auto-pickup on area_entered)
var pickup_radius: float = 48.0 # Default (will be overridden by GameConfig)

@onready var inventory_manager = InventoryManager # Singleton reference
@onready var sprite = $AnimatedSprite2D # Reference to AnimatedSprite2D node
@onready var interaction_area: Area2D = null # Will be created in _ready


func _ready() -> void:
	# Load GameConfig Resource
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		speed = game_config.player_speed
		pickup_radius = game_config.pickup_radius

	# Create interaction Area2D for detecting nearby pickables
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.monitorable = false # This area detects, doesn't need to be detected
	interaction_area.monitoring = true # Enable monitoring
	interaction_area.collision_mask = 2 # Detect items on collision layer 2
	add_child(interaction_area)

	# Create collision shape for interaction radius
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	# Pickup radius: 32 pixels = two tiles (gives player time to react and run away)
	circle_shape.radius = 32.0
	collision_shape.shape = circle_shape
	interaction_area.add_child(collision_shape)

	# Connect signals for tracking nearby pickables
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	interaction_area.area_entered.connect(_on_interaction_area_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_area_exited)

	# Locate farming system if in the farm scene
	var farm_scene = get_tree().current_scene
	print("[Player] _ready: Current scene: ", farm_scene, " name: ", farm_scene.name if farm_scene else "null")

	if farm_scene and farm_scene.has_node("FarmingManager"):
		farming_manager = farm_scene.get_node("FarmingManager")
		print("[Player] _ready: Found FarmingManager via has_node: ", farming_manager)
	else:
		# Fallback: try to find FarmingManager via scene tree search
		var farming_managers = get_tree().get_nodes_in_group("farming_manager")
		print("[Player] _ready: Found ", farming_managers.size(), " farming managers in group")
		if farming_managers.size() > 0:
			farming_manager = farming_managers[0]
			print("[Player] _ready: Using first farming manager from group: ", farming_manager)
		else:
			# Try to find it as a child of current scene
			if farm_scene:
				var found_manager = farm_scene.find_child("FarmingManager", true, false)
				if found_manager:
					farming_manager = found_manager
					print("[Player] _ready: Found FarmingManager via find_child: ", farming_manager)
				else:
					farming_manager = null
					print("[Player] _ready: ERROR - FarmingManager not found!")
			else:
				farming_manager = null
				print("[Player] _ready: ERROR - No current scene!")


func _physics_process(_delta: float) -> void:
	# Reset direction
	direction = Vector2.ZERO

	# Handle input for movement
	direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))

	# Normalize direction for diagonal movement
	if direction.length() > 1:
		direction = direction.normalized()

	# Update velocity based on direction and speed
	velocity = direction * speed

	# Apply movement using built-in move_and_slide()
	move_and_slide()

	# Update animation direction and state
	_update_animation(direction)


func _update_animation(input_direction: Vector2) -> void:
	if input_direction == Vector2.ZERO:
		if sprite.animation.begins_with("walk_"):
			var idle_animation = "stand_" + sprite.animation.substr(5)
			sprite.play(idle_animation)
	else:
		if input_direction.x > 0:
			sprite.play("walk_right")
		elif input_direction.x < 0:
			sprite.play("walk_left")
		elif input_direction.y > 0:
			sprite.play("walk_down")
		elif input_direction.y < 0:
			sprite.play("walk_up")


func _input(event: InputEvent) -> void:
	# CRITICAL: Don't process farming interactions here - moved to _unhandled_input()
	# This ensures UI elements (toolkit, inventory) get priority and can handle clicks first
	# Only check for dragging state to prevent conflicts
	if event.is_action_pressed("ui_mouse_left") and not event.is_echo():
		# CRITICAL: Don't trigger tool actions if player is dragging an item
		# Check if any toolkit or inventory slot is currently dragging
		if _is_any_slot_dragging():
			# Don't mark as handled - let UI handle it if needed
			return # Block tool action when dragging


func _unhandled_input(event: InputEvent) -> void:
	# CRITICAL: _unhandled_input() is called AFTER UI elements have had a chance to handle input
	# This ensures UI elements (toolkit, inventory) get priority over world interactions
	# Handle left-click for farming interactions (only if not handled by UI)
	if event.is_action_pressed("ui_mouse_left") and not event.is_echo():
		print("[Player] _unhandled_input: Left mouse button pressed")
		
		# CRITICAL: Detect drag state BEFORE stopping it
		var was_dragging = _is_any_slot_dragging()
		print("[Player] _unhandled_input: Was dragging: ", was_dragging)
		
		# Extract drag information WITHOUT stopping the drag yet
		var dragged_slot_tool: String = ""
		var dragged_slot_index: int = -1
		var dragged_slot = null
		if was_dragging:
			print("[Player] _unhandled_input: Dragging detected - extracting tool info")
			dragged_slot = _get_dragging_slot()
			if dragged_slot:
				if "slot_index" in dragged_slot:
					dragged_slot_index = dragged_slot.slot_index
				print("[Player] _unhandled_input: Dragged slot index: ", dragged_slot_index)
				# Get the tool texture from the slot
				var tool_texture = dragged_slot.get("item_texture") if "item_texture" in dragged_slot else null
				if not tool_texture:
					# Try to get it from the slot's get_item() method
					if dragged_slot.has_method("get_item"):
						tool_texture = dragged_slot.get_item()
				if tool_texture:
					# Extract base texture if it's an AtlasTexture
					if tool_texture is AtlasTexture:
						tool_texture = tool_texture.atlas
					# Look up tool name
					var tool_config = load("res://resources/data/tool_config.tres")
					if tool_config and tool_config.has_method("get_tool_name"):
						dragged_slot_tool = tool_config.get_tool_name(tool_texture)
						print("[Player] _unhandled_input: Tool from dragged slot: ", dragged_slot_tool)
		
		# CHEST PLACEMENT HANDLING - special case, must prevent _throw_to_world()
		if was_dragging and dragged_slot_tool == "chest" and dragged_slot_index >= 0:
			print("[CHEST] Drag ended: tool=", dragged_slot_tool, " index=", dragged_slot_index)
			
			var world_pos = MouseUtil.get_world_mouse_pos_2d(self)
			print("[CHEST] World position=", world_pos)
			print("[CHEST] Attempting placement in:", ("farm" if farming_manager else "house"))
			
			# Mark input as handled to prevent _stop_drag() from throwing to world
			get_viewport().set_input_as_handled()
			
			# Cancel the drag manually without triggering throw-to-world
			if dragged_slot and dragged_slot.has_method("_cancel_drag"):
				dragged_slot._cancel_drag()
			
			# Now attempt placement
			var placement_success = false
			if farming_manager:
				# Farm scene - use farming_manager
				farming_manager.interact_with_tile(world_pos, global_position, dragged_slot_tool, dragged_slot_index)
				placement_success = true # Assume success for now (farming_manager handles it)
			else:
				# House scene - direct placement (async call)
				placement_success = await _handle_chest_placement_in_house_and_return_success(dragged_slot_index)
			
			print("[CHEST] Placement result:", ("SUCCESS" if placement_success else "FAILED"))
			return
		
		# For non-chest drags, stop them normally
		if was_dragging:
			print("[Player] Non-chest drag ended, stopping normally")
			_stop_all_drags()
		
		# Only process farming if UI didn't handle the click and we're not dragging
		if not was_dragging:
			print("[Player] _unhandled_input: farming_manager exists: ", farming_manager != null)
			if farming_manager:
				var mouse_pos = MouseUtil.get_world_mouse_pos_2d(self)
				print("[Player] _unhandled_input: Mouse world pos: ", mouse_pos, " Player pos: ", global_position)
				print("[Player] _unhandled_input: Calling farming_manager.interact_with_tile()")
				farming_manager.interact_with_tile(mouse_pos, global_position)
			else:
				# House scene - handle pickaxe for chest removal
				var current_tool = _get_current_tool()
				print("[Player] _unhandled_input[House]: Current tool: ", current_tool)
				if current_tool == "pickaxe":
					print("[Player] Pickaxe detected in house, calling handler")
					_handle_pickaxe_in_house()

		# REMOVED: Direct tool shortcuts that bypass ToolSwitcher
		# Tools are now managed entirely by ToolSwitcher based on slot selection
		# Keyboard shortcuts (1-0) select slots via ToolSwitcher, which then updates farming_manager
		# This ensures tools are tied to tool textures, not slot positions

		# Handle E key for door interactions (house entrance)
		if event.is_action_pressed("ui_interact"):
			if current_interaction == "house":
				# Door interaction is handled by house_interaction.gd
				# This is just a fallback - door should handle its own input
				pass

		# REMOVED: Right-click pickup (now auto-pickup on proximity)
		# Right-click will be used for harvesting from trees/plants in the future


func _is_any_slot_dragging() -> bool:
	"""Check if any toolkit or inventory slot is currently dragging an item"""
	print("[Player] _is_any_slot_dragging: Checking for dragging slots...")
	# Check toolkit slots
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		# Try alternative path
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	print("[Player] _is_any_slot_dragging: HUD found: ", hud != null)
	
	if hud:
		# CRITICAL: HUD structure is Hud (Node) -> HUD (CanvasLayer) -> MarginContainer -> HBoxContainer
		var hud_canvas = hud.get_node_or_null("HUD")
		if hud_canvas:
			var margin_container = hud_canvas.get_node_or_null("MarginContainer")
			if margin_container:
				var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
				if toolkit_container:
					print("[Player] _is_any_slot_dragging: Checking ", toolkit_container.get_child_count(), " toolkit slots")
					for i in range(toolkit_container.get_child_count()):
						var slot = toolkit_container.get_child(i)
						if slot and slot is TextureButton:
							if "is_dragging" in slot:
								print("[Player] _is_any_slot_dragging: Slot ", i, " is_dragging = ", slot.is_dragging)
								if slot.is_dragging:
									print("[Player] _is_any_slot_dragging: FOUND DRAGGING SLOT: ", i)
									return true
							else:
								print("[Player] _is_any_slot_dragging: Slot ", i, " has no is_dragging property")
	
	# Check inventory slots (only if pause menu is visible)
	var pause_menu = null
	if UiManager and "pause_menu" in UiManager:
		pause_menu = UiManager.pause_menu
	
	if pause_menu and pause_menu.visible:
		var inventory_grid = pause_menu.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot and slot is TextureButton:
					if "is_dragging" in slot and slot.is_dragging:
						return true
	
	print("[Player] _is_any_slot_dragging: No dragging slots found, returning false")
	return false


func _get_dragging_slot() -> Node:
	"""Get the slot that is currently dragging, or null if none"""
	# Check toolkit slots
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	if hud:
		var hud_canvas = hud.get_node_or_null("HUD")
		if hud_canvas:
			var margin_container = hud_canvas.get_node_or_null("MarginContainer")
			if margin_container:
				var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
				if toolkit_container:
					for i in range(toolkit_container.get_child_count()):
						var slot = toolkit_container.get_child(i)
						if slot and slot is TextureButton:
							if "is_dragging" in slot and slot.is_dragging:
								return slot
	
	# Check inventory slots (only if pause menu is visible)
	var pause_menu = null
	if UiManager and "pause_menu" in UiManager:
		pause_menu = UiManager.pause_menu
	
	if pause_menu and pause_menu.visible:
		var inventory_grid = pause_menu.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot and slot is TextureButton:
					if "is_dragging" in slot and slot.is_dragging:
						return slot
	
	return null


func _stop_all_drags() -> void:
	"""Stop all active drag operations from toolkit and inventory slots"""
	print("[Player] _stop_all_drags: Stopping all drags...")
	# Check toolkit slots
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	if hud:
		var hud_canvas = hud.get_node_or_null("HUD")
		if hud_canvas:
			var margin_container = hud_canvas.get_node_or_null("MarginContainer")
			if margin_container:
				var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
				if toolkit_container:
					for i in range(toolkit_container.get_child_count()):
						var slot = toolkit_container.get_child(i)
						if slot and slot is TextureButton:
							if "is_dragging" in slot and slot.is_dragging:
								print("[Player] _stop_all_drags: Stopping drag on toolkit slot ", i)
								if slot.has_method("_stop_drag"):
									slot._stop_drag()
								elif slot.has_method("_cancel_drag"):
									slot._cancel_drag()
	
	# Check inventory slots
	var pause_menu = null
	if UiManager and "pause_menu" in UiManager:
		pause_menu = UiManager.pause_menu
	
	if pause_menu and pause_menu.visible:
		var inventory_grid = pause_menu.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot and slot is TextureButton:
					if "is_dragging" in slot and slot.is_dragging:
						print("[Player] _stop_all_drags: Stopping drag on inventory slot ", i)
						if slot.has_method("_stop_drag"):
							slot._stop_drag()
						elif slot.has_method("_cancel_drag"):
							slot._cancel_drag()


func _on_interaction_area_body_entered(body: Node2D) -> void:
	# REMOVED: Manual pickup tracking (now auto-pickup via area_entered)
	pass


func _on_interaction_area_body_exited(body: Node2D) -> void:
	# REMOVED: Manual pickup tracking (now auto-pickup via area_entered)
	pass


func _on_interaction_area_area_entered(area: Area2D) -> void:
	# Auto-pickup pickable items when player walks near them
	print("[Player] area_entered detected: ", area.name, " parent: ", area.get_parent().name if area.get_parent() else "null")
	var parent = area.get_parent()
	if parent and parent.is_in_group("pickable"):
		print("[Player] Pickable detected, attempting auto-pickup: ", parent.name)
		# Auto-pickup immediately
		if parent.has_method("pickup_item"):
			# Set HUD reference if needed
			if not parent.hud:
				var hud_ref = get_tree().root.get_node_or_null("Hud")
				if not hud_ref:
					hud_ref = get_tree().current_scene.get_node_or_null("Hud")
				parent.hud = hud_ref
			
			# Trigger pickup
			parent.pickup_item()
			print("[Player] Auto-pickup successful for: ", parent.name)


func _on_interaction_area_area_exited(area: Area2D) -> void:
	# REMOVED: Manual pickup tracking (now auto-pickup via area_entered)
	pass


func _handle_chest_placement_in_house_and_return_success(slot_index_override: int) -> bool:
	"""Handle chest placement when farming_manager is not available (e.g., in house scene). Returns true if successful."""
	print("[Player] _handle_chest_placement_in_house: CALLED with slot_index: ", slot_index_override)
	
	# Validate slot index
	if slot_index_override < 0:
		print("[Player] _handle_chest_placement_in_house: BLOCKED - Invalid slot index")
		return false
	
	# Read item from toolkit via InventoryManager
	if not InventoryManager:
		print("[Player] _handle_chest_placement_in_house: BLOCKED - InventoryManager is null")
		return false
	
	var texture := InventoryManager.get_toolkit_item(slot_index_override)
	var count := InventoryManager.get_toolkit_item_count(slot_index_override)
	
	print("[Player] _handle_chest_placement_in_house: Slot ", slot_index_override, " texture: ", texture, " count: ", count)
	
	if texture == null or count <= 0:
		print("[Player] _handle_chest_placement_in_house: BLOCKED - No item in slot")
		return false
	
	# Identify tool using ToolConfig
	var tool_name := ""
	var tool_config = load("res://resources/data/tool_config.tres")
	if tool_config and tool_config.has_method("get_tool_name"):
		tool_name = tool_config.get_tool_name(texture)
		print("[Player] _handle_chest_placement_in_house: Tool name: ", tool_name)
	else:
		# Fallback: check resource path
		if texture.resource_path.findn("chest") != -1:
			tool_name = "chest"
			print("[Player] _handle_chest_placement_in_house: Tool name (fallback): chest")
	
	if tool_name != "chest":
		print("[Player] _handle_chest_placement_in_house: BLOCKED - Not a chest tool: ", tool_name)
		return false
	
	# Get mouse position in world and snap to grid
	var mouse_pos = MouseUtil.get_world_mouse_pos_2d(self)
	var world_pos = Vector2(floor(mouse_pos.x / 16.0) * 16.0 + 8, floor(mouse_pos.y / 16.0) * 16.0 + 8)
	print("[Player] _handle_chest_placement_in_house: World pos: ", world_pos)
	
	# Get ChestManager
	var chest_manager = get_node_or_null("/root/ChestManager")
	if not chest_manager:
		print("[Player] _handle_chest_placement_in_house: BLOCKED - ChestManager is null")
		return false
	
	# Check if there's already a chest at this position
	var existing_chests = chest_manager.chest_registry
	for chest_id in existing_chests.keys():
		var chest_data = existing_chests[chest_id]
		var chest_node = chest_data.get("node")
		if chest_node and is_instance_valid(chest_node):
			var distance = chest_node.global_position.distance_to(world_pos)
			if distance < 16.0:
				print("[Player] _handle_chest_placement_in_house: BLOCKED - Chest already exists at position")
				return false
	
	# Create chest at position
	print("[Player] _handle_chest_placement_in_house: Creating chest...")
	var chest = chest_manager.create_chest_at_position(world_pos)
	if chest == null:
		print("[Player] _handle_chest_placement_in_house: FAILED - ChestManager.create_chest_at_position returned null")
		return false
	
	print("[Player] _handle_chest_placement_in_house: SUCCESS - Chest created, consuming item...")
	
	# Log BEFORE decrement
	print("[CHEST INV][House] BEFORE decrement: slot=%d texture=%s count=%d" % [slot_index_override, str(InventoryManager.get_toolkit_item(slot_index_override)), InventoryManager.get_toolkit_item_count(slot_index_override)])
	
	# Consume one chest item from the toolkit slot
	InventoryManager.decrement_toolkit_item_count(slot_index_override, 1)
	
	# Deferred sync to ensure drag state is cleared
	await get_tree().process_frame
	InventoryManager.sync_toolkit_ui()
	
	# Log AFTER sync
	print("[CHEST INV][House] AFTER decrement: slot=%d texture=%s count=%d" % [slot_index_override, str(InventoryManager.get_toolkit_item(slot_index_override)), InventoryManager.get_toolkit_item_count(slot_index_override)])
	
	print("[Player] _handle_chest_placement_in_house: COMPLETE")
	return true


func _pickup_nearest_item() -> void:
	# REMOVED: Manual pickup (now auto-pickup on proximity)
	pass


func _get_current_tool() -> String:
	"""Get the currently selected tool name from ToolSwitcher."""
	# ToolSwitcher is a child of HUD, not an autoload
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	var tool_switcher = null
	if hud:
		tool_switcher = hud.get_node_or_null("ToolSwitcher")
	
	if not tool_switcher:
		print("[Player] _get_current_tool: ToolSwitcher not found in HUD")
		return ""
	
	# ToolSwitcher uses "current_hud_slot", not "selected_slot"
	var selected_slot = -1
	if "current_hud_slot" in tool_switcher:
		selected_slot = tool_switcher.current_hud_slot
		print("[Player] _get_current_tool: ToolSwitcher current_hud_slot = ", selected_slot)
	else:
		print("[Player] _get_current_tool: current_hud_slot property not found in ToolSwitcher")
		return ""
	
	if selected_slot < 0:
		print("[Player] _get_current_tool: No slot selected (slot = ", selected_slot, ")")
		return ""
	
	var tool_texture = InventoryManager.get_toolkit_item(selected_slot)
	if not tool_texture:
		print("[Player] _get_current_tool: No texture in slot ", selected_slot)
		return ""
	
	print("[Player] _get_current_tool: Tool texture path = ", tool_texture.resource_path)
	
	var tool_config = load("res://resources/data/tool_config.tres")
	if tool_config and tool_config.has_method("get_tool_name"):
		var tool_name = tool_config.get_tool_name(tool_texture)
		print("[Player] _get_current_tool: Tool name = ", tool_name)
		return tool_name
	
	print("[Player] _get_current_tool: ToolConfig not found or no get_tool_name method")
	return ""


func _handle_pickaxe_in_house() -> void:
	"""Handle pickaxe usage in house scene (for chest removal)."""
	print("[CHEST PICKAXE][House] Pickaxe clicked in house")
	
	# Get mouse position
	var mouse_pos = MouseUtil.get_world_mouse_pos_2d(self)
	print("[CHEST PICKAXE][House] Mouse world pos: ", mouse_pos)
	
	# Get ChestManager
	var chest_manager = get_node_or_null("/root/ChestManager")
	if not chest_manager:
		print("[CHEST PICKAXE][House] ERROR: ChestManager not found")
		return
	
	# Find chest at mouse position
	var chest_at_pos = chest_manager.find_chest_at_position(mouse_pos, 16.0)
	if not chest_at_pos:
		print("[CHEST PICKAXE][House] No chest found at position")
		return
	
	print("[CHEST PICKAXE][House] Chest found at pos: ", chest_at_pos.global_position)
	
	# Get HUD for droppable spawning
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	# Attempt to remove chest and spawn drop
	var removal_success = chest_manager.remove_chest_and_spawn_drop(chest_at_pos, hud)
	
	if removal_success:
		print("[CHEST PICKAXE][House] Chest removed successfully")
	else:
		print("[CHEST PICKAXE][House] Chest removal blocked (not empty)")


func start_interaction(interaction_type: String):
	current_interaction = interaction_type
	# print("Player can interact with:", interaction_type)


func stop_interaction():
	current_interaction = ""


func interact_with_droppable(droppable_data: Resource) -> void:
	if inventory_manager:
		var _success = inventory_manager.add_item_to_first_empty_slot(droppable_data)
