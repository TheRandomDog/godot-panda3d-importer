@tool
@icon('ExclusiveChildNode2D.svg')
extends Node2D
class_name ExclusiveChildNode2D

var current_visible_index := -1

func _init() -> void:
	ExclusiveChildNode.Behavior.setup_parent(self)
