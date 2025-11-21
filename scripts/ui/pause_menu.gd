# pause_menu.gd
# Extensible pause menu with tab system (Inventory, MainMenu, and future tabs)
# Stardew Valley-style inventory/menu system

extends Control

# Tab references for extensibility
@onready var tab_container: TabContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer
@onready
var inventory_tab: Control = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab
@onready
var main_menu_tab: Control = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/MainMenuTab

# Inventory grid reference
@onready
var inventory_grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid

# Player info references
@onready
var player_sprite: TextureRect = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/PlayerSpriteContainer/PlayerSprite
@onready
var date_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/StatsContainer/DateLabel
@onready
var money_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/StatsContainer/MoneyLabel
@onready
var health_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/StatsContainer/HealthLabel
@onready
var energy_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/StatsContainer/EnergyLabel
@onready
var weather_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/StatsContainer/WeatherLabel

# Placeholder stats (for future development)
@onready
var stat_boredom_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/PlaceholderStatsContainer/StatBoredomLabel
@onready
var stat_lonely_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/PlaceholderStatsContainer/StatLonelyLabel
@onready
var stat_social_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/PlaceholderStatsContainer/StatSocialLabel
@onready
var stat_creativity_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/PlayerInfoContainer/PlaceholderStatsContainer/StatCreativityLabel

# MainMenu tab button references
@onready
var resume_button: Button = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/MainMenuTab/MainMenuContent/CenterContainer/VBoxContainer/ResumeButton
@onready
var save_button: Button = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/MainMenuTab/MainMenuContent/CenterContainer/VBoxContainer/SaveGame
@onready
var back_to_main_menu_button: Button = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/MainMenuTab/MainMenuContent/CenterContainer/VBoxContainer/BackToMainMenu
@onready
var exit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/MainMenuTab/MainMenuContent/CenterContainer/VBoxContainer/ExitButton
@onready
var save_feedback_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TabContainer/MainMenuTab/MainMenuContent/CenterContainer/VBoxContainer/SaveFeedbackLabel

# Constants
const INVENTORY_SLOTS_TOTAL = 30 # 3x10 grid
const INVENTORY_SLOTS_ACTIVE = 24 # Top 8 rows (24 slots)
const INVENTORY_SLOTS_LOCKED = 6 # Bottom 2 rows (6 slots)

# Game state (to be connected to GameState singleton later)
var current_day: int = 1
var current_year: int = 1
var current_season: String = "Spring"
var current_money: int = 0
var current_health: int = 100
var max_health: int = 100
var current_energy: int = 100
var max_energy: int = 100
var current_weather: String = "Sunny"

# Placeholder stats (for future development)
var stat_boredom: int = 50
var stat_lonely: int = 50
var stat_social: int = 50
var stat_creativity: int = 50


func _ready() -> void:
	self.visible = false
	
	# Wait for nodes to be fully ready
	await get_tree().process_frame
	
	# FIRST: Initialize inventory slots (create the 30 TextureButton children)
	_setup_inventory_slots()
	

	# THEN: Register with InventoryManager and sync (now that slots exist!)
	if InventoryManager and inventory_grid:
		# Pass the inventory_grid directly to InventoryManager
		# InventoryManager.sync_inventory_ui() will handle it
		InventoryManager.set_inventory_instance(inventory_grid)

		# Sync UI with stored inventory data
		InventoryManager.sync_inventory_ui()
	# Setup player sprite (use first frame of idle animation)
	_setup_player_sprite()
	
	# Ensure player info section is visible and properly sized
	if inventory_tab:
		var player_info = inventory_tab.get_node_or_null("VBoxContainer/PlayerInfoContainer")
		if player_info:
			player_info.visible = true
			player_info.custom_minimum_size = Vector2(0, 200) # Force minimum size
	
	# Update all UI elements
	_update_ui()
	
	# Connect tab change signal for extensibility
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)
		# Set default tab to Inventory (index 0)
		tab_container.current_tab = 0
	
	# Connect MainMenu tab button signals
	_connect_main_menu_signals()
	
	# Hide save feedback initially
	if save_feedback_label:
		save_feedback_label.visible = false


func _setup_inventory_slots() -> void:
	"""Create and configure all inventory slots (30 total, bottom 6 locked)"""
	if not inventory_grid:
		return
	
	# Make sure grid is visible
	inventory_grid.visible = true
	
	# Load empty slot texture
	var empty_texture = preload("res://assets/ui/tile_outline.png")
	var slot_script = load("res://scripts/ui/inventory_menu_slot.gd")
	
	if not slot_script:
		return
	
	# Load border texture for slot outlines (like existing inventory)
	var border_texture = preload("res://assets/ui/tile_outline.png")
	
	# Create 30 slots (3 columns x 10 rows)
	var slots = []
	for i in range(INVENTORY_SLOTS_TOTAL):
		var slot = TextureButton.new()
		slot.name = "InventorySlot_" + str(i)
		slot.custom_minimum_size = Vector2(64, 64) # Match toolkit size approximately
		slot.set_script(slot_script)
		if slot.has_method("set_slot_index"):
			slot.call("set_slot_index", i)
		else:
			slot.slot_index = i
		slot.empty_texture = empty_texture
		slot.visible = true # Ensure slot is visible
		slot.texture_normal = empty_texture # Set initial texture
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		slot.flip_v = false
		slot.flip_h = false
		# CRITICAL: Ensure slot can receive mouse events for dragging
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.focus_mode = Control.FOCUS_CLICK
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Add background style for slots (removed white test background)
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.3, 0.3, 0.3, 1.0) # Dark gray background
		bg_style.border_width_left = 2
		bg_style.border_width_top = 2
		bg_style.border_width_right = 2
		bg_style.border_width_bottom = 2
		bg_style.border_color = Color.BLACK # Black border
		slot.add_theme_stylebox_override("normal", bg_style)
		slot.add_theme_stylebox_override("hover", bg_style.duplicate())
		slot.add_theme_stylebox_override("pressed", bg_style.duplicate())
		slot.add_theme_stylebox_override("disabled", bg_style.duplicate())
		
		# Add border TextureRect as child (exactly like existing inventory slots)
		# Must add AFTER slot is in tree for proper layout
		# We'll add it after adding to grid
		
		# Lock bottom 2 rows (slots 24-29)
		if i >= INVENTORY_SLOTS_ACTIVE:
			slot.is_locked = true
		
		inventory_grid.add_child(slot)
		slots.append({"slot": slot, "index": i})
		
		# Add border TextureRect AFTER slot is in tree (like existing inventory)
		var border_rect = TextureRect.new()
		border_rect.name = "Border"
		border_rect.texture = border_texture
		border_rect.custom_minimum_size = Vector2(64, 64)
		border_rect.layout_mode = 1 # Use integer 1 for LAYOUT_MODE_ANCHORS (Godot 4.x)
		border_rect.anchors_preset = Control.PRESET_FULL_RECT
		border_rect.anchor_right = 1.0
		border_rect.anchor_bottom = 1.0
		border_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
		border_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
		border_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		border_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# CRITICAL: Ignore mouse events so they pass through to parent TextureButton for drag
		border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border_rect.focus_mode = Control.FOCUS_NONE
		border_rect.z_index = 101
		border_rect.z_as_relative = false
		border_rect.visible = true
		slot.add_child(border_rect)
		
	# Force grid to update layout
	inventory_grid.queue_sort()
	
	# Wait for layout to update
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Connect slot signals after all slots are added to tree
	await get_tree().process_frame
	for slot_data in slots:
		var slot = slot_data.slot
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_inventory_slot_clicked)
		if slot.has_signal("slot_drop_received"):
			slot.slot_drop_received.connect(_on_inventory_slot_drop_received)


func _setup_player_sprite() -> void:
	"""Setup player sprite using first frame of idle animation"""
	if not player_sprite:
		return
	
	# Use the player sprite atlas - first frame of idle (stand_down)
	# Region: Rect2(0, 0, 32, 32) from char1.png
	var player_texture = preload("res://assets/sprites/char1.png")
	if player_texture:
		# Create an AtlasTexture for the first frame
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = player_texture
		atlas_texture.region = Rect2(0, 0, 32, 32) # First frame of idle
		player_sprite.texture = atlas_texture
		player_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _update_ui() -> void:
	"""Update all UI elements with current game state"""
	_update_date_display()
	_update_money_display()
	_update_health_display()
	_update_energy_display()
	_update_weather_display()
	_update_placeholder_stats()


func _update_date_display() -> void:
	"""Update date display: 'Spring 1, Year 1' format"""
	if date_label:
		date_label.text = "%s %d, Year %d" % [current_season, current_day, current_year]


func _update_money_display() -> void:
	"""Update money display"""
	if money_label:
		money_label.text = "Money: $%d" % current_money


func _update_health_display() -> void:
	"""Update health display: 'Health: 0/100' format"""
	if health_label:
		health_label.text = "Health: %d/%d" % [current_health, max_health]


func _update_energy_display() -> void:
	"""Update energy display"""
	if energy_label:
		energy_label.text = "Energy: %d/%d" % [current_energy, max_energy]


func _update_weather_display() -> void:
	"""Update weather display"""
	if weather_label:
		weather_label.text = "Weather: %s" % current_weather


func _update_placeholder_stats() -> void:
	"""Update placeholder stats (for future development)"""
	if stat_boredom_label:
		stat_boredom_label.text = "Boredom: %d" % stat_boredom
	if stat_lonely_label:
		stat_lonely_label.text = "Lonely: %d" % stat_lonely
	if stat_social_label:
		stat_social_label.text = "Social: %d" % stat_social
	if stat_creativity_label:
		stat_creativity_label.text = "Creativity: %d" % stat_creativity


func _on_tab_changed(tab_index: int) -> void:
	"""Handle tab changes - extensible for future tabs"""
	match tab_index:
		0: # Inventory tab
			pass # Inventory is default
		1: # MainMenu tab
			_focus_on_resume()
		_: # Future tabs
			pass


func _connect_main_menu_signals() -> void:
	"""Connect MainMenu tab button signals"""
	if resume_button:
		if not resume_button.is_connected("pressed", Callable(self, "_on_resume_button_pressed")):
			resume_button.pressed.connect(_on_resume_button_pressed)
	if save_button:
		if not save_button.is_connected("pressed", Callable(self, "_on_save_game_pressed")):
			save_button.pressed.connect(_on_save_game_pressed)
	if back_to_main_menu_button:
		if not back_to_main_menu_button.is_connected(
			"pressed", Callable(self, "_on_back_to_main_menu_pressed")
		):
			back_to_main_menu_button.pressed.connect(_on_back_to_main_menu_pressed)
	if exit_button:
		if not exit_button.is_connected("pressed", Callable(self, "_on_exit_button_pressed")):
			exit_button.pressed.connect(_on_exit_button_pressed)


func _focus_on_resume() -> void:
	"""Focus on resume button when MainMenu tab is opened"""
	if resume_button:
		resume_button.grab_focus()


func _notification(what: int) -> void:
	"""Handle visibility changes to set correct tab"""
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			# When menu becomes visible, ensure Inventory tab is selected
			if tab_container:
				tab_container.current_tab = 0 # Inventory tab
			# Update UI with latest game state
			_update_ui()


func _input(event: InputEvent) -> void:
	"""Handle ESC and E keys - close menu if open"""
	# Don't process on main menu - only during gameplay
	var current_scene = get_tree().current_scene
	if current_scene:
		# Check both scene name and scene file path to be safe
		var scene_name = current_scene.name
		var scene_file = current_scene.scene_file_path
		if scene_name == "Main_Menu" or (scene_file and scene_file.ends_with("main_menu.tscn")):
			return
	
	# Handle ESC or E key to close menu (UiManager also handles this, but we ensure it works)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_interact"):
		if self.visible:
			# Close the menu
			self.visible = false
			get_tree().paused = false
			get_viewport().set_input_as_handled() # Prevent further processing
		elif not self.visible:
			# When opening, set to Inventory tab by default
			if tab_container:
				tab_container.current_tab = 0 # Inventory tab


func _on_resume_button_pressed() -> void:
	"""Resume game"""
	self.visible = false
	get_tree().paused = false


func _on_exit_button_pressed() -> void:
	"""Exit game"""
	get_tree().quit()


func _on_save_game_pressed() -> void:
	"""Save game"""
	# Save to a dynamic slot based on current time
	var timestamp = Time.get_unix_time_from_system()
	var save_file_path = "user://save_slot_%s.json" % timestamp

	GameState.save_game(save_file_path) # Save the game

	# Provide feedback for saving
	if not save_feedback_label:
		return
	
	save_feedback_label.visible = true
	save_feedback_label.text = "Game Saving..."

	# Force an immediate UI update
	await get_tree().process_frame # Allow one frame to process to update the label

	# Validate save file and update feedback
	await get_tree().create_timer(0.5).timeout # Small delay to ensure save file is registered
	if FileAccess.file_exists(save_file_path):
		# Check the number of save files
		var save_dir = DirAccess.open("user://")
		var save_count = 0
		if save_dir:
			save_dir.list_dir_begin()
			var file_name = save_dir.get_next()
			while file_name != "":
				if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
					save_count += 1
				file_name = save_dir.get_next()
			save_dir.list_dir_end()
		
		# Set feedback text based on the save count
		if save_count > 4:
			save_feedback_label.text = "Game Saved! If you save again, older saves will be overwritten."
			
			# Force an immediate UI update after changing the text
			await get_tree().process_frame # Allow one frame to process to update the label
			
			# Longer delay for the special warning message
			await get_tree().create_timer(2.0).timeout # 2-second delay for longer message
			save_feedback_label.visible = false
		else:
			save_feedback_label.text = "Game Saved!"
			# Force an immediate UI update after changing the text
			await get_tree().process_frame # Allow one frame to process to update the label

			# Shorter delay for the regular message
			await get_tree().create_timer(1.5).timeout
			save_feedback_label.visible = false


func _on_back_to_main_menu_pressed() -> void:
	"""Return to main menu"""
	# Unpause the game before switching to the main menu
	get_tree().paused = false
	
	# Assuming there's a SceneManager singleton that handles scene transitions
	if SceneManager:
		SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
	else:
		# If there's no SceneManager, just change scene directly
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_inventory_slot_clicked(slot_index: int) -> void:
	"""Handle inventory slot clicks - prepare for future functionality"""
	# Future: Handle slot selection, item interaction, toolbelt swapping, etc.
	pass


func _on_inventory_slot_drop_received(slot_index: int, data: Dictionary) -> void:
	"""Handle inventory slot drop - notify ToolSwitcher (InventoryManager already updated in drop_data)"""
	# NOTE: InventoryManager is now updated in inventory_menu_slot.drop_data() BEFORE UI swap
	# This signal handler only needs to notify ToolSwitcher about toolkit changes
	
	# If item came from toolkit, notify ToolSwitcher about the toolkit slot change
	if data.has("source") and data["source"] == "toolkit":
		var toolkit_slot_index = data.get("slot_index", -1)
		if toolkit_slot_index >= 0:
			# Get the swapped item from the toolkit slot (after swap)
			var source_node = data.get("source_node", null)
			var swapped_item: Texture = null
			if source_node and source_node.has_method("get_item"):
				swapped_item = source_node.get_item()
			
			# CRITICAL: Notify ToolSwitcher about the toolkit slot change
			# Find ToolSwitcher in the HUD
			var hud = get_tree().root.get_node_or_null("HUD")
			if hud:
				var tool_switcher = _find_tool_switcher_in_node(hud)
				if tool_switcher and tool_switcher.has_method("update_toolkit_slot"):
					tool_switcher.update_toolkit_slot(toolkit_slot_index, swapped_item)


func _find_tool_switcher_in_node(node: Node) -> Node:
	"""Recursively search for ToolSwitcher node"""
	if node.name == "ToolSwitcher":
		return node
	for child in node.get_children():
		if child.name == "ToolSwitcher":
			return child
		var result = _find_tool_switcher_in_node(child)
		if result:
			return result
	return null


# Public API for updating game state (to be called from GameState singleton)
func update_date(day: int, season: String, year: int) -> void:
	"""Update date display (called when day advances)"""
	current_day = day
	current_season = season
	current_year = year
	_update_date_display()


func update_money(amount: int) -> void:
	"""Update money display"""
	current_money = amount
	_update_money_display()


func update_health(current: int, maximum: int) -> void:
	"""Update health display"""
	current_health = current
	max_health = maximum
	_update_health_display()


func update_energy(current: int, maximum: int) -> void:
	"""Update energy display"""
	current_energy = current
	max_energy = maximum
	_update_energy_display()


func update_weather(weather: String) -> void:
	"""Update weather display"""
	current_weather = weather
	_update_weather_display()


func update_placeholder_stat(stat_name: String, value: int) -> void:
	"""Update placeholder stats (for future development)"""
	match stat_name:
		"boredom":
			stat_boredom = value
			if stat_boredom_label:
				stat_boredom_label.text = "Boredom: %d" % value
		"lonely":
			stat_lonely = value
			if stat_lonely_label:
				stat_lonely_label.text = "Lonely: %d" % value
		"social":
			stat_social = value
			if stat_social_label:
				stat_social_label.text = "Social: %d" % value
		"creativity":
			stat_creativity = value
			if stat_creativity_label:
				stat_creativity_label.text = "Creativity: %d" % value
