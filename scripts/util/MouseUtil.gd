extends Node

class_name MouseUtil

static func _resolve_viewport(node: Node) -> Viewport:
	var vp: Viewport
	if node is CanvasItem:
		vp = (node as CanvasItem).get_viewport()
	else:
		var tree := node.get_tree()
		if tree != null:
			vp = tree.root
	return vp  # may be null

static func get_viewport_mouse_pos(node: Node) -> Vector2:
	var vp := _resolve_viewport(node)
	if vp == null:
		push_warning("MouseUtil: No viewport available.")
		return Vector2.ZERO
	return vp.get_mouse_position()

static func get_world_mouse_pos_2d(node: Node) -> Vector2:
	var vp := _resolve_viewport(node)
	if vp == null:
		push_warning("MouseUtil: No viewport available.")
		return Vector2.ZERO
	var cam: Camera2D = vp.get_camera_2d()
	if cam != null:
		# Use Godot's built-in method to convert screen coordinates to world coordinates
		# This properly accounts for camera position, zoom, and transform
		return cam.get_global_mouse_position()
	# Fallback if no camera (shouldn't happen in normal gameplay)
	var p: Vector2 = vp.get_mouse_position()
	return p
