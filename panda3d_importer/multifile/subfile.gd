extends Resource
class_name MultifileSubfile

const MAX_SUBFILE_SIZE = 4000000000

enum SubfileFlags {
	DELETED = 1,
	INDEX_INVALID = 2,
	DATA_INVALID = 4,
	COMPRESSED = 8,
	ENCRYPTED = 16,
	SIGNATURE = 32,
	TEXT = 64,
}

@export_flags("Deleted:1", "Invalid Index:2", "Invalid Data:4", 'Compressed:8', 'Encrypted:16', 'Signature:32', 'Text:64') var flags: int
@export var file_size: int
@export var timestamp: int
@export var name: String
@export var data: PackedByteArray
var data_address_start: int
var data_address_end: int
	
#class EncryptedSubfile extends Subfile:
@export_group("Encryption", "encryption_")
@export var encryption_algorithm_nid: int
@export var encryption_key_length: int
@export var encryption_key_iteration_count: int

func is_compressed():
	return (MultifileSubfile.SubfileFlags.COMPRESSED & flags or
		MultifileSubfile.SubfileFlags.ENCRYPTED & flags)
