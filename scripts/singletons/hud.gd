extends Node2D

@export var tool_switcher_path: NodePath
signal tool_changed(slot_index: int, item_texture: Texture)

var farming_manager: Node = null  # Reference to FarmingManager
var current_drag_data: Dictionary = {}  # Track drag data across slots
var hud_initialized = false  # Flag to indicate if the HUD is initialized

func _ready() -> void:
	print("DEBUG: HUD ready function called.")
	
	if hud_initialized:
		print("DEBUG: HUD already initialized. Skipping ready setup.")
		return

	# Connect tool_changed via SignalManager
	SignalManager.connect_tool_changed(self, self)
	
	# Connect to UiManager's scene_changed signal
	if UiManager:
		UiManager.connect("scene_changed", Callable(self, "_on_scene_changed"))

	# Check current scene on startup
	_on_scene_changed(get_tree().current_scene.name)

func _on_scene_changed(new_scene_name: String) -> void:
	print("DEBUG: Scene changed to:", new_scene_name)
	if UiManager._is_not_game_scene():
		print("DEBUG: Not in a game scene.")
	else:
		setup_hud()
		
func setup_hud() -> void:
	print("DEBUG: Setting up HUD.")
	if hud_initialized:
		print("DEBUG: HUD already initialized. Skipping setup.")
		return
		
	var farm_node = get_node_or_null("/root/Farm")  # Adjust to your scene structure
	if farm_node:
		print("DEBUG: Farm node found.")
		farming_manager = get_node_or_null("/root/Farm/FarmingManager")
	else:
		print("ERROR: Farming Manager node not found.")

	# Access ToolSwitcher via sibling relationship
	var tool_switcher = get_node("/root/Farm/Hud/ToolSwitcher")
	if tool_switcher:
		print("DEBUG: ToolSwitcher found.")
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_highlight_active_tool")):
			tool_switcher.connect("tool_changed", Callable(self, "_highlight_active_tool"))
	else:
		print("ERROR: ToolSwitcher not found as sibling.")

	# Dynamically connect signals for each TextureButton node
	var tool_buttons = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer").get_children()
	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			print("DEBUG: Connecting signals for tool button at index:", i)
			var hud_slot = tool_buttons[i].get_node("Hud_slot_" + str(i))
			if hud_slot and hud_slot is TextureRect:  # Adjust for TextureRect
				hud_slot.set_meta("slot_index", i)  # Assign slot index for tracking
				tool_buttons[i].connect("gui_input", Callable(self, "_on_tool_clicked").bind(hud_slot))  # No need to cast
			else:
				print("ERROR: hud_slot not found or invalid for tool button at index:", i)
	
	# Emit tool_changed for the first slot (slot 0)
	if tool_buttons.size() > 0:
		var first_slot = tool_buttons[0].get_node("Hud_slot_0")
		if first_slot and first_slot.texture:
			print("DEBUG: Emitting tool_changed for first slot.")
			emit_signal("tool_changed", 0, first_slot.texture)  # Emit signal with the texture from Hud_slot_0
			_update_farming_manager_tool(0, first_slot.texture)
		else:
			print("DEBUG: No texture in first slot. Emitting default tool_changed.")
			emit_signal("tool_changed", 0, null)
	
	# Ensure all gui signals are properly connected
	connect_gui_signals()
	hud_initialized = true  # Mark as initialized
	print("DEBUG: HUD setup complete.")

# hud.gd
func connect_gui_signals() -> void:
	print("DEBUG: Connecting GUI signals.")
	var slots_container = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer")
	if not slots_container:
		print("ERROR: HBoxContainer not found.")
		return

	for slot in slots_container.get_children():
		if slot.has_signal("drag_started"):
			slot.connect("drag_started", Callable(self, "_start_drag"))
		if slot.has_signal("item_dropped"):
			slot.connect("item_dropped", Callable(self, "_on_drop_received"))

# hud.gd
func _on_tool_clicked(event: InputEvent, clicked_texture_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		var slot_index = clicked_texture_rect.get_meta("slot_index")
		
		# Validate texture and create drag data
		if clicked_texture_rect.texture:
			var drag_data = {
				"slot_index": slot_index,
				"item_texture": clicked_texture_rect.texture,
				"item_quantity": clicked_texture_rect.get_meta("item_quantity") if clicked_texture_rect.has_meta("item_quantity") else 1
			}
			
			if Input.is_action_just_pressed("ui_mouse_left"):
				print("DEBUG: Left click detected on slot:", slot_index)
				emit_signal("tool_changed", slot_index, clicked_texture_rect.texture)
				_start_drag(drag_data)
			elif Input.is_action_just_pressed("ui_mouse_right"):
				print("DEBUG: Right-click detected on slot:", slot_index)
				if Input.is_action_pressed("ui_shift"):
					drag_data["half_stack"] = true
				_start_drag(drag_data)
		else:
			print("ERROR: No texture in clicked slot:", slot_index)

# hud.gd
func _start_drag(slot_data: Dictionary) -> void:
	print("DEBUG: Starting drag with data:", slot_data)

	current_drag_data = slot_data

	# Create or reuse the drag preview
	var drag_preview = get_node_or_null("DragPreview")
	if drag_preview:
		drag_preview.queue_free()  # Clear old preview

	drag_preview = TextureRect.new()
	drag_preview.name = "DragPreview"
	drag_preview.texture = slot_data["item_texture"]
	drag_preview.set_custom_minimum_size(Vector2(64, 64))
	drag_preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add to HUD layer
	add_child(drag_preview)
	drag_preview.global_position = get_global_mouse_position()
	print("DEBUG: Drag preview created.")

func _process(delta: float) -> void:
	var drag_preview = get_node_or_null("DragPreview")
	if drag_preview:
		drag_preview.global_position = get_global_mouse_position()

func get_slot_by_index(slot_index: int) -> TextureRect:
	print("DEBUG: Getting slot by index:", slot_index)
	var slots_container = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer")
	if not slots_container:
		print("ERROR: HBoxContainer not found.")
		return null

	var slot_button = slots_container.get_children()[slot_index]
	if slot_button and slot_button is TextureButton:
		var texture_rect = slot_button.get_node("Hud_slot_" + str(slot_index))
		if texture_rect and texture_rect is TextureRect:
			return texture_rect
	print("ERROR: TextureRect not found for slot index:", slot_index)
	return null

func get_slot_by_mouse_position() -> Node:
	print("DEBUG: Getting slot by mouse position.")
	var mouse_position = get_global_mouse_position()
	var slots_container = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer")
	if not slots_container:
		print("ERROR: HBoxContainer not found.")
		return null

	for slot in slots_container.get_children():
		if slot.get_global_rect().has_point(mouse_position):
			print("DEBUG: Slot found under mouse.")
			return slot
	print("DEBUG: No slot found under mouse.")
	return null

func _on_drag_started() -> void:
	print("DEBUG: Drag started:", current_drag_data)

func _on_drag_ended() -> void:
	print("DEBUG: Drag ended. Dropped data:", current_drag_data)

	# Remove the drag preview if it exists
	var drag_preview = get_node_or_null("DragPreview")
	if drag_preview:
		drag_preview.queue_free()
		print("DEBUG: Drag preview removed.")
	else:
		print("DEBUG: No drag preview to remove.")

	current_drag_data.clear()
# hud.gd
func _on_drop_received(target_slot_index: int, dropped_data: Dictionary) -> void:
	print("DEBUG: Drop received on slot:", target_slot_index, "with data:", dropped_data)
	var target_slot = get_slot_by_index(target_slot_index)
	if target_slot:
		if target_slot.stack_items(dropped_data["item_texture"], dropped_data["item_quantity"]):
			print("DEBUG: Stacked items in target slot.")
		else:
			print("DEBUG: Swapped items in target slot.")
	else:
		print("DEBUG: Invalid target slot.")
	_clear_drag_preview()

func _clear_drag_preview() -> void:
	var drag_preview = get_node_or_null("DragPreview")
	if drag_preview:
		drag_preview.queue_free()
		print("DEBUG: Drag preview cleared.")
	current_drag_data.clear()

func _highlight_active_tool(slot_index: int, _item_texture: Texture, tool_name: String) -> void:
	print("DEBUG: Highlighting active tool at slot:", slot_index)
	var tool_buttons = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer").get_children()
	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			var highlight = tool_buttons[i].get_node("Highlight")
			if highlight:
				highlight.visible = (i == slot_index)
				
func set_farming_manager(farming_manager_instance: Node) -> void:
	print("DEBUG: Setting FarmingManager.") 
	if farming_manager_instance:
		farming_manager = farming_manager_instance
	else:
		print("ERROR: FarmingManager instance is null. Cannot link.")

func _update_farming_manager_tool(slot_index: int, item_texture: Texture) -> void: 
	print("DEBUG: Updating FarmingManager tool. Slot index:", slot_index) 
	if farming_manager: 
		farming_manager._on_tool_changed(slot_index, item_texture)
	else:
		print("ERROR: Farming manager is not linked.")
