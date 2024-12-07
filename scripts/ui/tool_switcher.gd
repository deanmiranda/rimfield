extends Node

signal tool_changed(slot_index: int, item_texture: Texture)  # Signal for tool changes

var current_hud_slot: int = -1  # Currently active tool slot index
var current_tool_texture: Texture = null  # Texture of the currently active tool
var current_tool: String = "unknown"  # Default to unknown

 #Tool mapping from texture to tool name
const TOOL_MAP = {
	preload("res://assets/tiles/tools/shovel.png"): "hoe",
	preload("res://assets/tiles/tools/rototiller.png"): "till",
	preload("res://assets/tiles/tools/pick-axe.png"): "pickaxe",
	preload("res://assets/tilesets/full version/tiles/FartSnipSeeds.png"): "seed"
}

func _ready() -> void:
	# Access HUD via sibling relationship
	var hud = get_node("../HUD")
	if hud:
		if not is_connected("tool_changed", Callable(hud, "_highlight_active_tool")):
			connect("tool_changed", Callable(hud, "_highlight_active_tool"))
	else:
		print("Error: HUD not found as sibling.")

func _input(event: InputEvent) -> void:
	# Handle key inputs to switch tools based on slot numbers (1-0)
	for i in range(10):  # Keys 1-0 correspond to HUD slots 0-9
		var action = "ui_hud_" + str(i + 1)
		if i == 9:  # Special case for "0" key (maps to slot 9)
			action = "ui_hud_0"
		if event.is_action_pressed(action):
			set_hud_by_slot(i)

func set_hud_by_slot(slot_index: int) -> void:
	var hud = get_node("../HUD")
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
			var item_texture = hud_slot.get_texture() if hud_slot.has_method("get_texture") else null
			
			if item_texture:
				current_hud_slot = slot_index
				current_tool_texture = item_texture
				# Map texture to tool name
				current_tool = TOOL_MAP.get(item_texture, "unknown")
				
				emit_signal("tool_changed", slot_index, item_texture)
			else:
				print("Tool node in slot ", slot_index, " is empty. Cannot set tool.")
		else:
			print("Tool slot not found at path:", slot_path)
	else:
		print("TextureButton not found at path:", button_path)
