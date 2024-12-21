@tool
extends EditorPlugin

const SGIImporterPlugin = preload("./sgi_importer.gd")
const TextureImporterPlugin = preload("./texture_importer.gd")

const ModelImporterPlugin = preload("./bam_model_importer.gd")
const AnimImporterPlugin = preload("./bam_anim_importer.gd")
const FontImporterPlugin = preload("./bam_font_importer.gd")

const EggModelImporterPlugin = preload("./egg_model_importer.gd")
const EggAnimImporterPlugin = preload("./egg_anim_importer.gd")
const EggFontImporterPlugin = preload("./egg_font_importer.gd")

var sgi_importer = SGIImporterPlugin.new()
var texture_importer = TextureImporterPlugin.new()

var anim_importer = AnimImporterPlugin.new()
var model_importer = ModelImporterPlugin.new()
var font_importer = FontImporterPlugin.new()

var egg_model_importer = EggModelImporterPlugin.new()
var egg_anim_importer = EggAnimImporterPlugin.new()
var egg_font_importer = EggFontImporterPlugin.new()

func _enter_tree():
	add_import_plugin(sgi_importer)
	add_import_plugin(texture_importer)
	add_import_plugin(anim_importer)
	add_import_plugin(model_importer)
	add_import_plugin(font_importer)
	add_import_plugin(egg_anim_importer)
	add_import_plugin(egg_model_importer)
	add_import_plugin(egg_font_importer)

func _exit_tree():
	remove_import_plugin(egg_font_importer)
	remove_import_plugin(egg_model_importer)
	remove_import_plugin(egg_anim_importer)
	remove_import_plugin(font_importer)
	remove_import_plugin(model_importer)
	remove_import_plugin(anim_importer)
	remove_import_plugin(texture_importer)
	remove_import_plugin(sgi_importer)
