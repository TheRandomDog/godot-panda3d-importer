class_name MultifileReader

const HEADER_OFFSET := 18
var magic_header := PackedByteArray([0x70, 0x6D, 0x66, 0x00, 0x0A, 0x0D])

var read_contents: PackedByteArray
var read_byte_offset := 0
var datagram_size_remaining := 0
var error := OK
var store_subfile_data := true
var multifile: Multifile

var chunk_offset := HEADER_OFFSET
var next_subfile_address: int

var version: Array[int]
var scale_factor: int
var timestamp: int

func read_from_bytes(byte_array: PackedByteArray, name: String) -> Error:
	var file := byte_array
	
	# Validate the magic header
	if file.slice(0, 6) != PackedByteArray(Multifile.MAGIC_HEADER):
		return FAILED
	
	# Get multifile header information
	multifile = Multifile.new()
	multifile.name = name
	multifile.major_version = file.decode_s16(6)
	multifile.minor_version = file.decode_s16(8)
	multifile.scale_factor = file.decode_u32(10)
	multifile.timestamp = file.decode_u32(14)
	
	# Start reading subfile index entries
	var subfile_start := 18
	var next_subfile_address := multifile._get_real_address(file.decode_u32(subfile_start))
	while next_subfile_address != 0:
		var subfile := MultifileSubfile.new()
		var data_address := multifile._get_real_address(file.decode_u32(subfile_start + 4))
		var data_length := file.decode_u32(subfile_start + 8)
		
		subfile.flags = file.decode_u16(subfile_start + 12)
		if (MultifileSubfile.SubfileFlags.COMPRESSED & subfile.flags or
			MultifileSubfile.SubfileFlags.ENCRYPTED & subfile.flags):
			# If our subfile is compressed or encrypted, this value will be the
			# original file length (when uncompressed / unencrypted).
			subfile.file_size = file.decode_u32(subfile_start + 14)
		else:
			# Otherwise, our original file length is the data length.
			subfile.file_size = data_length
			# We'll also offset the start of our subfile index since we didn't
			# read the optional additional value above.
			subfile_start -= 4
		
		subfile.timestamp = file.decode_u32(subfile_start + 18)
		
		var name_length := file.decode_u16(subfile_start + 22)
		# Panda3D inverts the bits in the name, so we'll restore that real quick.
		var obfuscated_name = Array(file.slice(subfile_start + 24, subfile_start + 24 + name_length))
		subfile.name = PackedByteArray(obfuscated_name.map(func(b: int): return 255 - b)).get_string_from_ascii()
		
		# Finally, load in the subfile data directly from the file address.
		if store_subfile_data:
			subfile.data = file.slice(data_address, data_address + data_length)
		subfile.data_address_start = data_address
		subfile.data_address_end = data_address + data_length
		multifile.subfiles.append(subfile)
		
		# Get the start of the next subfile.
		subfile_start = next_subfile_address
		next_subfile_address = multifile._get_real_address(file.decode_u32(subfile_start))
	
	return error
