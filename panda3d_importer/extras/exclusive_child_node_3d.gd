@tool
extends Node3D

var current_visible_index := -1

func _enter_tree() -> void:
	child_entered_tree.connect(_setup_child)
	child_exiting_tree.connect(_handle_child_exiting)

func _setup_child(child: Node) -> void:
	if child is Node3D and not child.visibility_changed.is_connected(_handle_child_visibility_changed):
		if current_visible_index == -1:
			child.visible = true
			current_visible_index = child.get_index()
		else:
			child.visible = false
		child.visibility_changed.connect(_handle_child_visibility_changed.bind(child))

func _handle_child_visibility_changed(child: Node) -> void:
	if child.visible:
		var current_child := get_child(current_visible_index)
		current_child.visible = false
		current_visible_index = child.get_index()

func _handle_child_exiting(child: Node) -> void:
	if child is Node3D and child.get_index() == current_visible_index:
		current_visible_index = find_children('*', 'Node3D', false, false).size() - 1
