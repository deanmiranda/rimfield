extends CanvasLayer

signal tool_changed(new_tool: String)  # Signal to notify tool changes

const TOOL_NAMES = ["hoe", "till", "pickaxe"]

func _ready() -> void:
	# Connect the signal to highlight the active tool
	# This is triggered whenever the active tool changes, either through HUD clicks or input actions.
	connect("tool_changed", Callable(self, "_highlight_active_tool"))

	# Connect signals for manual TextureRect nodes
	# Each TextureRect represents a tool slot in the HUD. Signals are connected dynamically based on setup.
	for i in range(3):  # Assuming you have exactly 3 tools
		var tool_slot = $MarginContainer/HBoxContainer.get_node("tool_slot_%d" % i)
		if tool_slot:
			tool_slot.set_meta("tool_index", i)  # Store the tool index as metadata
			tool_slot.connect("gui_input", Callable(self, "_on_tool_clicked").bind(tool_slot))
			print("Connected signals for: %s" % tool_slot.name)

	# NextTodo: Add future drag-and-drop functionality here.
	#  - Allow users to drag tools from the HUD and swap positions.
	#  - Integrate with inventory management to equip items dynamically into tool slots.

func _on_tool_clicked(event: InputEvent, clicked_texture_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		# When a tool slot is clicked, retrieve its tool index and emit the tool_changed signal.
		if clicked_texture_rect and clicked_texture_rect.has_meta("tool_index"):
			var index = clicked_texture_rect.get_meta("tool_index")
			emit_signal("tool_changed", TOOL_NAMES[index])  # Emit tool_changed with tool name
			print("Tool clicked: %s (index %d)" % [TOOL_NAMES[index], index])

	# NextTodo: Add sound or animation when a tool is selected.
	#  - Play a sound effect to confirm the tool switch.
	#  - Highlight the HUD slot visually to indicate active selection.

func _highlight_active_tool(new_tool: String) -> void:
	# Update the highlight state for each tool slot
	# The highlight node (ColorRect) is toggled visible based on the active tool.
	for i in range(3):  # Assuming you have exactly 3 tools
		var tool_slot = $MarginContainer/HBoxContainer.get_node("tool_slot_%d" % i)
		if tool_slot:
			var highlight = tool_slot.get_node("Highlight")
			if highlight:
				highlight.visible = (TOOL_NAMES[i] == new_tool)

	# NextTodo: Expand logic for drag and drop and additional tool slots.
	#  - Add support for additional slots in the HUD (e.g., food, seeds, etc.).
	#  - Ensure drag-and-drop correctly updates the active tool when swapping slots.
	#  - Consider dynamically managing tool_slots to support a larger inventory system.

# Overall NextTodo:
#  - Refactor to decouple HUD-specific logic from tool switching logic for better modularity.
#  - Create a centralized inventory manager to handle tools and HUD updates.
#  - Add support for hover effects, indicating when a tool can be swapped or equipped.
