extends Resource
class_name GameConfig

# Game configuration values to replace magic numbers (follows .cursor/rules/godot.md)
@export var hud_slot_count: int = 10
@export var inventory_slot_count: int = 12
@export var max_item_stack: int = 99
@export var interaction_distance: float = 250.0  # Allow interaction with tiles up to ~15 cells away (16px per cell)
@export var player_speed: float = 200
@export var pickup_radius: float = 48.0
