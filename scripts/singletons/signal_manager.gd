extends Node

func connect_tool_changed(emitter: Node, receiver: Node) -> void:
	if not emitter.is_connected("tool_changed", Callable(receiver, "_on_tool_changed")):
		emitter.connect("tool_changed", Callable(receiver, "_on_tool_changed"))
		print("DEBUG: Connected tool_changed from", emitter.name, "to", receiver.name)
