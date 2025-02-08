extends PandaRenderEffect
class_name PandaBillboardEffect

var off: bool
var up_vector: Vector3
var eye_relative: bool
var axial_rotate: bool
var offset: float
var look_at_point: Vector3

var o_look_at: PandaNode = null  # 6.43+
var fixed_depth: bool = false  # 6.43+

func parse_object_data() -> void:
	super()
	off = bam_parser.decode_bool()
	up_vector = bam_parser.decode_vector3(bam_parser.decode_stdfloat)
	eye_relative = bam_parser.decode_bool()
	axial_rotate = bam_parser.decode_bool()
	offset = bam_parser.decode_stdfloat()
	look_at_point = bam_parser.decode_vector3(bam_parser.decode_stdfloat)
	
	if bam_parser.version >= [6, 43]:
		o_look_at = bam_parser.decode_and_follow_pointer(true) as PandaNode
		fixed_depth = bam_parser.decode_bool()

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
