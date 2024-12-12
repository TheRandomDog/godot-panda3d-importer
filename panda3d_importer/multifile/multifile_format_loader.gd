@tool
extends ResourceFormatLoader
class_name ResourceMultifileFormatLoader
## Handles reading Panda3D's Multifile (.mf) file type into a [Multifile] resource.

func _get_recognized_extensions() -> PackedStringArray:
	return ['mf']
	
func _get_resource_script_class(path: String) -> String:
	return 'multifile.gd'
	
func _get_resource_type(path: String) -> String:
	return 'Resource'

func _handles_type(type: StringName) -> bool:
	return type == 'Resource'

func _load(path: String, original_path: String, sbthr: bool, cache_mode: int) -> Variant:
	var file := FileAccess.get_file_as_bytes(path)
	if not file:
		return FileAccess.get_open_error()
	
	# Validate the magic header
	if file.slice(0, 6) != PackedByteArray(Multifile.MAGIC_HEADER):
		return FAILED
	
	# Get multifile header information
	var multifile := Multifile.new()
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
		subfile.data = file.slice(data_address, data_address + data_length)
		multifile.subfiles.append(subfile)
		
		# Get the start of the next subfile.
		subfile_start = next_subfile_address
		next_subfile_address = multifile._get_real_address(file.decode_u32(subfile_start))
	
	return multifile
