extends VisualInstance3D

var timer: Timer
var fps: float = 0
var current_child: Node

# Called when the node enters the scene tree for the first time.
func _ready():
	for child in find_children('*', "", false, false):  # TODO: owned should be true
		child.hide()
		child.visibility_changed.connect(handle_child_visibility_changed.bind(child))
	current_child = get_child(0)
	current_child.show()
	timer = Timer.new()
	timer.name = 'SwitchTimer'
	add_child(timer, false, Node.INTERNAL_MODE_FRONT)
	if fps > 0:
		timer.wait_time = 1 / fps
		timer.timeout.connect(show_next_child)
		timer.start()

func handle_child_visibility_changed(child):
	if child.visible:
		current_child.hide()
		current_child = child
		#for other_child in find_children('*', "", false, false):
		#	if other_child != child and other_child.visible:
		#		other_child.hide()

func show_next_child():
	var child_index = current_child.get_index()
	if child_index == get_child_count() - 1:
		get_child(0).show()
	else:
		get_child(child_index + 1).show()
