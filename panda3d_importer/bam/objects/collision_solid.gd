extends BamObject
class_name PandaCollisionSolid

enum Flags { 
	TANGIBLE = 1,
	EFFECTIVE_NORMAL = 2,
	VIZ_GEOM_STALE = 4,
	IGNORE_EFFECTIVE_NORMAL = 8,
	INTERNAL_BOUNDS_STALE = 16,
}
var flags: Flags
var effective_normal

func parse_object_data() -> void:
	return
	var flags := datagram.decode_u8()
	if flags & Flags.EFFECTIVE_NORMAL:
		effective_normal
		
	
