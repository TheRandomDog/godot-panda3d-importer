@tool
extends RefCounted
class_name SGIParser
## A class that can read and parse a Silicon Graphics Image.

enum Compression { UNCOMPRESSED, RLE_COMPRESSED }
enum BytesPerPixel { UNDEFINED, BIT_8, BIT_16 }
enum Dimension {
	UNDEFINED,
	ONE_CHANNEL_ONE_SCANLINE,
	ONE_CHANNEL_MULTI_SCANLINE,
	MULTI_CHANNEL_MULTI_SCANLINE,
}
enum Channels {
	UNDEFINED,
	GREYSCALE,
	GREYSCALE_ALPHA,
	RGB,
	RGBA,
}
enum ColorMap { NORMAL, DITHERED, SCREEN, COLOR_MAP }

const CHANNELS_TO_FORMAT = {
	Channels.GREYSCALE: Image.Format.FORMAT_L8,
	Channels.GREYSCALE_ALPHA: Image.Format.FORMAT_LA8,
	Channels.RGB: Image.Format.FORMAT_RGB8,
	Channels.RGBA: Image.Format.FORMAT_RGBA8,
}

var image: Image

func load(path) -> Error:
	return parse(FileAccess.get_file_as_bytes(path))

func parse(data_array: PackedByteArray) -> Error:
	var stream := StreamPeerBuffer.new()
	stream.big_endian = true
	stream.data_array = data_array
	if stream.data_array.is_empty():
		return ERR_INVALID_DATA
		
	var magic_header_read := stream.get_data(2)
	if magic_header_read[0] != OK:
		return magic_header_read[0]
	elif magic_header_read[1] != PackedByteArray([0x01, 0xDA]):
		return ERR_FILE_UNRECOGNIZED
	
	var compression := stream.get_u8() as Compression
	var bytes_per_pixel := stream.get_u8() as BytesPerPixel
	var dimensions := stream.get_u16() as Dimension
	
	var size_x := stream.get_u16()
	var size_y := stream.get_u16()
	#image.resize(size_x, size_y)
	
	var channel_count := stream.get_u16() as Channels
	var minimum_pixel_value := stream.get_u32()
	var maximum_pixel_value := stream.get_u32()
	stream.get_u32()
	
	var image_name = stream.get_string(80)
	
	var color_map := stream.get_u32() as ColorMap
	assert(color_map == ColorMap.NORMAL, "Tried to import a RGB file with an obsolete color map")
	var format: int = CHANNELS_TO_FORMAT[channel_count]
	
	var data: PackedByteArray
	if compression == Compression.RLE_COMPRESSED:
		data = _read_with_compression(stream, bytes_per_pixel, size_x, size_y, channel_count)
	else:
		data = _read_no_compression(stream, bytes_per_pixel, size_x, size_y, channel_count)
	image = Image.create_from_data(size_x, size_y, false, format, data)
	return OK

func _read_no_compression(stream: StreamPeerBuffer, bytes_per_pixel: int, size_x: int, size_y: int, channel_count: int) -> PackedByteArray:
	stream.seek(512)
	var data: PackedByteArray
	data.resize(size_x * size_y * channel_count)
	
	var get_pixel: Callable = stream.get_u8 if bytes_per_pixel == 1 else stream.get_u16
	var set_pixel: Callable = data.encode_u8 if bytes_per_pixel == 1 else data.encode_u16
	var pixel_value: int
	var position: int
	var row: int
	assert(bytes_per_pixel <= 2)
	for channel in range(channel_count):
		for scanline in range(size_y):
			row = size_y - scanline - 1
			for pixel in range(0, size_x, bytes_per_pixel):
				pixel_value = get_pixel.call()
				if bytes_per_pixel == 2:
					pixel_value = pixel_value >> 8
				position = (
					(size_x * channel_count * row) +
					(pixel * channel_count) + channel
				)
				set_pixel.call(position, pixel_value)
	return data

func _read_with_compression(stream: StreamPeerBuffer, bytes_per_pixel: int, size_x: int, size_y: int, channel_count: int) -> PackedByteArray:
	stream.seek(512)
	var data: PackedByteArray
	data.resize(size_x * size_y * channel_count)
	
	var scanlines := size_y * channel_count
	var cached_data: Dictionary
	
	var start_offsets := PackedInt32Array()
	start_offsets.resize(scanlines)
	for i in range(scanlines):
		start_offsets[i] = stream.get_u32()
	
	var length_offsets := PackedInt32Array()
	length_offsets.resize(scanlines)
	for i in range(scanlines):
		length_offsets[i] = stream.get_u32()
	
	var get_data: Callable = stream.get_u8 if bytes_per_pixel == 1 else stream.get_u16
	var set_data: Callable = data.encode_u8 if bytes_per_pixel == 1 else data.encode_u16
	var offset_index: int
	var offset_start: int
	var offset_length: int
	var instructions: int
	var count: int
	var repeat: bool
	var pixel_value: int
	var position: int
	var row: int
	assert(bytes_per_pixel <= 2)
	for channel in range(channel_count):
		for scanline in range(size_y):
			row = size_y - scanline - 1
			offset_index = (channel * size_y) + scanline
			offset_start = start_offsets[offset_index]
			offset_length = length_offsets[offset_index]

			# Read from offset
			stream.seek(offset_start)
			var pixel_index := 0
			
			while true:
				instructions = get_data.call()
				count = instructions & 0x7F
				repeat = not (instructions & 0x80)
				if not instructions:
					# End of scanline
					assert(stream.get_position() == offset_start + offset_length)
					break
				else:
					# Start with the next pixel value.
					pixel_value = get_data.call()
					if bytes_per_pixel == 2:
						pixel_value = pixel_value >> 8
					for pixel in range(count):
						position = (
							(size_x * channel_count * row) +
							(pixel_index * channel_count) + channel
						)
						set_data.call(position, pixel_value)
						# Grab the next pixel value, if needed.
						if not repeat and pixel < count - 1:
							pixel_value = get_data.call()
							if bytes_per_pixel == 2:
								pixel_value = pixel_value >> 8
						pixel_index += 1
						
	return data
