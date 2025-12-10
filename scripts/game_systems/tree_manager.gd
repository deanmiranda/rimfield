extends Node

# TreeManager - Manages all trees in the Farm scene
# Tree registry: tree_id: String → {"node": Tree, "position": Vector2, "tree_type": TreeType, "growth_stage": TreeStage, "days_at_stage": int, "scene_name": String}

# Growth days per stage (days required to advance to next stage)
# Format: {tree_type: {growth_stage: days_required}}
const GROWTH_DAYS_PER_STAGE := {
	0: { # MAPLE
		0: 3, # SAPLING -> MID
		1: 5, # MID -> ADULT
		2: 7, # ADULT -> FULLY_GROWN
	},
	1: { # OAK
		0: 4, # SAPLING -> MID
		1: 6, # MID -> ADULT
		2: 8, # ADULT -> FULLY_GROWN
	},
	2: { # PINE
		0: 2, # SAPLING -> MID
		1: 4, # MID -> ADULT
		2: 6, # ADULT -> FULLY_GROWN
	}
}

var tree_registry: Dictionary = {}
var tree_id_counter: int = 0
var pending_restore_data: Array = [] # Store tree data to restore when trees are instantiated


func _ready() -> void:
	"""Connect signals on ready and check for pending tree data from save."""
	connect_signals()
	
	# Check if GameState has pending tree data from load
	if GameState and GameState.has_meta("pending_tree_data"):
		var tree_data_to_restore = GameState.get_meta("pending_tree_data")
		GameState.remove_meta("pending_tree_data") # Clear after reading
		restore_trees_from_save(tree_data_to_restore)


func connect_signals() -> void:
	"""Connect to GameTimeManager for day changes."""
	if GameTimeManager:
		if not GameTimeManager.day_changed.is_connected(_on_day_changed):
			GameTimeManager.day_changed.connect(_on_day_changed)
	else:
		push_error("TreeManager: GameTimeManager not found!")


func _on_day_changed(_new_day: int, _new_season: int, _new_year: int) -> void:
	"""Handle day change event from GameTimeManager."""
	_advance_tree_growth()


func _advance_tree_growth() -> void:
	"""Increment days_at_stage for all trees and advance growth stages if thresholds met."""
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var tree_node = tree_data.get("node")
		
		# Skip if tree node is invalid
		if not tree_node or not is_instance_valid(tree_node):
			continue
		
		var tree_type: int = tree_data.get("tree_type", 0)
		var growth_stage: int = tree_data.get("growth_stage", 0)
		var days_at_stage: int = tree_data.get("days_at_stage", 0)
		
		# Skip if tree is already fully grown (stage 3)
		if growth_stage >= 3:
			continue
		
		# Increment days at current stage
		days_at_stage += 1
		tree_registry[tree_id]["days_at_stage"] = days_at_stage
		
		# Check if tree should advance to next stage
		var days_required = _get_days_required_for_stage(tree_type, growth_stage)
		if days_at_stage >= days_required:
			# Advance to next stage
			var new_stage = growth_stage + 1
			tree_registry[tree_id]["growth_stage"] = new_stage
			tree_registry[tree_id]["days_at_stage"] = 0 # Reset days counter for new stage
			
			# Update tree node visuals
			if tree_node.has_method("set_growth_stage"):
				tree_node.set_growth_stage(new_stage)


func _get_days_required_for_stage(tree_type: int, current_stage: int) -> int:
	"""Get the number of days required to advance from current_stage to next stage."""
	if GROWTH_DAYS_PER_STAGE.has(tree_type):
		var stage_data = GROWTH_DAYS_PER_STAGE[tree_type]
		if stage_data.has(current_stage):
			return stage_data[current_stage]
	
	# Fallback: default to 5 days if not specified
	return 5


func register_tree(tree: Node2D) -> String:
	"""Register a tree and assign it a unique ID. Returns the tree_id."""
	if not tree:
		push_error("TreeManager: Cannot register null tree")
		return ""
	
	# Check if tree already has an ID (from save/load)
	var tree_id: String = ""
	if "tree_id" in tree:
		tree_id = tree.tree_id
	
	# If no ID, generate new one
	if tree_id == "":
		tree_id_counter += 1
		tree_id = "tree_%d" % tree_id_counter
	
	# Get tree properties
	var tree_type = tree.get_tree_type() if tree.has_method("get_tree_type") else 0
	var growth_stage = tree.get_growth_stage() if tree.has_method("get_growth_stage") else 0
	var position: Vector2 = tree.global_position if tree is Node2D else Vector2.ZERO
	var scene_name = _get_current_scene_name()
	
	# Initialize days_at_stage (start at 0 for newly registered trees)
	var days_at_stage: int = 0
	
	# Store in registry
	tree_registry[tree_id] = {
		"node": tree,
		"position": position,
		"tree_type": tree_type,
		"growth_stage": growth_stage,
		"days_at_stage": days_at_stage,
		"scene_name": scene_name
	}
	
	# Set tree ID on the tree node
	if "tree_id" in tree:
		tree.tree_id = tree_id
	
	return tree_id


func spawn_tree_at_position(position: Vector2, tree_type: int, initial_stage: int = 0) -> String:
	"""Spawn a new tree at the specified position.
	
	Args:
		position: World position where the tree should be spawned
		tree_type: TreeType enum value (0=MAPLE, 1=OAK, 2=PINE)
		initial_stage: TreeStage enum value (0=SAPLING, 1=MID, 2=ADULT, 3=FULLY_GROWN)
	
	Returns:
		tree_id of the spawned tree, or empty string if spawn failed
	"""
	
	# Validation 1: Check for overlap with existing trees
	const OVERLAP_RADIUS = 16.0 # Minimum distance between trees
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var tree_node = tree_data.get("node")
		if tree_node and is_instance_valid(tree_node):
			var distance = tree_node.global_position.distance_to(position)
			if distance < OVERLAP_RADIUS:
				push_error("TreeManager: Cannot spawn tree at %s - too close to existing tree %s (distance: %.1f)" % [position, tree_id, distance])
				return ""
	
	# Validation 2: Get WorldActors from current scene
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("TreeManager: Cannot spawn tree - no current scene")
		return ""
	
	var world_actors = current_scene.get_node_or_null("WorldActors")
	if not world_actors:
		push_error("TreeManager: Cannot spawn tree - WorldActors not found in scene")
		return ""
	
	# Load and instantiate tree scene
	var tree_scene = load("res://scenes/world/tree.tscn")
	if not tree_scene:
		push_error("TreeManager: Could not load tree scene")
		return ""
	
	var tree_instance = tree_scene.instantiate()
	if not tree_instance:
		push_error("TreeManager: Could not instantiate tree scene")
		return ""
	
	# Set tree properties BEFORE adding to scene tree
	if tree_instance.has_method("set_tree_type"):
		tree_instance.set_tree_type(tree_type)
	if tree_instance.has_method("set_growth_stage"):
		tree_instance.set_growth_stage(initial_stage)
	
	# Set position
	tree_instance.global_position = position
	
	# Add to WorldActors
	world_actors.add_child(tree_instance)
	
	# Register the tree
	var tree_id = register_tree(tree_instance)
	
	return tree_id


func serialize_all_trees() -> Array:
	"""Serialize all trees for save. Returns array of tree data dictionaries."""
	var tree_data_array: Array = []
	
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var tree_node = tree_data.get("node")
		var position = tree_data.get("position", Vector2.ZERO)
		var tree_type = tree_data.get("tree_type", 0)
		var growth_stage = tree_data.get("growth_stage", 0)
		var days_at_stage = tree_data.get("days_at_stage", 0)
		var scene_name = tree_data.get("scene_name", "")
		
		# Only save tree if node still exists or if we have valid data
		if (tree_node and is_instance_valid(tree_node)) or scene_name != "":
			tree_data_array.append({
				"tree_id": tree_id,
				"position": {"x": position.x, "y": position.y},
				"tree_type": tree_type,
				"growth_stage": growth_stage,
				"days_at_stage": days_at_stage,
				"scene_name": scene_name
			})
	
	return tree_data_array


func restore_trees_from_save(tree_data: Array) -> void:
	"""Restore trees from save data. Stores tree data in registry for scene restoration."""
	# Clear registry completely before restoring to prevent cross-save contamination
	tree_registry.clear()
	pending_restore_data = tree_data
	
	# Add tree data to registry (without nodes yet - those will be created when scenes load)
	for save_data in tree_data:
		var tree_id = save_data.get("tree_id", "")
		var position_data = save_data.get("position", {"x": 0, "y": 0})
		var position = Vector2(position_data["x"], position_data["y"])
		var tree_type = save_data.get("tree_type", 0)
		var growth_stage = save_data.get("growth_stage", 0)
		var days_at_stage = save_data.get("days_at_stage", 0)
		var scene_name = save_data.get("scene_name", "")
		
		# Store in registry (without node - will be created when scene loads)
		tree_registry[tree_id] = {
			"node": null,
			"position": position,
			"tree_type": tree_type,
			"growth_stage": growth_stage,
			"days_at_stage": days_at_stage,
			"scene_name": scene_name
		}
		
		# Update counter to prevent ID collision
		var id_number = tree_id.trim_prefix("tree_").to_int()
		if id_number > tree_id_counter:
			tree_id_counter = id_number


func restore_trees_for_scene(scene_name: String) -> void:
	"""Restore trees for a specific scene when it loads."""
	if not scene_name:
		return
	
	# Get current scene and WorldActors
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	var world_actors = current_scene.get_node_or_null("WorldActors")
	if not world_actors:
		push_error("TreeManager: Cannot restore trees - WorldActors not found")
		return
	
	# Find trees for this scene in the registry
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var saved_scene_name = tree_data.get("scene_name", "")
		var has_tree_node = tree_data.get("node") != null
		
		# Only restore if this tree belongs to the current scene and doesn't have a node
		if saved_scene_name == scene_name and not has_tree_node:
			var position = tree_data.get("position", Vector2.ZERO)
			var tree_type = tree_data.get("tree_type", 0)
			var growth_stage = tree_data.get("growth_stage", 0)
			var days_at_stage = tree_data.get("days_at_stage", 0)
			
			# Load and instantiate tree scene
			var tree_scene = load("res://scenes/world/tree.tscn")
			if not tree_scene:
				push_error("TreeManager: Could not load tree scene")
				continue
			
			var tree_instance = tree_scene.instantiate()
			if not tree_instance:
				push_error("TreeManager: Could not instantiate tree scene")
				continue
			
			# Set tree ID BEFORE adding to scene tree (prevents register_tree from generating new ID)
			if "tree_id" in tree_instance:
				tree_instance.tree_id = tree_id
			
			# Set tree properties
			if tree_instance.has_method("set_tree_type"):
				tree_instance.set_tree_type(tree_type)
			if tree_instance.has_method("set_growth_stage"):
				tree_instance.set_growth_stage(growth_stage)
			
			# Set position
			tree_instance.global_position = position
			
			# Add to WorldActors
			world_actors.add_child(tree_instance)
			
			# Update registry with node reference and restored days_at_stage
			tree_registry[tree_id]["node"] = tree_instance
			tree_registry[tree_id]["days_at_stage"] = days_at_stage


func _get_current_scene_name() -> String:
	"""Get the current scene name."""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return ""
	
	# Try to get scene name from scene file path
	var scene_path = current_scene.scene_file_path
	if scene_path.ends_with("farm_scene.tscn"):
		return "Farm"
	
	# Fallback: use scene name
	return current_scene.name
