# Panda3D Native File Types Importer for Godot 4.4+
This is an add-on for Godot 4.4+ that allows you to import or read native Panda3D file types into Godot. This includes:

 - **Import:** .egg and .egg.pz (Egg) files
	 - 3D Models as **PackedScene** resources with the Egg Model importer.
	 - Animations as **Animation** resources with the Egg Animation importer.
 - **Import:** .bam (BAM) files
	 - 3D Models as **PackedScene** resources with the BAM Model importer.
	 - Animations as **Animation** resources with the BAM Animation importer.
 - **Import:** .sgi / .rgb (SGI) files
	 - SGI Image Format as **Image** resources.
 - **Resource Loader:** .mf (Multifile) files


### Warning: Experimental
At the moment, this add-on is mostly experimental and there are many features that are untested or unsupported. There are several debug outputs and editor warnings, and use of in-development features only present in Godot 4.4 dev builds. There are multiple discrepancies between what's supported between Egg files and BAM files.

In the future, these issues should become more resolved and the add-on will likely be backported to support older Godot 4 versions.

## Installing
This add-on is currently only available through GitHub while experimental.
1. Clone or download this repository from GitHub.
2. Copy the `addons/panda3d_importer` folder into your project's add-ons folder.
3. Enable the Panda3D Importer add-on in the `Project -> Project Settings -> Plugins` menu.

## Using the add-on
When you have recognized file types in your FileSystem, Godot will import them like any other resource and they will become available in the editor to drag-and-drop into your scenes / inspector.

You may also use it programmatically via GDScript. `EggParser` and `BamParser` are two classes that can be instantiated to allow for loading / parsing their corresponding file types. As an example:
```swift
var egg_parser := EggParser.new()
var result: Error = egg_parser.load("res://smiley.egg.pz")
if result == OK:
	var smiley: VisualInstance3D = egg_parser.make_model()

var bam_parser := BamParser.new()
var result: Error = bam_parser.parse(external_byte_array)
if result == OK:
	var streamed_animation: Animation = bam_parser.make_animation()
bam_parser.cleanup()

var sgi_parse := SGIParser.new()
var result: Error = sgi_parser.load("res://texture.rgb")
if result == OK:
  var texture := ImageTexture.create_from_image(result.image)
```
Multifiles can also be read and written to as resources, but aren't imported. Opening them via the FileSystem will show Multifile and Subfile data in the Inspector. You can also interact with them through GDScript:
```swift
func _subfile_not_obsolete(subfile: MultifileSubfile):
	var path: String = subfile.name
	return not path.get_file().begins_with("obsolete_")

var my_files: Multifile = load("res://myfiles.mf")
my_files.subfiles = my_files.subfiles.filter(_subfile_not_obsolete)
ResourceSaver("res://myfiles.mf", my_files)
```


## Supported Features
Panda3D is a mature realtime 3D engine that's been active for twice as long as Godot, and is aimed towards all sorts of practical applications alongside games. As such, there are many features Panda3D supports that are difficult to match or emulate using Godot, and such features (if present in your .egg or .bam files) may have to be manually adjusted to work within Godot. In the end, this is merely a convenience tool to remove extra conversion steps using intermediary formats.

The following is a list of features and their support level, with the following legend:
- 🟢Fully supported
- 🟡Partially supported
- 🔵Partially supported through emulated behavior
- 🔴Not yet supported
- ⚫No planned support

### Egg Files
|Feature|Supported|
|-|-|
|Reading|🟢 Yes|
|Writing|⚫ No. This parser is only used to convert Egg files into a native Godot resource.
|.egg.pz|🟢 Yes
|Basic Geometry|🟡 Only \<Polygon\> entries are currently supported. Vertex coordinates only take three dimensions.
|Parametric (NURBS)|🔴 No
|Normals|🟡 Yes, but does not follow Egg file spec *(will take vertex normal entry regardless of if all verticies have normal entries or not.)*
|Coloring|🟢 Supports polygon and vertex coloring.
|UV Coordinates|🟡 Does not support 3D textures, multitextures, or tangent and binormal values. Currently, only the last UV child entry for a parent is respected.
|Textures|🟡 Can read and import JPEG, PNG, and SGI (RGB) files as texture dependencies for a .egg resource. If a texture has a separate alpha file, the resulting import will be a pre-baked combination of the two files.<br><br>Only 2D RGB and RGBA texture formats are supported. Texture filters, wrap modes, mipmaps, and border colors are **not** supported.
|Multitextures / TextureStages|🔴 No
|Materials|🔴 No
|Morphs|🔴 No
|Coordinate System|🟢 Automatically converts to Godot's Y-Up-Right.
|Cull Bins|🔴 No
|Backfaces|🔴 No
|Billboards|🔴 No
|Lighting|🟡 Converts Panda3D's `PointLight` to an **OmniLight3D**. (By default, converted geometry has no shading set.)
|Level of Detail (LOD)|🔴 No
|Characters|🟡 Yes, will convert joint data to a **Skeleton3D**. Default poses and initial transforms values for joints currently both set bone rest poses.
|Animation|🟡 Yes, will convert animated joint transform data to **Animation** resources. Only one animation per file is supported.<br><br>Shear animations are **not** supported.<br>\<VertexAnim\> entries are **not** supported.<br><br>Detecting Egg file contents is not automatic: you must choose the **Egg Animation** importer or call `EggParser.make_animation()`.
|Fonts|🟢 Egg files containing fonts pre-generated with Panda3D's `egg-mkfont` tool can be imported as **FontFile** resources.<br><br>Detecting Egg file contents is not automatic: you must choose the **Egg Font** importer or call `EggParser.make_font()`.
|Font Features|🟡 Fonts can be imported from Egg files with "small caps", a Panda3D feature that fills in lowercase letters as smaller-scaled uppercase letters, ignoring a font's designated (or non-existent) lowercase entries.<br><br>Fonts imported from Egg files **do not** support "cheesy" accent marks, a Panda3D feature that synthesizes accented characters by combining similar-looking glyphs from a font.
|Collisions|🟡 A **StaticBody3D** (or **Area3D** if the `intangible` flag is set) and corresponding **CollisionShape3D** child is created.<br><br>If the `keep` flag is set, these nodes are parented under a mesh instance.<br>If the `event` flag is set, a child Area3D will be created regardless.<br><br>Only supports polygon, polyset, sphere, and box collision types.<br>`descend` and `level` flags are not yet supported.<br>\<ObjectType\> entries are **not** supported.

### Bam Files
|Feature|Supported|
|-|-|
|Reading|🟡 Currently does not support `REMOVE` and `FILE_DATA` object codes, and Object ID pointers above the uint16 max.
|Writing|⚫ No. This parser is only used to convert BAM files into a native Godot resource.
|.bam.pz|🟢 Yes, but due to a Godot limitation, this add-on will attempt to read any file with the ".pz" extension as an Egg file first. You'll have to manually switch the importer for a .bam.pz resource.
|Basic Geometry|🟡 Only triangles, tristrips, and points are currently supported.
|Parametric (NURBS)|🔴 No
|Normals|🟢 Yes
|Coloring|🟢 Supports polygon and vertex coloring.
|UV Coordinates|🟡 Does not support 3D textures or multitextures. **Does** support binormal and tangents.
|Textures|🟡 Can read and import JPEG, PNG, and SGI (RGB) files as texture dependencies for a .bam resource. If a texture has a separate alpha file, the resulting import will be a pre-baked combination of the two files.<br><br>Only 2D RGB and RGBA texture formats are supported. Texture filters, wrap modes, mipmaps, and border colors are **not** supported.
|Multitextures / TextureStages|🔴 No
|Materials|🔴 No
|Morphs|🔴 No
|Coordinate System|🟢 Automatically converts to Godot's Y-Up-Right.
|Cull Bins|🔴 No
|Backfaces|🔴 No
|Billboards|🟡 If a PandaNode has a Billboard RenderEffect, the corresponding Godot node will have its `BaseMaterial3D.billboard_mode` set to `BaseMaterial3D.BILLBOARD_FIXED_Y`. The resulting behavior may not be 1:1.
|Lighting|🔴 No (By default, converted geometry has no shading set.)
|Level of Detail (LOD)|🔴 No
|Characters|🟡 Yes, will convert joint data to a **Skeleton3D**. Initial transform is used for bone rest poses while default values of MovingParts are ignored.
|Animation|🟡 Yes, will convert animated joint transform data to an **Animation** resource. Only one animation per file is supported.<br><br>Only animations with an underlying matrix transformation table using new-style HPR values are currently supported.<br>Shear animations are **not** supported.<br><br>Detecting BAM file contents is not automatic: you must choose the **BAM Animation** importer or call `BamParser.make_animation()`.
|Fonts|🟢 BAM files containing fonts pre-generated with Panda3D's `egg-mkfont` tool can be imported as **FontFile** resources.<br><br>Detecting BAM file contents is not automatic: you must choose the **BAM Font** importer or call `BamParser.make_font()`.
|Font Features|🟡 Fonts can be imported from BAM files with "small caps", a Panda3D feature that fills in lowercase letters as smaller-scaled uppercase letters, ignoring a font's designated (or non-existent) lowercase entries.<br><br>Fonts imported from BAM files **do not** support "cheesy" accent marks, a Panda3D feature that synthesizes accented characters by combining similar-looking glyphs from a font.
|Collisions|🔴 No

### SGI (RGB) Images
|Feature|Supported|
|-|-|
|Reading|🟡 Yes.Certain information like dimension count, min/max pixel value, and the color map are ignored.<br><br>Only can read images with 1-4 channels (`ZSIZE`), which generates: greyscale images, greyscale w/ alpha, RGB images, and RGBA images.
|Writing|⚫ No. This parser is only used to convert SGI images into a native Godot **Image** or **ImageTexture** resource.
|RLE Compression|🟢 Yes

### Multifiles
|Feature|Supported|
|-|-|
|Reading|🟢 Yes
|Writing|🟢 Yes, but the writer does not act in a smart way, and will rewrite the entire file from scratch on each save.
|Subfile Compression|🔴 No. Subfiles with the compress flag set will not have their data uncompressed on load or compressed on save.
|Subfile Encryption|🔴 No. Subfiles with the encrypted flag set will not have their data unencrypted on load or encrypted on save. 
|Multifile Signatures|🔴 Signature signing and verification is not supported.
|Multifile Scale Factor|🟡 Yes, but has to be manually changed when needed. Will return `ERR_FILE_CANT_WRITE` if you try to save a Multifile resource that's above the file size limit for its current scale factor.

## Help
If you have an issue, questions, or bug report regarding this add-on, please open an issue on the GitHub repository. Some documentation exists in-engine by using the "Search Help" (F1) and searching for a class name under the Script tab.
