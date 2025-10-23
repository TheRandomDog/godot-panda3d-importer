@tool
class_name PandaImportDependencyManager
extends RefCounted

enum DependencyType {
	TEXTURE,
	ALPHA_TEXTURE,
}

var _source_file_path: String:
	set(new):
		_source_file_path = _source_file_path.trim_prefix('res://')

var relative_path: String:
	get:
		if relative_path:
			return relative_path
		else:
			return _source_file_path
	set(new):
		relative_path = relative_path.trim_prefix('res://')

var dependencies: Array[Dictionary]

func is_valid_path(path: String) -> bool:
	return not path.begins_with('.') or relative_path

func get_dependency_path(path: String) -> String:
	if path.begins_with('.') and relative_path:
		return relative_path.get_base_dir().path_join(path).simplify_path()
	return path.simplify_path()

func get_dependency(path: String, type: DependencyType) -> Resource:
	path = get_dependency_path(path)
	if not path:
		return
	return ResourceLoader.load(path)

func add_dependency(object: BamObject, path: String, type: DependencyType) -> void:
	dependencies.append({
		'path': get_dependency_path(path),
		'type': type,
		'object': object,
	})
