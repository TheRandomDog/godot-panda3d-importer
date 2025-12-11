extends BamObject
class_name PandaTexture
## A BAM Object containing information about a texture.
##
## This information can include just metadata about things like texture type,
## compression / quality levels, name, format, etc., but raw image data can
## also sometimes be embedded into these objects.
##
## When importing a BAM Model into Godot, PandaTexture objects are read to tie
## texture resource files to the model as a dependecy. If there are separate
## alpha files, they will be stitched back into one texture for convenience.

# TODO: Many texture properties here are not mapped to functionality

enum TextureType {
	TEXTURE_1D,
	TEXTURE_2D,
	TEXTURE_3D,
	TEXTURE_ARRAY_2D,
	CUBE_MAP,
	TEXTURE_BUFFER,
	CUBE_MAP_ARRAY,
	TEXTURE_ARRAY_1D,
}

enum CompressionMode {
	DEFAULT, OFF, ON,
	FXT1,
	DXT1, DXT2, DXT3, DXT4, DXT5,
	PVR1_2BPP, PVR1_4bPP,
	RGTC,
	ETC1, ETC2,
	EAC,
}

enum QualityLevel { DEFAULT, FASTEST, NORMAL, BEST }

enum Format {
	_PADDING,
	DEPTH_STENCIL, COLOR_INDEX,
	RED, GREEN, BLUE, ALPHA,
	RGB, RGB5, RGB8, RGB12, RGB332,
	RGBA, RGBM, RGBA4, RGBA5, RGBA8, RGBA12,
	LUMINANCE, LUMINANCE_ALPHA, LUMINANCE_ALPHAMASK,
	RGBA16, RGBA32,
	DEPTH_COMPONENT, DEPTH_COMPONENT16, DEPTH_COMPONENT24, DEPTH_COMPONENT32,
	R16, RG16, RGB16, SRGB, SRGB_ALPHA,
	SLUMINANCE, SLUMINANCE_ALPHA,
	R32I, R32, RG32, RGB32,
	R8I, RG8I, RGB8I, RGBA8I,
	R11_G11_B10, RGB9_E5, RGB10_A2,
	RG,
	R16I, RG16I, RGB16I, RGBA16I,
	RG32I, RGB32I, RGBA32I,
}

enum AutoTextureScale { NONE, DOWN, UP, PAD, UNSPECIFIED }

enum ComponentType {
	UNSIGNED_BYTE,
	UNSIGNED_SHORT,
	FLOAT,
	UNSIGNED_INT_24_8,
	INT,
	BYTE,
	SHORT,
	HALF_FLOAT,
	UNSIGNED_INT,
}


# Header
var name: String
var filename: String
var alpha_filename: String
var primary_file_num_channels: int
var alpha_file_channel: int
var has_raw_data: bool
var texture_type: TextureType
var has_read_mipmaps: bool  # 6.32+

# Body
var default_sampler: SamplerState
var compression: CompressionMode = CompressionMode.DEFAULT  # 6.1+
var quality_level: QualityLevel = QualityLevel.DEFAULT  # 6.16+
var format: Format
var num_components: int
var usage_hint: PandaGeom.UsageHint
var auto_texture_scale: AutoTextureScale = AutoTextureScale.UNSPECIFIED  # 6.28+
var orig_file_x_size: int  # 6.18+
var orig_file_y_size: int  # 6.18+
# Body - Simple Ram Image
var has_simple_ram_image: bool = false  # 6.18+
var simple_x_size: int
var simple_y_size: int
var simple_image_date_generated: int
var simple_raw_data: PackedByteArray
var clear_color: Color  # 6.45+

# Raw Data
var x_size: int
var y_size: int
var z_size: int
var pad_x_size: int = 0  # 6.30+
var pad_y_size: int = 0  # 6.30+
var pad_z_size: int = 0  # 6.30+
var num_views: int = 1  # 6.26+
var component_type: ComponentType
var component_width: int
var ram_image_compression: CompressionMode = CompressionMode.OFF  # 6.1+
var ram_images: Array[RamImage]  # 6.3+

func parse_object_data() -> void:
	parse_texture_header()
	parse_texture_body()
	if has_raw_data:
		parse_texture_rawdata()

func parse_texture_header() -> void:
	name = datagram.decode_string()
	filename = datagram.decode_string()
	bam_parser.import_dependency_manager.add_dependency(
		self, filename,
		PandaImportDependencyManager.DependencyType.TEXTURE,
	)
	alpha_filename = datagram.decode_string()
	if alpha_filename:
		bam_parser.import_dependency_manager.add_dependency(
			self, alpha_filename,
			PandaImportDependencyManager.DependencyType.ALPHA_TEXTURE,
		)

	primary_file_num_channels = datagram.decode_u8()
	alpha_file_channel = datagram.decode_u8()
	has_raw_data = datagram.decode_bool()
	texture_type = datagram.decode_u8() as TextureType
	if bam_parser.version < [6, 25] and texture_type == TextureType.TEXTURE_ARRAY_2D:
		# Between Panda3D releases 1.7.2 and 1.8.0 (bam versions 6.24 and 6.25),
   		# 2D texture arrays were added, shifting the enum for Cube Maps.
		texture_type = TextureType.CUBE_MAP
	if bam_parser.version >= [6, 32]:
		has_read_mipmaps = datagram.decode_bool()

func parse_texture_body() -> void:
	default_sampler = SamplerState.new(datagram)

	if bam_parser.version >= [6, 1]:
		compression = datagram.decode_u8() as CompressionMode
	if bam_parser.version >= [6, 16]:
		quality_level = datagram.decode_u8() as QualityLevel

	format = datagram.decode_u8() as Format
	num_components = datagram.decode_u8()

	if texture_type == TextureType.TEXTURE_BUFFER:
		usage_hint = datagram.decode_u8() as PandaGeom.UsageHint

	if bam_parser.version >= [6, 28]:
		auto_texture_scale = datagram.decode_u8() as AutoTextureScale

	if bam_parser.version >= [6, 18]:
		orig_file_x_size = datagram.decode_u32()
		orig_file_y_size = datagram.decode_u32()
		has_simple_ram_image = datagram.decode_bool()

	if has_simple_ram_image:
		simple_x_size = datagram.decode_u32()
		simple_y_size = datagram.decode_u32()
		simple_image_date_generated = datagram.decode_s32()
		var simple_raw_data_size := datagram.decode_u32()
		if simple_raw_data_size > datagram.datagram_size_remaining:
			bam_parser.parse_warning(
				'Simple RAM Image extends past end of datagram, '
				+ 'abandoning Texture parse'
			)
			return
		simple_raw_data = datagram.take_size(simple_raw_data_size)

	if bam_parser.version >= [6, 45]:
		var has_clear_color = datagram.decode_bool()
		if has_clear_color:
			clear_color = datagram.decode_color()

func parse_texture_rawdata() -> void:
	x_size = datagram.decode_u32()
	y_size = datagram.decode_u32()
	z_size = datagram.decode_u32()

	if bam_parser.version >= [6, 30]:
		pad_x_size = datagram.decode_u32()
		pad_y_size = datagram.decode_u32()
		pad_z_size = datagram.decode_u32()

	if bam_parser.version >= [6, 26]:
		num_views = datagram.decode_u32()

	component_type = datagram.decode_u8() as ComponentType
	component_width = datagram.decode_u8()
	ram_image_compression = datagram.decode_u8() as CompressionMode

	# TODO: Ram Image

## Returns a [PandaImageAndAlphaTexture] from the resource matching
## [member PandaTexture.filename] and [member PandaTexture.alpha_filename]
## (if set).
func load_texture() -> PandaImageAndAlphaTexture:
	var texture := PandaImageAndAlphaTexture.new()

	var texture_resource := bam_parser.get_dependency(
		filename,
		PandaImportDependencyManager.DependencyType.TEXTURE,
	)
	if texture_resource is Texture2D:
		texture.image = texture_resource.get_image()
	elif texture_resource is Image:
		texture.image = texture_resource

	var alpha_resource := bam_parser.get_dependency(
		alpha_filename,
		PandaImportDependencyManager.DependencyType.ALPHA_TEXTURE,
	)
	if alpha_resource is Texture2D:
		texture.alpha_image = alpha_resource.get_image()
	elif alpha_resource is Image:
		texture.alpha_image = alpha_resource

	texture.alpha_channel = alpha_file_channel
	return texture


class RamImage:
	var image: PackedByteArray
	var page_size: int
