extends RefCounted
class_name EggEntry

var egg_parser: EggParser
var entry_dict: Dictionary
var entry_type: String
var entry_name: String
var raw_contents: Variant
var children: Array[EggEntry]
var data: Variant

func _init(parser: EggParser, entry: Dictionary) -> void:
	egg_parser = parser
	entry_type = entry['type']
	entry_name = entry['name']
	raw_contents = entry['contents']
	entry_dict = entry
	read_entry()
	for child in get_children():
		if child['type'] == 'Scalar':
			read_scalar(child['name'], child['contents'])
		else:
			read_child(child)
	
func _to_string() -> String:
	return "<%s %s %s>" % [get_script().resource_path.rsplit('/')[-1], entry_name, raw_contents]

func type() -> String:
	return entry_dict['type']
	
func name() -> String:
	return entry_dict['name']
	
func contents() -> String:
	return entry_dict['contents']
	
func get_children() -> Array:
	return entry_dict['children']

## Returns a [bool] constructed from an egg entry's contents.
static func as_bool(entry_dict: Dictionary) -> bool:
	var contents = entry_dict['contents']
	return contents == '1' or contents == 'true'

## Returns an [int] constructed from an egg entry's contents.
static func as_int(entry_dict: Dictionary) -> int:
	return entry_dict['contents'].to_int()
	
## Returns a [float] constructed from an egg entry's contents.
static func as_float(entry_dict: Dictionary) -> float:
	return entry_dict['contents'].to_float()

## Returns a [Vector2] constructed from an egg entry's contents.
static func as_vector2(entry_dict: Dictionary) -> Vector2:
	var floats = get_floats(entry_dict['contents'], 2)
	return Vector2(floats[0], floats[1])

## Returns a [Vector3] constructed from an egg entry's contents.
static func as_vector3(entry_dict: Dictionary) -> Vector3:
	var floats = get_floats(entry_dict['contents'], 3)
	return Vector3(floats[0], floats[1], floats[2])
	
## Returns a [Color] constructed from an egg entry's contents.
static func as_color(entry_dict: Dictionary) -> Color:
	var floats = get_floats(entry_dict['contents'], 4)
	return Color(floats[0], floats[1], floats[2], floats[3])

## Returns a [Projection] constructed from an egg entry's contents.
static func as_projection(entry_dict: Dictionary) -> Projection:
	var floats = get_floats(entry_dict['contents'], 16)
	return Projection(
		Vector4(floats[0], floats[1], floats[2], floats[3]),
		Vector4(floats[4], floats[5], floats[6], floats[7]),
		Vector4(floats[8], floats[9], floats[10], floats[11]),
		Vector4(floats[12], floats[13], floats[14], floats[15]),
	)

## Returns a [PackedFloat64Array] from the [param contents] of an egg entry.
static func get_floats(contents: String, expected_count: int = 0, allow_empty=true) -> PackedFloat64Array:
	var whitespace_trimmer = RegEx.new()
	whitespace_trimmer.compile('\\s+')
	var trimmed_contents = whitespace_trimmer.sub(
		contents.strip_edges(), ' ', true
	)
	var floats: PackedFloat64Array = trimmed_contents.split_floats(' ', allow_empty)
	assert(
		not expected_count or floats.size() == expected_count,
		"get_floats() was called expected %s values, but got %s" 
		% [expected_count, floats.size()]
	)
	return floats
	
## Called when an [EggEntry] is first initialized. This function can be overridden
## to populate the attributes of a subclass upon receiving the entry's dictionary.
func read_entry() -> void:
	return

## Called when a child entry for this [EggEntry] is read. This function can be
## overridden to store data or handle behavior of a parent given its children.
## [br][br]
## [b]NOTE:[/b] This method is not called for [b]Scalar[/b] child entries.
## [method EggEntry.read_scalar] will be called instead.
func read_child(child: Dictionary) -> void:
	return
	
## Called when a Scalar child entry for this [EggEntry] is read. This function
## can be overridden to modify the data or behavior of the entry.
func read_scalar(scalar: String, data: String) -> void:
	return
