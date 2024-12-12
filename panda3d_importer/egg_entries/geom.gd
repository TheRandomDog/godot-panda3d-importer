extends EggGroup
class_name EggGeomGroup
## A group entry describing a piece of geometry in Panda3D.

var polygons: Array[EggPolygon]
var collide: EggCollide

func read_child(child: Dictionary):
	super(child)
	match child['type']:
		'Polygon':
			polygons.append(EggPolygon.new(egg_parser, child))
		'Collide':
			collide = EggCollide.new(egg_parser, child)

func _make_collision_static_body(shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = shape.duplicate()
	body.add_child(collision)
	return body

func _make_collision_area(shape: Shape3D) -> Area3D:
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = shape.duplicate()
	area.add_child(collision)
	return area

func convert() -> Node3D:
	#var collision_node: Node3D
	var node: Node3D
	if collide:
		var shape: Shape3D
		var collision_mesh_array := get_collision_mesh_array()
		var collision_mesh := ArrayMesh.new()
		var collision_mesh_aabb := collision_mesh.get_aabb()
		collision_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,  # TODO
			collision_mesh_array,
			[], {},
			Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		)
		match collide.collide_type:
			EggCollide.CollideType.PLANE:
				shape = WorldBoundaryShape3D.new()
			EggCollide.CollideType.POLYGON, EggCollide.CollideType.POLYSET:
				shape = collision_mesh.create_convex_shape()
			EggCollide.CollideType.SPHERE:
				shape = SphereShape3D.new()
				var position := collision_mesh_aabb.get_center() 
				var furthest_vertex := collision_mesh_aabb.get_support(
					collision_mesh_aabb.get_longest_axis()
				)
				shape.radius = furthest_vertex - position
			EggCollide.CollideType.BOX:
				shape = BoxShape3D.new()
				shape.position = collision_mesh_aabb.position
				shape.size = collision_mesh_aabb.size
			EggCollide.CollideType.TUBE:
				shape = CapsuleShape3D.new()
				var axis := collision_mesh_aabb.get_longest_axis()
				var furthest_vertex_a := collision_mesh_aabb.get_support(axis)
				var furthest_vertex_b := collision_mesh_aabb.get_support(axis * -1)
				# TODO
		
		if collide.keep_visual_mesh:
			node = convert_model()
		if collide.uses_static_body:
			var body := _make_collision_static_body(shape)
			if node:
				node.add_child(body)
			else:
				node = body
		if collide.uses_area:
			var area := _make_collision_area(shape)
			if node:
				node.add_child(area)
			else:
				node = area
		if not node:
			return null
	
	else:
		node = convert_model()
	
	convert_node(node)
	return node

func get_collision_mesh_array() -> Array:
	if collide and collide.uses_one_polygon:
		return create_mesh_data([polygons[0]], true)[0]
	else:
		return create_mesh_data([], true)[0]

## Creates an [Array] that will be used as the base to create an [ArrayMesh].
##
## This array includes vertex data, normals, tangents, colors, UV coordinates,
## bones, and bone weights.
func create_mesh_data(polygon_array: Array[EggPolygon] = [], for_collision := false) -> Array:
	var mesh_array := [
		PackedVector3Array(),  # ARRAY_VERTEX  # TODO: and if it's points?
		PackedVector3Array(),  # ARRAY_NORMAL
		null,#PackedFloat32Array(),  # ARRAY_TANGENT  # TODO
		PackedColorArray() if not for_collision else null,    # ARRAY_COLOR
		PackedVector2Array() if not for_collision else null,  # ARRAY_TEX_UV
		null,                  # ARRAY_TEX_UV2
		null,                  # ARRAY_CUSTOM0
		null,                  # ARRAY_CUSTOM1
		null,                  # ARRAY_CUSTOM2
		null,                  # ARRAY_CUSTOM3
		PackedInt32Array() if not for_collision else null,    # ARRAY_BONES
		PackedFloat32Array() if not for_collision else null,  # ARRAY_WEIGHTS
		PackedInt32Array(),    # ARRAY_INDEX
	]
	var surfaces: Dictionary[int, Array]
	
	# Unlike BAM files, verticies that make up the same polygon can have
	# different combinations of vertex data. Since we're only temporarily
	# using an ArrayMesh to construct the mesh, we'll just take the easy route
	# and add default values for all vertex data properties for all polygons.
	
	# We keep an index of verticies used in the ArrayMesh
	# (not the same as the vertex indicies found in the Egg file.)
	#
	# Normally we wouldn't need to track indexes since we're just adding
	# each vertex one-by-one, but this avoids duplication data in the event
	# that an Egg file uses quad polygons (as Godot doesn't support that and
	# we just break it down into two triangles).
	var unique_array_vertex_id: int
	
	if not polygon_array:
		polygon_array = polygons
	
	var printed = []
	for polygon in polygon_array:
		var uv_transform: Transform2D
		var egg_texture := polygon.get_texture()
		if egg_texture != null: #has_texture:
			uv_transform = polygon.get_uv_transform()
		
		var all_verticies_have_color := true
		var id_start = unique_array_vertex_id
		for vertex in polygon.vertex_ref.verticies:
			if not vertex.color:
				all_verticies_have_color = false
			
			# Some of these vertex properties may not be defined in the egg file.
			# If they're not, they will simply be default values in the EggVertex,
			# which works out perfectly fine for passing to the ArrayMesh.
			mesh_array[Mesh.ARRAY_VERTEX].append(vertex.position * egg_parser.rotation_matrix)
			mesh_array[Mesh.ARRAY_NORMAL].append(vertex.normal)
			if for_collision:
				continue
			
			mesh_array[Mesh.ARRAY_COLOR].append(vertex.color)
			mesh_array[Mesh.ARRAY_TEX_UV].append(vertex.uv_coords)
			
			var joints: Array[EggJoint] = vertex.joint_influences.keys()
			for i in range(8):
				if i < joints.size():
					var joint := joints[i]
					mesh_array[Mesh.ARRAY_BONES].append(joint.bone_id)
					mesh_array[Mesh.ARRAY_WEIGHTS].append(vertex.joint_influences[joint])
				else:
					mesh_array[Mesh.ARRAY_BONES].append(0)
					mesh_array[Mesh.ARRAY_WEIGHTS].append(0)
					
			unique_array_vertex_id += 1
		var unique_array_vertex_ids_assigned := range(id_start, id_start + polygon.vertex_ref.verticies.size())
		
		if not for_collision:
			var surface := Surface.new()
			surface.add_albedo_color(polygon.color)
			if all_verticies_have_color:
				surface.add_vertex_coloring()
			if egg_texture:
				surface.add_texture(egg_texture.texture)
				if 'rgba' in egg_texture.format.to_lower():
					surface.add_alpha()

			var surface_id := surface.get_surface_id()
			if surface_id in surfaces:
				surfaces[surface_id].append_array(unique_array_vertex_ids_assigned)
			else:
				surfaces[surface_id] = unique_array_vertex_ids_assigned
		
		if polygon.vertex_ref.is_quad():
			# Godot does not natively support quads, so we'll have to
			# create triangles out of this polygon.
			mesh_array[Mesh.ARRAY_INDEX].append_array(
				PackedInt32Array([
					id_start, id_start + 1, id_start + 2,
					id_start, id_start + 2, id_start + 3
				])
			)
		else:
			mesh_array[Mesh.ARRAY_INDEX].append_array(
				PackedInt32Array(unique_array_vertex_ids_assigned)
			)
			
	return [mesh_array, surfaces]


## Converts the geom group data into a [MeshInstance3D] node.
func convert_model() -> MeshInstance3D:
	var arr_mesh = ArrayMesh.new()
	
	var mesh_data := create_mesh_data()
	var mesh_array: Array = mesh_data[0]
	var surfaces: Dictionary[int, Array] = mesh_data[1]

	var mesh := ArrayMesh.new()
	var mesh_surface_count := 0
	
	#assert(surfaces.size() == 1)
	for surface_id in surfaces.keys():
		var mesh_array_part := mesh_array.duplicate()
		var indicies := Array(mesh_array_part[Mesh.ARRAY_INDEX])
		var surface_indicies := surfaces[surface_id]
		mesh_array_part[Mesh.ARRAY_INDEX] = PackedInt32Array(
			indicies.filter(func(i): return i in surface_indicies)
		)
		
		var surface := Surface.from_surface_id(surfaces.keys()[0])
		arr_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,  # TODO
			mesh_array_part,
			[], {},
			Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		)
		arr_mesh.surface_set_material(mesh_surface_count, surface.finalize())
		mesh_surface_count += 1
		
	var m = MeshInstance3D.new()
	m.mesh = arr_mesh
	return m
