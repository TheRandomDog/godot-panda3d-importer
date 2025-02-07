extends PandaNode
class_name PandaGeomNode
## A PandaNode that holds geometry information.
##
## This node will act as our entry point for rendering any mesh geometry.

var o_geoms: Array[PandaGeomInfo]

class PandaGeomInfo:
	var geom: PandaGeom
	var render_state: PandaRenderState
	
func parse_object_data() -> void:
	super()
	var geoms_count = bam_parser.decode_u16()
	var geom_info: PandaGeomInfo
	for i in range(geoms_count):
		geom_info = PandaGeomInfo.new()
		geom_info.geom = bam_parser.decode_and_follow_pointer() as PandaGeom
		geom_info.render_state = bam_parser.decode_and_follow_pointer() as PandaRenderState
		o_geoms.append(geom_info)

## Converts this [PandaNode] into a Godot node. [br][br]
##
## [GeomNode] objects will convert into a [MeshInstance3D].
func convert() -> MeshInstance3D:
	# Create a new array mesh for this GeomNode.
	var mesh := ArrayMesh.new()
	var mesh_surface_count := 0
	
	# This GeomNode may be the parent of multiple geometries,
	# we'll take all of them.
	for geom_info in o_geoms:
		var geom := geom_info.geom
		# We try to keep good track of surface data for these meshes. A lot of
		# mesh data, such as textures, colors, etc. each require their own
		# Material in Godot whereas such features are standalone in Panda3D.
		#
		# To be efficient, we want to reuse Materials as much as possible,
		# which is what this helper class aims to do.
		var surface := Surface.new()
		
		# Get the base array containing our mesh data. This contains most
		# everything other than special render data and vertex indexing.
		var mesh_array = geom.create_base_mesh_array()
		var mesh_array_flags = geom.get_mesh_array_flags()
		
		# Apply render attributes and effects to the mesh surface.
		for attrib in geom_info.render_state.o_attribs:
			attrib.apply_to_surface(surface)
		for effect in o_effects.o_effects:
			effect.apply_to_surface(surface)
		
		# Pull vertex index information from each primitive.
		for primitive in geom.o_primitives:
			mesh_array[Mesh.ARRAY_INDEX] = primitive._get_vertex_indices()
			mesh.add_surface_from_arrays(
				primitive._get_primitive_type(),
				mesh_array,
				[], {},
				mesh_array_flags
			)
			# Finalize the mesh surface.
			mesh.surface_set_material(mesh_surface_count, surface.finalize())
			mesh_surface_count += 1
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	# Apply the standard conversions for a PandaNode now.
	_convert_node(mesh_instance)
	return mesh_instance
