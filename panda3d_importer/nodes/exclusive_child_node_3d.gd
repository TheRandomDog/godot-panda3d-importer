@tool
@icon('ExclusiveChildNode3D.svg')
extends Node3D
class_name ExclusiveChildNode3D

var current_visible_index := -1

func _init() -> void:
	ExclusiveChildNode.Behavior.setup_parent(self)
