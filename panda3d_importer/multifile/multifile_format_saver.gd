@tool
extends ResourceFormatSaver
class_name ResourceMultifileFormatSaver
## Handles writing a [Multifile] resource into Panda3D's Multifile (.mf) file type.

func _recognize(resource: Resource) -> bool:
	return resource is Multifile

func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	return ['mf']
	
func _save(resource: Resource, path: String, flags: ResourceSaver.SaverFlags) -> Error:
	# This is not aimed to be a suitable alternative or replacement to packing
	# multifiles with Panda3D's SDK, obviously. We won't do anything efficient,
	# just create the Multifile from scratch.
	var old_file := FileAccess.get_file_as_bytes(path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	
	var multifile := resource as Multifile
	# Write the magic header
	file.store_buffer(Multifile.MAGIC_HEADER)
	
	# Write out our multifile headers
	# FileAccess does not have a store method that directly writes a signed
	# integer, so we'll just use a PackedByteArray to write the version number.
	var version := PackedByteArray()
	version.resize(4)
	version.encode_s16(0, multifile.major_version)
	version.encode_s16(2, multifile.minor_version)
	file.store_buffer(version)
	
	file.store_32(multifile.scale_factor)
	file.store_32(Time.get_unix_time_from_system())

	# Begin getting the subfile index entry data we'll write later on.
	# We only want to gather it here so we can fill in the index/data addresses
	# later, once we have a better idea of the file structure/size.
	var subfile_index_entries: Array[PackedByteArray]
	var next_index := Multifile.SUBFILE_INDEXES_START
	for subfile in multifile.subfiles:
		# Get the buffer containing our entry.
		var entry := _get_subfile_index_entry(subfile)
		next_index += entry.size()
		# Add any optional padding to accomodate the scale factor.
		var padding := _get_scale_factor_padding(multifile, next_index)
		next_index += padding.size()
		# Modify the index entry buffer to point to where the next entry will be.
		entry.encode_u32(0, multifile._get_scaled_address(next_index))
		subfile_index_entries.append(entry)
		subfile_index_entries.append(padding)
	
	# Create a buffer that will mark the end of our subfile index entries.
	# This is just a uint32 value of 0, alongside scale factor padding.
	var index_data_split: PackedByteArray
	index_data_split.resize(4)
	var ids_padding := _get_scale_factor_padding(multifile, next_index + 4)
	index_data_split.append_array(ids_padding)
	next_index += index_data_split.size()
	
	# Begin getting the subfile data entries we'll write later on.
	var subfile_data_entries: Array[PackedByteArray]
	for i in range(multifile.subfiles.size()):
		# Grab our subfile and index entry (i*2 because odd-numbers are padding)
		var subfile := multifile.subfiles[i]
		var index_entry := subfile_index_entries[i*2]
		# Modify the index entry buffer to point to where the subfile data will be.
		index_entry.encode_u32(4, multifile._get_scaled_address(next_index))
		next_index += subfile.data.size()
		# Add any optional padding to accomodate the scale factor.
		var padding := _get_scale_factor_padding(multifile, next_index)
		next_index += padding.size()
		subfile_data_entries.append(subfile.data)
		subfile_data_entries.append(padding)
	
	# Now that we've correctly filled in all addresses, we can write to the file.
	for index_entry in subfile_index_entries:
		file.store_buffer(index_entry)
	file.store_buffer(index_data_split)
	for data_entry in subfile_data_entries:
		file.store_buffer(data_entry)
	
	if file.get_length() > multifile.file_size_limit:
		push_error('Multifile too big -- please increase the scale factor')
		file.resize(0)
		if old_file:
			file.store_buffer(old_file)
		else:
			DirAccess.remove_absolute(path)
		return ERR_FILE_CANT_WRITE
		
	return OK

## Returns a [PackedByteArray] containing a subfile index entry.
func _get_subfile_index_entry(subfile: MultifileSubfile) -> PackedByteArray:
	var entry := PackedByteArray()
	entry.resize(20 + (4 if subfile.is_compressed() else 0))
	
	entry.encode_u32(0, 0)  # Next Subfile Address (will be filled in later)
	entry.encode_u32(4, 0)  # Data Address (will be filled in later)
	entry.encode_u32(8, subfile.data.size())
	entry.encode_u16(12, subfile.flags)
	var offset := 0
	if subfile.is_compressed():
		# If our subfile is compressed or encrypted, this value will be the
		# original file length (when uncompressed / unencrypted).
		entry.encode_u32(14, subfile.file_size)
	else:
		# Otherwise, our original file length is the data length.
		# We'll offset the start of our subfile index since we didn't
		# write the optional additional value above.
		offset = -4
		
	entry.encode_u32(offset+18, subfile.timestamp)
	entry.encode_u16(offset+22, subfile.name.length())
	
	# Panda3D inverts the bits in the name, so we'll restore that real quick.
	var subfile_name := Array(subfile.name.to_ascii_buffer())
	var obfuscated_name := PackedByteArray(subfile_name.map(func(b: int): return 255 - b))
	entry.append_array(obfuscated_name)
	
	return entry

## Returns a [PackedByteArray] resized to the padding needed to reach a valid
## scaled address.
func _get_scale_factor_padding(multifile: Multifile, orig_index: int) -> PackedByteArray:
	var next_index := multifile._get_next_address(orig_index)
	var padding := PackedByteArray()
	padding.resize(next_index - orig_index)
	return padding
