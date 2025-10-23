@tool
extends EditorPlugin
class_name Panda3DImporterPlugin

## Returns a suitable Basis object given a Panda3D HPR rotation value.
static func get_basis_from_hpr(hpr: Vector3, rotated := false) -> Basis:
	# For euler angles,
	#   Panda3D supplies:  Vector3(H, P, R)
	#   Godot expects:     Vector3(P, H, R)
	# Then, Panda3D applies rotation in roll-pitch-yaw order.
	hpr = Vector3(deg_to_rad(hpr.y), deg_to_rad(hpr.x), -deg_to_rad(hpr.z))
	var basis = Basis.from_euler(hpr, EULER_ORDER_YXZ)
	if rotated:
		return basis.rotated(Vector3.LEFT, -PI / 2)
	else:
		return basis


var sgi_importer = preload("./sgi/importer.gd").new()

var anim_importer = preload("./bam/importer_anim.gd").new()
var model_importer = preload("./bam/importer_model.gd").new()
var font_importer = preload("./bam/importer_font.gd").new()
var flat_importer = preload("./bam/importer_flat.gd").new()

var egg_model_importer = preload("./egg/importer_model.gd").new()
var egg_anim_importer = preload("./egg/importer_anim.gd").new()
var egg_font_importer = preload("./egg/importer_font.gd").new()

func _enter_tree():
	add_import_plugin(sgi_importer)
	add_import_plugin(anim_importer)
	add_import_plugin(model_importer)
	add_import_plugin(font_importer)
	add_import_plugin(flat_importer)
	add_import_plugin(egg_anim_importer)
	add_import_plugin(egg_model_importer)
	add_import_plugin(egg_font_importer)

func _exit_tree():
	remove_import_plugin(egg_font_importer)
	remove_import_plugin(egg_model_importer)
	remove_import_plugin(egg_anim_importer)
	remove_import_plugin(flat_importer)
	remove_import_plugin(font_importer)
	remove_import_plugin(model_importer)
	remove_import_plugin(anim_importer)
	remove_import_plugin(sgi_importer)
