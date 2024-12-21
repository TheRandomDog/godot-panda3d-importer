@tool
extends Node

var timer: Timer
@export var playing := false:
	set(new):
		playing = new
		if playing:
			start_playing()
		else:
			stop_playing()
@export var fps: float = 0:
	set(new):
		fps = new
		if playing:
			start_playing()
@export var current_child: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	for child in get_parent().get_children():
		if child != self:
			child.hide()
			child.visibility_changed.connect(handle_child_visibility_changed.bind(child))
	current_child = get_parent().get_child(0)
	current_child.show()
	timer = Timer.new()
	timer.name = 'SwitchTimer'
	timer.timeout.connect(show_next_child)
	add_child(timer, false, Node.INTERNAL_MODE_FRONT)
	if playing:
		start_playing()
		
func start_playing():
	if fps > 0:
		timer.wait_time = 1 / fps
		timer.start()
	else:
		stop_playing()
		
func stop_playing():
	timer.stop()

func handle_child_visibility_changed(child):
	if child.visible:
		current_child.hide()
		current_child = child

func show_next_child():
	var child_index = current_child.get_index()
	var parent = get_parent()
	if child_index == parent.get_child_count() - 1:
		parent.get_child(0).show()
	else:
		parent.get_child(child_index + 1).show()
