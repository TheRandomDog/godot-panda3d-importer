extends PandaNode
class_name PandaGeomNode
## A PandaNode that holds geometry information.
##
## This node will act as our entry point for rendering any mesh geometry.

var geoms: Array[GeomInfo]

func parse_object_data() -> void:
	super()
	geoms.assign(BAMStruct.make_array(GeomInfo, datagram))

## Converts this [PandaNode] into a Godot node. [br][br]
##
## [GeomNode] objects will convert into a [MeshInstance3D].
func convert() -> MeshInstance3D:
	# Create a new array mesh for this GeomNode.
	var mesh := ArrayMesh.new()
	var mesh_surface_count := 0

	# This GeomNode may be the parent of multiple geometries,
	# we'll take all of them.
	for geom_info in geoms:
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
		for attrib in geom_info.render_stateattribs:
			attrib.apply_to_surface(surface)
		for effect in effects.get_effects():
			effect.apply_to_surface(surface)

		# Pull vertex index information from each primitive.
		for primitive in geom.get_primitives():
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


class GeomInfo extends BAMStruct:
	var _geom: WeakRef
	var geom: PandaGeom:
		get:
			return get_object(_geom)

	var _render_state: WeakRef
	var render_state: PandaRenderState:
		get:
			return get_object(_render_state)

	func _init(datagram: PandaBAMDatagramReader) -> void:
		_geom = datagram.next_object_ref(PandaGeom)
		_render_state = datagram.next_object_ref(PandaRenderState)
