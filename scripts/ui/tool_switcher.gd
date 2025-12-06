extends Node

signal tool_changed(slot_index: int, item_texture: Texture) # Signal for tool changes

# Use shared ToolConfig Resource instead of duplicated TOOL_MAP (follows .cursor/rules/godot.md)
var tool_config: Resource = null
# Use shared GameConfig Resource for magic numbers (follows .cursor/rules/godot.md)
var game_config: Resource = null

var current_hud_slot: int = 0 # Currently active tool slot index
var current_tool_texture: Texture = null # Texture of the currently active tool
var current_tool: String = "unknown" # Default to unknown

# Track which slot contains which tool texture (so we can follow tools when moved)
var tool_slot_map: Dictionary = {} # Maps tool texture to slot index

# Cached reference to avoid repeated get_node() calls (follows .cursor/rules/godot.md)
@onready var hud: Node = get_node("../HUD")

func _ready() -> void:
	# Load shared Resources
	tool_config = load("res://resources/data/tool_config.tres")
	game_config = load("res://resources/data/game_config.tres")
	
	# NEW SYSTEM: Connect to ToolkitContainer signals
	# Wait for ToolkitContainer to be created by HudInitializer
	await get_tree().create_timer(0.1).timeout
	
	if ToolkitContainer and ToolkitContainer.instance:
		print("[ToolSwitcher] Connecting to ToolkitContainer...")
		ToolkitContainer.instance.active_slot_changed.connect(_on_active_slot_changed)
		ToolkitContainer.instance.item_changed.connect(_on_toolkit_item_changed)
		ToolkitContainer.instance.tool_equipped.connect(_on_tool_equipped)
		print("[ToolSwitcher] Connected to ToolkitContainer")
	else:
		print("[ToolSwitcher] WARNING: ToolkitContainer not available - using fallback")
	
	# Use cached HUD reference
	if hud:
		if not is_connected("tool_changed", Callable(hud, "_highlight_active_tool")):
			connect("tool_changed", Callable(hud, "_highlight_active_tool"))
		
		# Connect to HUD slots (for backward compatibility during migration)
		var tool_container = hud.get_node_or_null("MarginContainer/HBoxContainer")
		if tool_container:
			var tool_slots = tool_container.get_children()
			for slot in tool_slots:
				if slot.has_signal("tool_selected"):
					if not slot.is_connected("tool_selected", Callable(self, "_on_tool_selected")):
						slot.connect("tool_selected", Callable(self, "_on_tool_selected"))
				
		
# Signal handler for tool_selected
func _on_tool_selected(slot_index: int) -> void:
	set_hud_by_slot(slot_index) # Pass item_texture here


func _on_active_slot_changed(slot_index: int) -> void:
	"""Handle ToolkitContainer active slot change signal"""
	current_hud_slot = slot_index
	var slot_data = ToolkitContainer.instance.get_slot_data(slot_index) if ToolkitContainer.instance else {}
	current_tool_texture = slot_data.get("texture", null)
	
	if current_tool_texture and tool_config and tool_config.has_method("get_tool_name"):
		current_tool = tool_config.get_tool_name(current_tool_texture)
	else:
		current_tool = "unknown"
	
	print("[ToolSwitcher] Active slot: %d, tool: %s" % [slot_index, current_tool])
	emit_signal("tool_changed", slot_index, current_tool_texture)


func _on_toolkit_item_changed(slot_index: int, texture: Texture, count: int) -> void:
	"""Handle ToolkitContainer item change signal"""
	# If this is the active slot, update current tool
	if slot_index == current_hud_slot:
		current_tool_texture = texture
		if texture and tool_config and tool_config.has_method("get_tool_name"):
			current_tool = tool_config.get_tool_name(texture)
		else:
			current_tool = "unknown"
		emit_signal("tool_changed", slot_index, texture)


func _on_tool_equipped(slot_index: int, texture: Texture) -> void:
	"""Handle ToolkitContainer tool equipped signal"""
	# This is emitted when set_active_slot is called
	# Already handled by _on_active_slot_changed
	pass


func set_hud_by_slot(slot_index: int) -> void:
	"""Set active HUD slot (delegates to ToolkitContainer in new system)"""
	print("[ToolSwitcher] set_hud_by_slot called with slot_index: ", slot_index)
	
	# NEW SYSTEM: Delegate to ToolkitContainer
	if ToolkitContainer and ToolkitContainer.instance:
		ToolkitContainer.instance.set_active_slot(slot_index)
		return
	
	# OLD SYSTEM: Fallback (DEPRECATED)
	# Use cached HUD reference instead of repeated get_node() call
	if not hud:
		print("[ToolSwitcher] ERROR: HUD not found.")
		return
	# Access the TextureButton and list its children
	var button_path = "MarginContainer/HBoxContainer/TextureButton_" + str(slot_index)
	var texture_button = hud.get_node_or_null(button_path)
	print("[ToolSwitcher] TextureButton found: ", texture_button != null)
	
	if texture_button:
		# Access the Hud_slot_X child
		var slot_path = button_path + "/Hud_slot_" + str(slot_index)
		var hud_slot = hud.get_node_or_null(slot_path)
		print("[ToolSwitcher] Hud_slot found: ", hud_slot != null)

		if hud_slot:
			# Use explicit if/else instead of ternary operator (follows .cursor/rules/godot.md)
			var item_texture: Texture = null
			if hud_slot.has_method("get_texture"):
				item_texture = hud_slot.get_texture()
			else:
				# Try getting texture directly
				if hud_slot is TextureRect:
					item_texture = hud_slot.texture
					# If it's an AtlasTexture, get the atlas
					if item_texture is AtlasTexture:
						item_texture = item_texture.atlas
						print("[ToolSwitcher] Found AtlasTexture, using atlas: ", item_texture.resource_path if item_texture else "null")
			
			print("[ToolSwitcher] Item texture: ", item_texture, " path: ", item_texture.resource_path if item_texture else "null")
			
			if item_texture:
				current_hud_slot = slot_index
				current_tool_texture = item_texture
				# Map texture to tool name using shared ToolConfig
				print("[ToolSwitcher] tool_config exists: ", tool_config != null)
				if tool_config and tool_config.has_method("get_tool_name"):
					current_tool = tool_config.get_tool_name(item_texture)
					print("[ToolSwitcher] Tool name from config: ", current_tool)
				else:
					current_tool = "unknown"
					print("[ToolSwitcher] tool_config missing or no get_tool_name method")
				
				# Update tool slot mapping
				tool_slot_map[item_texture] = slot_index
				
				print("[ToolSwitcher] Emitting tool_changed signal - slot: ", slot_index, " tool: ", current_tool)
				emit_signal("tool_changed", slot_index, item_texture)
			else:
				# Slot is empty - ALWAYS clear the active tool when selecting an empty slot
				print("[ToolSwitcher] Slot is empty, clearing tool")
				current_tool_texture = null
				current_tool = "unknown"
				current_hud_slot = slot_index # Track which slot is selected, but it's empty
				emit_signal("tool_changed", slot_index, null)
		else:
			print("[ToolSwitcher] ERROR: Tool slot not found at path:", slot_path)
	else:
		print("[ToolSwitcher] ERROR: TextureButton not found at path:", button_path)
		
		
func update_toolkit_slot(slot_index: int, texture: Texture) -> void:
	"""Update toolkit slot and emit tool_changed if active tool was moved"""
	# NEW SYSTEM: Delegate to ToolkitContainer (it will emit item_changed signal)
	if ToolkitContainer and ToolkitContainer.instance:
		var current_data = ToolkitContainer.instance.get_slot_data(slot_index)
		var count = current_data.get("count", 1) if texture else 0
		ToolkitContainer.instance.add_item_to_slot(slot_index, texture, count)
		return
	
	# OLD SYSTEM: Fallback (DEPRECATED)
	# Update the slot texture in the HUD
	if not hud:
		print("Error: HUD not found.")
		return
	
	var button_path = "MarginContainer/HBoxContainer/TextureButton_" + str(slot_index)
	var texture_button = hud.get_node_or_null(button_path)
	
	if texture_button:
		var slot_path = button_path + "/Hud_slot_" + str(slot_index)
		var hud_slot = hud.get_node_or_null(slot_path)
		
		if hud_slot:
			# CRITICAL: Don't overwrite slot if it's currently being dragged (is_dragging)
			# This prevents clearing slots that are in the middle of a drag-and-drop operation
			# is_dragging is a property on the TextureButton (parent), not a method
			var is_dragging = false
			if texture_button and "is_dragging" in texture_button:
				is_dragging = texture_button.is_dragging
			
			if is_dragging:
				# Slot is being dragged - don't update it, just update the mapping
				if texture:
					tool_slot_map[texture] = slot_index
				return
			
			# CRITICAL: Only update if texture is different to avoid overwriting correct state
			# Check current texture first
			var current_texture: Texture = null
			if hud_slot.has_method("get_texture"):
				current_texture = hud_slot.get_texture()
			elif hud_slot is TextureRect:
				current_texture = hud_slot.texture
			
			# Only update if texture actually changed
			if current_texture != texture:
				if hud_slot.has_method("set_item"):
					# set_item() expects (texture, count) - use current count if available
					var current_count = 1
					if hud_slot.has_method("get_stack_count"):
						current_count = hud_slot.get_stack_count()
					hud_slot.set_item(texture, current_count)
				elif hud_slot is TextureRect:
					hud_slot.texture = texture
			
			# Update tool slot mapping
			if texture:
				tool_slot_map[texture] = slot_index
			else:
				# Remove from mapping if slot is cleared
				for tool_texture in tool_slot_map.keys():
					if tool_slot_map[tool_texture] == slot_index:
						tool_slot_map.erase(tool_texture)
						break
			
			# PRIORITY 1: If the active tool texture was moved to this slot, follow it
			# This ensures tool actions follow the tool, not the slot
			if current_tool_texture and current_tool_texture == texture:
				current_hud_slot = slot_index
				# Tool name and texture stay the same (it's the same tool)
				# Emit signal so farming_manager knows the tool is still active, just in a new slot
				emit_signal("tool_changed", slot_index, texture)
			# PRIORITY 2: If this is the currently active slot, update current tool
			elif slot_index == current_hud_slot:
				current_tool_texture = texture
				if texture:
					# Map texture to tool name using shared ToolConfig
					if tool_config and tool_config.has_method("get_tool_name"):
						current_tool = tool_config.get_tool_name(texture)
					else:
						current_tool = "unknown"
					emit_signal("tool_changed", slot_index, texture)
				else:
					# Slot is now empty, set to unknown
					current_tool = "unknown"
					current_tool_texture = null
					emit_signal("tool_changed", slot_index, null)

func _input(event: InputEvent) -> void:
	# Handle key inputs to switch tools based on slot numbers (1-0)
	# Use GameConfig instead of magic number (follows .cursor/rules/godot.md)
	var hud_slot_count: int = 10
	if game_config:
		hud_slot_count = game_config.hud_slot_count
	
	for i in range(hud_slot_count): # Keys 1-0 correspond to HUD slots 0-9
		var action = "ui_hud_" + str(i + 1)
		if i == 9: # Special case for "0" key (maps to slot 9)
			action = "ui_hud_0"
		if event.is_action_pressed(action):
			set_hud_by_slot(i)
