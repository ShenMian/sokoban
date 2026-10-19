extends Node

const GAMEPLAY_SCENE_PATH := "res://scenes/gameplay.tscn"
const LEVEL_LIST_SCENE_PATH := "res://scenes/ui/level_list.tscn"

var collection_name: String = ""
var level_index: int = -1

var _level_id: int
var _gameplay_scene: PackedScene


func _ready() -> void:
	_gameplay_scene = await _load_packed_scene(GAMEPLAY_SCENE_PATH)


## Loads a level from a collection and transitions to gameplay.
func load_level(new_collection_name: String, new_level_index: int) -> void:
	collection_name = new_collection_name
	level_index = new_level_index
	_level_id = Database.get_level_id_by_index(collection_name, level_index)

	var scene := await _get_gameplay_scene()
	get_tree().change_scene_to_packed(scene)


## Returns true if there is a previous level in the collection.
func has_previous_level() -> bool:
	return level_index > 1


## Returns true if there is a next level in the collection.
func has_next_level() -> bool:
	return level_index < get_collection_size()


## Returns the number of levels in the collection.
func get_collection_size() -> int:
	return Database.get_collection_size(collection_name)


## Returns the id of the current level.
func get_level_id() -> int:
	return _level_id


## Loads the previous level in the collection.
func load_previous_level() -> void:
	assert(has_previous_level())
	level_index -= 1
	load_level(collection_name, level_index)


## Loads the next level in the collection.
func load_next_level() -> void:
	assert(has_next_level())
	level_index += 1
	load_level(collection_name, level_index)


## Transitions to the level list (main menu).
func load_main_menu() -> void:
	var scene := await _load_packed_scene(LEVEL_LIST_SCENE_PATH)
	get_tree().change_scene_to_packed(scene)


## Returns the gameplay scene, waiting for its background load if it is still
## running.
func _get_gameplay_scene() -> PackedScene:
	while _gameplay_scene == null:
		await get_tree().process_frame
	return _gameplay_scene


## Loads a scene, using a threaded load where the platform supports it.
func _load_packed_scene(path: String) -> PackedScene:
	if OS.has_feature("web"):
		# Threaded resource loading is broken on the web when both extension
		# support and thread support are enabled, so the status never leaves
		# THREAD_LOAD_IN_PROGRESS.
		# - https://github.com/godotengine/godot/issues/104498
		# - https://github.com/godotengine/godot/issues/112958
		return load(path) as PackedScene

	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene
