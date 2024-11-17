extends Resource
class_name Multifile

const MAGIC_HEADER = [0x70, 0x6D, 0x66, 0x00, 0x0A, 0x0D]
const SUBFILE_INDEXES_START = 18
var file_size_limit: int = 4000000000

@export var major_version: int = 1
@export var minor_version: int = 1
@export var scale_factor: int = 1:
	set(scale):
		file_size_limit = 4000000000 * scale
		scale_factor = scale
@export var timestamp: int
@export var subfiles: Array[MultifileSubfile]

func _get_real_address(scaled_address: int) -> int:
	return scaled_address * scale_factor
	
func _get_scaled_address(real_address: int) -> int:
	return (real_address + scale_factor - 1) / scale_factor

func _get_next_address(real_address: int) -> int:
	return _get_real_address(_get_scaled_address(real_address))
