extends CanvasLayer

@export var tool_switcher_path: NodePath
signal tool_changed(slot_index: int, item_texture: Texture)

var farming_manager: Node = null # Reference to FarmingManager
var _farming_manager_error_logged: bool = false # Flag to prevent error spam

# Cached references to avoid absolute path lookups (follows .cursor/rules/godot.md)
var hud_scene_instance: Node = null # Injected reference to instantiated HUD scene
var slots_container: HBoxContainer = null # Cached reference to tool slots container
var tool_switcher: Node = null # Cached reference to ToolSwitcher node


func _ready() -> void:
	# Add to "hud" group for easy lookup
	add_to_group("hud")
	
	# Connect the signal to highlight the active tool
	connect("tool_changed", Callable(self, "_highlight_active_tool"))

	# Connect to UiManager's scene_changed signal
	if UiManager:
		UiManager.connect("scene_changed", Callable(self, "_on_scene_changed"))

	# Connect to PlayerStatsManager signals
	_connect_player_stats_signals()

	# Check current scene on startup
	_on_scene_changed(get_tree().current_scene.name)


func _on_scene_changed(_new_scene_name: String) -> void:
	if UiManager._is_not_game_scene():
		pass # Not in a game scene, HUD will be hidden
	else:
		setup_hud()


func setup_hud() -> void:
	# Use cached references instead of absolute paths (follows .cursor/rules/godot.md)
	# farming_manager should already be set via set_farming_manager() from farm_scene
	if not farming_manager:
		if not _farming_manager_error_logged:
			_farming_manager_error_logged = true

	# Connect to ToolSwitcher using cached reference
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_highlight_active_tool")):
			tool_switcher.connect("tool_changed", Callable(self, "_highlight_active_tool"))
	else:
		return

	# Use cached slots container instead of absolute path
	if not slots_container:
		return

	# Dynamically connect signals for each TextureButton node
	var tool_buttons = slots_container.get_children()
	#for i in range(tool_buttons.size()):
	#print("Tool button:", tool_buttons[i], "Children:", tool_buttons[i].get_children())

	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			var hud_slot = tool_buttons[i].get_node("Hud_slot_" + str(i))
			if hud_slot and hud_slot is TextureRect: # Adjust for TextureRect
				hud_slot.set_meta("slot_index", i) # Assign slot index for tracking
				tool_buttons[i].connect(
					"gui_input", Callable(self, "_on_tool_clicked").bind(hud_slot)
				) # No need to cast
			else:
				print("Error: hud_slot not found or invalid for tool button", i)

	# CRITICAL: Check if InventoryManager has existing data (from previous scene or save file)
	# If yes, sync FROM InventoryManager TO UI (restore state)
	# If no, sync FROM UI TO InventoryManager (first-time setup with pre-loaded tools)
	if InventoryManager:
		var has_existing_data = false
		# Check if any toolkit slot has data
		for i in range(InventoryManager.max_toolkit_slots):
			var slot_data = InventoryManager.toolkit_slots.get(i, {"texture": null, "count": 0})
			if slot_data["texture"] != null and slot_data["count"] > 0:
				has_existing_data = true
				break

		if has_existing_data:
			# Restore toolkit from InventoryManager (scene transition or load game)
			InventoryManager.sync_toolkit_ui()
			# Also sync inventory
			InventoryManager.sync_inventory_ui()
		else:
			# First-time setup: Read pre-loaded tools from UI
			if InventoryManager.has_method("_sync_initial_toolkit_from_ui"):
				InventoryManager._sync_initial_toolkit_from_ui()

	# Emit tool_changed for the first slot (slot 0)
	if tool_buttons.size() > 0:
		var first_slot = tool_buttons[0].get_node("Hud_slot_0")
		#print("should have first tool assigned", first_slot)
		if first_slot and first_slot.texture:
			emit_signal("tool_changed", 0, first_slot.texture) # Emit signal with the texture from Hud_slot_0
			_update_farming_manager_tool(0, first_slot.texture) # Sync farming manager with the initial tool texture
		else:
			print("Warning: No texture in Hud_slot_0. Defaulting to empty.")
			emit_signal("tool_changed", 0, null)
	
	# Sync stat bars with current values from PlayerStatsManager
	_sync_stat_bars()


func set_farming_manager(farming_manager_instance: Node) -> void:
	if farming_manager_instance:
		farming_manager = farming_manager_instance # Save the reference
		_farming_manager_error_logged = false # Reset error flag when manager is set
	else:
		print("Error: FarmingManager instance is null. Cannot link.")


func set_hud_scene_instance(hud_instance: Node) -> void:
	"""Inject the HUD scene instance and cache its child references.
	This replaces absolute /root/... paths with cached references (follows .cursor/rules/godot.md)."""
	hud_scene_instance = hud_instance
	if hud_instance:
		# Cache the slots container reference
		slots_container = hud_instance.get_node_or_null("HUD/MarginContainer/HBoxContainer")
		if not slots_container:
			print("Error: Could not find HBoxContainer in HUD scene instance.")

		# Cache the ToolSwitcher reference
		tool_switcher = hud_instance.get_node_or_null("ToolSwitcher")
		if not tool_switcher:
			print("Error: Could not find ToolSwitcher in HUD scene instance.")
	else:
		print("Error: HUD scene instance is null. Cannot cache references.")


func _update_farming_manager_tool(slot_index: int, item_texture: Texture) -> void:
	#print("Updating farming manager with slot:", slot_index, "and texture:", item_texture)
	if farming_manager:
		farming_manager._on_tool_changed(slot_index, item_texture)


func _on_tool_clicked(event: InputEvent, clicked_texture_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		if clicked_texture_rect and clicked_texture_rect.has_meta("slot_index"):
			var index = clicked_texture_rect.get_meta("slot_index")
			var parent_button = clicked_texture_rect.get_parent() # Assuming the parent is the TextureButton
			if parent_button and parent_button is TextureButton:
				var item_texture = parent_button.texture_normal # Example for retrieving texture
				emit_signal("tool_changed", index, item_texture)
			else:
				print("Error: Parent is not a TextureButton for clicked slot:", index)


func _highlight_active_tool(slot_index: int, _item_texture: Texture) -> void:
	# Use cached reference instead of absolute path (follows .cursor/rules/godot.md)
	if not slots_container:
		print("Error: Slots container not cached. Cannot highlight tool.")
		return

	var tool_buttons = slots_container.get_children()
	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			var highlight = tool_buttons[i].get_node_or_null("Highlight")
			if highlight:
				highlight.visible = (i == slot_index)
				# CRITICAL: Ensure highlight doesn't block mouse events for drag-and-drop
				highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
				# Ensure highlight is behind the button (lower z_index)
				highlight.z_index = -1
				highlight.z_as_relative = true


func _connect_player_stats_signals() -> void:
	"""Connect to PlayerStatsManager signals for stat updates"""
	if PlayerStatsManager:
		if not PlayerStatsManager.health_changed.is_connected(_on_health_changed):
			PlayerStatsManager.health_changed.connect(_on_health_changed)
		if not PlayerStatsManager.energy_changed.is_connected(_on_energy_changed):
			PlayerStatsManager.energy_changed.connect(_on_energy_changed)
		if not PlayerStatsManager.happiness_changed.is_connected(_on_happiness_changed):
			PlayerStatsManager.happiness_changed.connect(_on_happiness_changed)
	else:
		print("Warning: PlayerStatsManager not found. Stats bars will not update.")


func _on_health_changed(new_health: int, max_health: int) -> void:
	"""Update health bar when health changes"""
	if not hud_scene_instance:
		return
	
	var health_bar = hud_scene_instance.get_node_or_null("HUD/MarginContainer2/Energy/HealthBar")
	if health_bar and health_bar is ProgressBar:
		health_bar.max_value = max_health
		health_bar.value = new_health
		_update_bar_color(health_bar, new_health, max_health)


func _on_energy_changed(new_energy: int, max_energy: int) -> void:
	"""Update energy bar when energy changes"""
	if not hud_scene_instance:
		return
	
	var energy_bar = hud_scene_instance.get_node_or_null("HUD/MarginContainer2/Energy/EnergyBar")
	if energy_bar and energy_bar is ProgressBar:
		energy_bar.max_value = max_energy
		energy_bar.value = new_energy
		_update_bar_color(energy_bar, new_energy, max_energy)


func _on_happiness_changed(new_happiness: int, max_happiness: int) -> void:
	"""Update happiness bar when happiness changes"""
	if not hud_scene_instance:
		return
	
	var happiness_bar = hud_scene_instance.get_node_or_null("HUD/MarginContainer2/Energy/HappinessBar")
	if happiness_bar and happiness_bar is ProgressBar:
		happiness_bar.max_value = max_happiness
		happiness_bar.value = new_happiness
		_update_bar_color(happiness_bar, new_happiness, max_happiness)


func _update_bar_color(bar: ProgressBar, current: int, max_value: int) -> void:
	"""Update ProgressBar color based on percentage (green ≥20%, red <20%)"""
	if not bar or max_value <= 0:
		return
	
	var percent = float(current) / float(max_value)
	if percent >= 0.2:
		# Green for ≥20%
		bar.modulate = Color(0.0, 1.0, 0.0, 1.0) # Green
	else:
		# Red for <20%
		bar.modulate = Color(1.0, 0.0, 0.0, 1.0) # Red


func _sync_stat_bars() -> void:
	"""Sync stat bars with current PlayerStatsManager values"""
	if not PlayerStatsManager or not hud_scene_instance:
		return
	
	# Sync health bar
	var health_bar = hud_scene_instance.get_node_or_null("HUD/MarginContainer2/Energy/HealthBar")
	if health_bar and health_bar is ProgressBar:
		health_bar.max_value = PlayerStatsManager.max_health
		health_bar.value = PlayerStatsManager.health
		_update_bar_color(health_bar, PlayerStatsManager.health, PlayerStatsManager.max_health)
	
	# Sync energy bar
	var energy_bar = hud_scene_instance.get_node_or_null("HUD/MarginContainer2/Energy/EnergyBar")
	if energy_bar and energy_bar is ProgressBar:
		energy_bar.max_value = PlayerStatsManager.max_energy
		energy_bar.value = PlayerStatsManager.energy
		_update_bar_color(energy_bar, PlayerStatsManager.energy, PlayerStatsManager.max_energy)
	
	# Sync happiness bar
	var happiness_bar = hud_scene_instance.get_node_or_null("HUD/MarginContainer2/Energy/HappinessBar")
	if happiness_bar and happiness_bar is ProgressBar:
		happiness_bar.max_value = PlayerStatsManager.max_happiness
		happiness_bar.value = PlayerStatsManager.happiness
		_update_bar_color(happiness_bar, PlayerStatsManager.happiness, PlayerStatsManager.max_happiness)
