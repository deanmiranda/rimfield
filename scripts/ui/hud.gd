extends CanvasLayer

signal tool_changed(new_tool: String)  # Declare the signal

const PICK_AXE = preload("res://assets/tiles/tools/pick-axe.png")
const ROTOTILLER = preload("res://assets/tiles/tools/rototiller.png")
const SHOVEL = preload("res://assets/tiles/tools/shovel.png")

@export var tool_icons: Array = [SHOVEL, ROTOTILLER, PICK_AXE]

func _ready() -> void:
	# Reference existing nodes
	var margin_container = $MarginContainer
	var hbox = margin_container.get_node("HBoxContainer")

	# Add tool icons to the HUD
	for i in range(tool_icons.size()):
		var texture_rect = TextureRect.new()
		texture_rect.texture = tool_icons[i]  # Use preloaded textures
		texture_rect.tooltip_text = get_tool_name(i)  # Set tooltip text
		texture_rect.mouse_filter = TextureRect.MOUSE_FILTER_PASS
		texture_rect.name = "tool_slot_%d" % i

		# Store the index as metadata for this TextureRect
		texture_rect.set_meta("tool_index", i)

		# Connect the click signal and bind the emitting node (texture_rect)
		texture_rect.connect("gui_input", Callable(self, "_on_tool_clicked").bind(texture_rect))

		hbox.add_child(texture_rect)  # Add TextureRect to the container

func get_tool_name(index: int) -> String:
	# Tooltips for each tool
	match index:
		0: return "Equip Shovel"
		1: return "Equip Rototiller"
		2: return "Equip Pickaxe"
		_: return "Unknown Tool"

func _on_tool_clicked(event: InputEvent, clicked_texture_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		if clicked_texture_rect and clicked_texture_rect.has_meta("tool_index"):
			var index = clicked_texture_rect.get_meta("tool_index")
			match index:
				0: emit_signal("tool_changed", "hoe")  # Equip Shovel as 'hoe'
				1: emit_signal("tool_changed", "till")  # Equip Rototiller as 'till'
				2: emit_signal("tool_changed", "pickaxe")  # Equip Pickaxe
