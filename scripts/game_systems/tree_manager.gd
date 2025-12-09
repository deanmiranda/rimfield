extends Node

# TreeManager - Manages all trees in the game, handles registration, growth, spawning, and persistence
# Tree registry: tree_id: String → {"node": Tree, "position": Vector2, "tree_type": int, "growth_stage": int, "days_at_stage": int, "scene_name": String}

# Import Tree enums from tree.gd
const TreeType = preload("res://scripts/world/trees/tree.gd").TreeType
const TreeStage = preload("res://scripts/world/trees/tree.gd").TreeStage

signal tree_grew(tree_id: String, new_stage: int)
signal tree_spawned(tree_id: String, position: Vector2)

var tree_registry: Dictionary = {}
var tree_id_counter: int = 0
var pending_restore_data: Array = []

# Growth configuration: days required at each stage before advancing
const GROWTH_DAYS_PER_STAGE := {
	TreeType.MAPLE: {
		TreeStage.SAPLING: 3,
		TreeStage.MID: 5,
		TreeStage.ADULT: 7,
	},
	TreeType.OAK: {
		TreeStage.SAPLING: 4,
		TreeStage.MID: 6,
		TreeStage.ADULT: 8,
	},
	TreeType.PINE: {
		TreeStage.SAPLING: 2,
		TreeStage.MID: 4,
		TreeStage.ADULT: 6,
	},
}

var farm_scene: Node2D = null


func _ready() -> void:
	# Registry is already initialized at class level
	# Do NOT clear it here - that would wipe saved data during scene rebuilds on load_game()
	pass


func reset_all() -> void:
	"""Reset all tree data (for new game)."""
	# Remove all tree nodes from scene
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var tree_node = tree_data.get("node")
		if tree_node and is_instance_valid(tree_node):
			if tree_node.get_parent():
				tree_node.get_parent().remove_child(tree_node)
			tree_node.queue_free()
	
	# Clear registries
	tree_registry = {}
	pending_restore_data = []
	tree_id_counter = 0


func set_farm_scene(scene: Node2D) -> void:
	"""Set farm scene reference."""
	farm_scene = scene


func connect_signals() -> void:
	"""Connect TreeManager to required signals."""
	if GameTimeManager:
		if not GameTimeManager.day_changed.is_connected(_on_day_changed):
			GameTimeManager.day_changed.connect(_on_day_changed)


func register_tree(tree: Node2D) -> String:
	"""Register a tree and assign it a unique ID. Returns the tree_id."""
	if not tree:
		push_error("TreeManager: Cannot register null tree")
		return ""
	
	# Check if tree already has an ID (from save/load)
	var existing_id = ""
	if "tree_id" in tree:
		existing_id = tree.tree_id
	
	if existing_id != "":
		if tree_registry.has(existing_id):
			# Tree already registered with this ID
			tree_registry[existing_id]["node"] = tree
			return existing_id
		else:
			# Tree has ID but not in registry - restore it
			var tree_type = tree.tree_type
			var growth_stage = tree.growth_stage
			var grid_pos = tree.grid_position
			
			var scene_name = _get_current_scene_name()
			tree_registry[existing_id] = {
				"node": tree,
				"position": tree.global_position,
				"tree_type": tree_type,
				"growth_stage": growth_stage,
				"days_at_stage": 0,
				"scene_name": scene_name,
				"grid_position": grid_pos
			}
			return existing_id
	
	# Generate new ID
	var tree_id = "tree_%d" % tree_id_counter
	tree_id_counter += 1
	
	# Get tree properties
	var tree_type = tree.tree_type
	var growth_stage = tree.growth_stage
	var grid_pos = tree.grid_position
	
	var scene_name = _get_current_scene_name()
	tree_registry[tree_id] = {
		"node": tree,
		"position": tree.global_position,
		"tree_type": tree_type,
		"growth_stage": growth_stage,
		"days_at_stage": 0,
		"scene_name": scene_name,
		"grid_position": grid_pos
	}
	
	# Store tree_id on the tree node for future reference
	tree.tree_id = tree_id
	
	return tree_id


func spawn_tree_at_position(position: Vector2, tree_type: int, initial_stage: int = 0) -> String:
	"""Spawn a new tree at the specified position. Returns tree_id or empty string if failed."""
	# Validate position
	if not _is_valid_tree_position(position):
		push_error("TreeManager: Invalid tree position: %s" % position)
		return ""
	
	# Load Tree scene
	var tree_scene = load("res://scenes/world/tree.tscn")
	if not tree_scene:
		push_error("TreeManager: Could not load tree scene")
		return ""
	
	# Instantiate tree
	var tree_instance = tree_scene.instantiate()
	if not tree_instance:
		push_error("TreeManager: Could not instantiate tree")
		return ""
	
	# Configure tree
	tree_instance.set_tree_type(tree_type)
	tree_instance.set_growth_stage(initial_stage)
	tree_instance.global_position = position
	
	# Add to WorldActors for Y-sorting
	var world_actors = null
	if farm_scene:
		world_actors = farm_scene.get_node_or_null("WorldActors")
	
	if world_actors:
		world_actors.add_child(tree_instance)
	else:
		# Fallback: add to farm scene root
		if farm_scene:
			farm_scene.add_child(tree_instance)
		else:
			push_error("TreeManager: Cannot spawn tree - no farm_scene reference")
			tree_instance.queue_free()
			return ""
	
	# Register the tree
	var tree_id = register_tree(tree_instance)
	
	# Emit signal
	tree_spawned.emit(tree_id, position)
	
	return tree_id


func _is_valid_tree_position(position: Vector2) -> bool:
	"""Check if position is valid for tree placement."""
	if not farm_scene:
		return false
	
	# Check for existing tree at this position (within 16 pixels)
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var existing_pos = tree_data.get("position", Vector2.ZERO)
		if position.distance_to(existing_pos) < 16.0:
			return false
	
	return true


func serialize_all_trees() -> Array:
	"""Serialize all trees for save. Returns array of tree data dictionaries."""
	var tree_data_array: Array = []
	
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var tree_node = tree_data.get("node")
		var position = tree_data.get("position", Vector2.ZERO)
		var tree_type = tree_data.get("tree_type", TreeType.MAPLE)
		var growth_stage = tree_data.get("growth_stage", TreeStage.SAPLING)
		var days_at_stage = tree_data.get("days_at_stage", 0)
		var scene_name = tree_data.get("scene_name", "")
		var grid_position = tree_data.get("grid_position", Vector2i(-1, -1))
		
		# Update position from node if available
		if tree_node and is_instance_valid(tree_node):
			if tree_node is Node2D:
				position = tree_node.global_position
		
		# Only save tree if node exists or has valid data
		if tree_node and is_instance_valid(tree_node):
			tree_data_array.append({
				"tree_id": tree_id,
				"position": {"x": position.x, "y": position.y},
				"tree_type": tree_type,
				"growth_stage": growth_stage,
				"days_at_stage": days_at_stage,
				"scene_name": scene_name,
				"grid_position": {"x": grid_position.x, "y": grid_position.y}
			})
	
	return tree_data_array


func restore_trees_from_save(tree_data: Array) -> void:
	"""Restore trees from save data. Stores tree data in registry for scene restoration."""
	# CRITICAL: Clear registry completely before restoring to prevent cross-save contamination
	tree_registry.clear()
	pending_restore_data = tree_data
	
	# Add tree data to registry (without nodes yet - those will be created when scenes load)
	for save_data in tree_data:
		var tree_id = save_data.get("tree_id", "")
		var position_data = save_data.get("position", {"x": 0, "y": 0})
		var position = Vector2(position_data["x"], position_data["y"])
		var tree_type = save_data.get("tree_type", TreeType.MAPLE)
		var growth_stage = save_data.get("growth_stage", TreeStage.SAPLING)
		var days_at_stage = save_data.get("days_at_stage", 0)
		var scene_name = save_data.get("scene_name", "")
		var grid_pos_data = save_data.get("grid_position", {"x": - 1, "y": - 1})
		var grid_position = Vector2i(grid_pos_data["x"], grid_pos_data["y"])
		
		if tree_id != "":
			tree_registry[tree_id] = {
				"node": null,
				"position": position,
				"tree_type": tree_type,
				"growth_stage": growth_stage,
				"days_at_stage": days_at_stage,
				"scene_name": scene_name,
				"grid_position": grid_position
			}
			
			# Update tree_id_counter to avoid conflicts
			if tree_id.begins_with("tree_"):
				var id_num_str = tree_id.substr(5)
				var id_num = int(id_num_str)
				if id_num >= tree_id_counter:
					tree_id_counter = id_num + 1


func restore_trees_for_scene(scene_name: String) -> void:
	"""Restore trees for a specific scene when it loads."""
	if not scene_name:
		return
	
	# Clear nodes for other scenes first
	clear_nodes_for_other_scenes(scene_name)
	
	# Get tree scene
	var tree_scene = load("res://scenes/world/tree.tscn")
	if not tree_scene:
		push_error("TreeManager: Could not load tree scene")
		return
	
	# Find WorldActors node for Y-sorting
	var world_actors = null
	if farm_scene:
		world_actors = farm_scene.get_node_or_null("WorldActors")
	
	# Find trees for this scene in the registry
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var saved_scene_name = tree_data.get("scene_name", "")
		var has_tree_node = tree_data.get("node") != null
		
		# Only restore if this tree belongs to the current scene and doesn't have a node
		if saved_scene_name == scene_name and not has_tree_node:
			var position = tree_data.get("position", Vector2.ZERO)
			var tree_type = tree_data.get("tree_type", TreeType.MAPLE)
			var growth_stage = tree_data.get("growth_stage", TreeStage.SAPLING)
			var grid_position = tree_data.get("grid_position", Vector2i(-1, -1))
			
			# Create tree at position with existing tree_id
			var tree_instance = tree_scene.instantiate()
			if tree_instance:
				# Configure tree
				tree_instance.set_tree_type(tree_type)
				tree_instance.set_growth_stage(growth_stage)
				tree_instance.set_grid_position(grid_position)
				tree_instance.global_position = position
				
				# Store tree_id on node before adding to scene
				tree_instance.tree_id = tree_id
				
				# Add to WorldActors or farm scene
				if world_actors:
					world_actors.add_child(tree_instance)
				elif farm_scene:
					farm_scene.add_child(tree_instance)
				
				# Update registry with node reference
				tree_registry[tree_id]["node"] = tree_instance


func clear_nodes_for_other_scenes(current_scene_name: String) -> void:
	"""Clear node references for trees that don't belong to current scene."""
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var saved_scene_name = tree_data.get("scene_name", "")
		var tree_node = tree_data.get("node")
		
		if saved_scene_name != current_scene_name and tree_node:
			# This tree belongs to a different scene - clear its node reference
			if is_instance_valid(tree_node):
				if tree_node.get_parent():
					tree_node.get_parent().remove_child(tree_node)
				tree_node.queue_free()
			tree_registry[tree_id]["node"] = null


func _get_current_scene_name() -> String:
	"""Get the current scene name for tracking which scene the tree belongs to."""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.name
	return ""


func _on_day_changed(_new_day: int, _new_season: int, _new_year: int) -> void:
	"""Handle day change - advance tree growth."""
	_advance_tree_growth()


func _advance_tree_growth() -> void:
	"""Advance growth for all registered trees."""
	for tree_id in tree_registry.keys():
		var tree_data = tree_registry[tree_id]
		var tree_node = tree_data.get("node")
		var current_stage = tree_data.get("growth_stage", TreeStage.SAPLING)
		var tree_type = tree_data.get("tree_type", TreeType.MAPLE)
		var days_at_stage = tree_data.get("days_at_stage", 0)
		
		# Skip if tree is fully grown
		if current_stage == TreeStage.FULLY_GROWN:
			continue
		
		# Skip if tree node is invalid
		if not tree_node or not is_instance_valid(tree_node):
			continue
		
		# Get growth days required for current stage
		var growth_config = GROWTH_DAYS_PER_STAGE.get(tree_type, {})
		var days_required = growth_config.get(current_stage, 999)
		
		# Increment days at current stage
		days_at_stage += 1
		tree_registry[tree_id]["days_at_stage"] = days_at_stage
		
		# Check if ready to advance
		if days_at_stage >= days_required:
			# Advance to next stage
			var next_stage = _get_next_stage(current_stage)
			if next_stage != current_stage:
				tree_registry[tree_id]["growth_stage"] = next_stage
				tree_registry[tree_id]["days_at_stage"] = 0
				
				# Update tree node
				tree_node.set_growth_stage(next_stage)
				
				# Update position in registry
				tree_registry[tree_id]["position"] = tree_node.global_position
				
				# Emit signal
				tree_grew.emit(tree_id, next_stage)


func _get_next_stage(current_stage: int) -> int:
	"""Get the next growth stage after current stage."""
	if current_stage == TreeStage.SAPLING:
		return TreeStage.MID
	elif current_stage == TreeStage.MID:
		return TreeStage.ADULT
	elif current_stage == TreeStage.ADULT:
		return TreeStage.FULLY_GROWN
	else:
		return current_stage


func get_tree_data(tree_id: String) -> Dictionary:
	"""Get tree data by ID. Returns empty dictionary if not found."""
	return tree_registry.get(tree_id, {})


func get_tree_node(tree_id: String) -> Node2D:
	"""Get tree node by ID. Returns null if not found."""
	var tree_data = tree_registry.get(tree_id, {})
	return tree_data.get("node", null)
