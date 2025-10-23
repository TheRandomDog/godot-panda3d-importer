@tool
@icon('ExclusiveChildNode.svg')
extends Node
class_name ExclusiveChildNode

var current_visible_index := -1

func _init() -> void:
	Behavior.setup_parent(self)


class Behavior extends Object:
	static func setup_parent(parent: Node) -> void:
		parent.child_entered_tree.connect(_setup_child.bind(parent))
		parent.child_exiting_tree.connect(_handle_child_exiting.bind(parent))

	static func _setup_child(child: Node, parent: Node) -> void:
		if (
			child.is_class(parent.get_class())
			and not child.visibility_changed.is_connected(
				_handle_child_visibility_changed
			)
		):
			if parent.current_visible_index == -1:
				child.visible = true
				parent.current_visible_index = child.get_index()
			else:
				child.visible = false
			child.visibility_changed.connect(
				_handle_child_visibility_changed.bind(parent, child)
			)

	static func _handle_child_visibility_changed(child: Node, parent: Node) -> void:
		if child.visible:
			var current_child := parent.get_child(parent.current_visible_index)
			current_child.visible = false
			parent.current_visible_index = child.get_index()

	static func _handle_child_exiting(child: Node, parent: Node) -> void:
		if (
			child.is_class(parent.get_class())
			and child.get_index() <= parent.current_visible_index
		):
			parent.current_visible_index -= 1
