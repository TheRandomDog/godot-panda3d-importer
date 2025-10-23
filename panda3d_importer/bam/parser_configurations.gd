extends Object
class_name BAMParserConfigs

enum BAMExcessTransformBlendBehavior { ERROR, WARN_AND_DROP, DROP }

const GLOBAL := 'global'

static func get_default() -> Dictionary:
	return {
		GLOBAL: {
			'magic_header': PackedByteArray([0x70, 0x62, 0x6A, 0x00, 0x0A, 0x0D]),
			'rotation_matrix': Transform3D(
				Basis().rotated(Vector3(-1, 0, 0), -PI / 2),
				Vector3()
			),
			'pixel_size': 0.01,
		},
		PandaAnimBundleNode: {
			'loop_mode': Animation.LoopMode.LOOP_NONE,
		},
		PandaTransformBlendTable: {
			'excess_transform_blend_behavior': BAMExcessTransformBlendBehavior.ERROR,
		},
	}
