extends Node

class_name World2DUtil

# May return null -> omit return type annotation
static func get_world_2d_for(node: Node):
	var vp: Viewport
	if node is CanvasItem:
		vp = (node as CanvasItem).get_viewport()
	else:
		var tree := node.get_tree()
		if tree != null:
			vp = tree.root
	if vp == null:
		push_warning("World2DUtil: No viewport available.")
		return null
	return vp.get_world_2d()

