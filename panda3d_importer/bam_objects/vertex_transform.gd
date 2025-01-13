extends BamObject
class_name PandaVertexTransform
## The base BAM Object that is used for calculating dynamic verticies,
## such as those for animations.
##
## Vertex transforms are typically blended in a [PandaTransformBlendTable].
## At the moment, any transform blends are handled as [Skeleton3D]s, so this
## class is only used to hold a Bone ID.

var static_bone_id: int  # (currently) set in character.gd

func parse_object_data() -> void:
	pass

## Returns the static [Transform3D] value for this [PandaVertexTransform].
## [br][br]
## If called on an inheriting object that is considered to be dynamic, like 
## [PandaJointVertexTransform], [member Transform3D.IDENTITY] will be returned.
func get_static_transform() -> Transform3D:
	assert(false, 'Base PandaVertexTransform.get_static_transform() called')
	return Transform3D()
