extends PandaVertexTransform
class_name PandaJointVertexTransform

var _joint: WeakRef
var joint: PandaCharacterJoint:
	get:
		return get_object(_joint)

func parse_object_data() -> void:
	super()
	_joint = datagram.next_object_ref(PandaCharacterJoint)
