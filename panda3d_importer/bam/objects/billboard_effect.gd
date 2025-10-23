extends PandaRenderEffect
class_name PandaBillboardEffect

var off: bool
var up_vector: Vector3
var eye_relative: bool
var axial_rotate: bool
var offset: float
var look_at_point: Vector3

var _look_at: WeakRef = null  # 6.43+
var look_at: PandaNode:
	get:
		return get_object(_look_at)

var fixed_depth: bool = false  # 6.43+

func parse_object_data() -> void:
	super()
	off = datagram.decode_bool()
	up_vector = datagram.decode_vector3(datagram.decode_stdfloat)
	eye_relative = datagram.decode_bool()
	axial_rotate = datagram.decode_bool()
	offset = datagram.decode_stdfloat()
	look_at_point = datagram.decode_vector3(datagram.decode_stdfloat)

	if bam_parser.version >= [6, 43]:
		_look_at = datagram.next_object_ref_or_null(PandaNode)
		fixed_depth = datagram.decode_bool()

func apply_to_surface(surface: Surface):
	if off:
		return
	# TEMP
	surface.add_billboard()

func apply_to_node(node: Node3D, panda_node: PandaNode) -> void:
	return
	if off:
		return
	# TEMP
	if node is MeshInstance3D:
		if node.mesh.get_surface_count() > 0:
			var material: Material = node.mesh.surface_get_material(0)
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			material.billboard_keep_scale = true
		#material.
