extends Node

signal tool_changed(slot_index: int, item_texture: Texture)  # Signal for tool changes

# Use shared ToolConfig Resource instead of duplicated TOOL_MAP (follows .cursor/rules/godot.md)
var tool_config: Resource = null
# Use shared GameConfig Resource for magic numbers (follows .cursor/rules/godot.md)
var game_config: Resource = null

var current_hud_slot: int = 0  # Currently active tool slot index
var current_tool_texture: Texture = null  # Texture of the currently active tool
var current_tool: String = "unknown"  # Default to unknown

# Track which slot contains which tool texture (so we can follow tools when moved)
var tool_slot_map: Dictionary = {}  # Maps tool texture to slot index

# Cached reference to avoid repeated get_node() calls (follows .cursor/rules/godot.md)
@onready var hud: Node = get_node("../HUD")

func _ready() -> void:
	# Load shared Resources
	tool_config = load("res://resources/data/tool_config.tres")
	game_config = load("res://resources/data/game_config.tres")
	
	# Use cached HUD reference
	if hud:
		if not is_connected("tool_changed", Callable(hud, "_highlight_active_tool")):
			connect("tool_changed", Callable(hud, "_highlight_active_tool"))
			# Find and connect all hud_slot signals
		var tool_container = hud.get_node_or_null("MarginContainer/HBoxContainer")
		if tool_container:
			var tool_slots = tool_container.get_children()
			for slot in tool_slots:
				if slot.has_signal("tool_selected"):
					if not slot.is_connected("tool_selected", Callable(self, "_on_tool_selected")):
						slot.connect("tool_selected", Callable(self, "_on_tool_selected"))
				
		
# Signal handler for tool_selected
func _on_tool_selected(slot_index: int) -> void:
	set_hud_by_slot(slot_index)  # Pass item_texture here


func set_hud_by_slot(slot_index: int) -> void:
	# Use cached HUD reference instead of repeated get_node() call
	if not hud:
		print("Error: HUD not found.")
		return
	# Access the TextureButton and list its children
	var button_path = "MarginContainer/HBoxContainer/TextureButton_" + str(slot_index)
	var texture_button = hud.get_node_or_null(button_path)
	
	if texture_button:
		# Access the Hud_slot_X child
		var slot_path = button_path + "/Hud_slot_" + str(slot_index)
		var hud_slot = hud.get_node_or_null(slot_path)

		if hud_slot:
			# Use explicit if/else instead of ternary operator (follows .cursor/rules/godot.md)
			var item_texture: Texture = null
			if hud_slot.has_method("get_texture"):
				item_texture = hud_slot.get_texture()
			
			if item_texture:
				current_hud_slot = slot_index
				current_tool_texture = item_texture
				# Map texture to tool name using shared ToolConfig
				if tool_config and tool_config.has_method("get_tool_name"):
					current_tool = tool_config.get_tool_name(item_texture)
				else:
					current_tool = "unknown"
				
				# Update tool slot mapping
				tool_slot_map[item_texture] = slot_index
				
				emit_signal("tool_changed", slot_index, item_texture)
			else:
				# Slot is empty - ALWAYS clear the active tool when selecting an empty slot
				print("DEBUG: Slot ", slot_index, " is empty - clearing active tool")
				current_tool_texture = null
				current_tool = "unknown"
				current_hud_slot = slot_index  # Track which slot is selected, but it's empty
				emit_signal("tool_changed", slot_index, null)
		else:
			print("Tool slot not found at path:", slot_path)
	else:
		print("TextureButton not found at path:", button_path)
		
		
func update_toolkit_slot(slot_index: int, texture: Texture) -> void:
	"""Update toolkit slot and emit tool_changed if active tool was moved"""
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
			if hud_slot.has_method("set_item"):
				hud_slot.set_item(texture)
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
				print("DEBUG: Active tool (", current_tool, ") moved to slot ", slot_index, " - updating active slot")
				current_hud_slot = slot_index
				# Tool name and texture stay the same (it's the same tool)
				# Emit signal so farming_manager knows the tool is still active, just in a new slot
				emit_signal("tool_changed", slot_index, texture)
			# PRIORITY 2: If this is the currently active slot, update current tool
			elif slot_index == current_hud_slot:
				print("DEBUG: Active slot ", slot_index, " now contains different tool")
				current_tool_texture = texture
				if texture:
					# Map texture to tool name using shared ToolConfig
					if tool_config and tool_config.has_method("get_tool_name"):
						current_tool = tool_config.get_tool_name(texture)
					else:
						current_tool = "unknown"
					print("DEBUG: Active tool changed to: ", current_tool)
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
	
	for i in range(hud_slot_count):  # Keys 1-0 correspond to HUD slots 0-9
		var action = "ui_hud_" + str(i + 1)
		if i == 9:  # Special case for "0" key (maps to slot 9)
			action = "ui_hud_0"
		if event.is_action_pressed(action):
			set_hud_by_slot(i)
