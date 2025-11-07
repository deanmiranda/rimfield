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
	var p: Vector2 = vp.get_mouse_position()
	var cam: Camera2D = vp.get_camera_2d()
	if cam != null:
		# Convert screen coordinates to world coordinates using camera transform
		# Formula: world_pos = camera.global_position + (screen_pos - viewport_center) / zoom
		var viewport_center: Vector2 = vp.size / 2.0
		var offset: Vector2 = (p - viewport_center) / cam.zoom
		return cam.global_position + offset
	return p
