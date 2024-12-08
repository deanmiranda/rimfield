# res://scripts/droppable_item.gd
@tool
extends Resource
class_name DroppableItem

@export var item_id: String = ""  # Unique identifier for the item
@export var texture: Texture  # The item's texture
@export var max_stack: int = 99  # Maximum stack size for the item
@export var description: String = ""  # Optional description of the item
