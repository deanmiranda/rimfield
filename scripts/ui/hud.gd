
### hud.gd ###
extends CanvasLayer

signal tool_changed(new_tool: String)  # Signal to notify tool changes

const PICK_AXE = preload("res://assets/tiles/tools/pick-axe.png")
const ROTOTILLER = preload("res://assets/tiles/tools/rototiller.png")
const SHOVEL = preload("res://assets/tiles/tools/shovel.png")

@export var tool_icons: Array = [SHOVEL, ROTOTILLER, PICK_AXE]

func _ready() -> void:
	var margin_container = $MarginContainer
	var hbox = margin_container.get_node("HBoxContainer")

	# Add tool icons dynamically
	for i in range(tool_icons.size()):
		var texture_rect = TextureRect.new()
		texture_rect.texture = tool_icons[i]
		texture_rect.tooltip_text = get_tool_name(i)
		texture_rect.mouse_filter = TextureRect.MOUSE_FILTER_PASS
		texture_rect.name = "tool_slot_%d" % i
		texture_rect.set_meta("tool_index", i)
		texture_rect.connect("gui_input", Callable(self, "_on_tool_clicked").bind(texture_rect))
		hbox.add_child(texture_rect)

func get_tool_name(index: int) -> String:
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
				0: emit_signal("tool_changed", "hoe")
				1: emit_signal("tool_changed", "till")
				2: emit_signal("tool_changed", "pickaxe")
