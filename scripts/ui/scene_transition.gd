extends CanvasLayer

signal transition_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var overlay: ColorRect = $ColorRect

var level_id: int

var collection_name: String
var collection_count: int
var level_index: int


## Loads a level from a collection and transitions to gameplay.
func load_level(new_collection_name: String, new_level_index: int) -> void:
	collection_name = new_collection_name
	collection_count = Database.get_collection_size(collection_name)
	level_index = new_level_index
	level_id = Database.get_level_id_by_index(collection_name, level_index)
	change_scene_to_file("res://scenes/gameplay.tscn")


## Returns true if there is a previous level in the collection.
func has_previous_level() -> bool:
	return level_index > 1


## Returns true if there is a next level in the collection.
func has_next_level() -> bool:
	return level_index < collection_count


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
	change_scene_to_file("res://scenes/ui/level_list.tscn")


## Fades out, loads the given scene, then fades back in.
func change_scene_to_file(path: String) -> void:
	overlay.visible = true
	animation_player.play("fade_in")

	var scene: PackedScene
	if OS.has_feature("web"):
		# Threaded resource loading is broken on the web when both extension
		# support and thread support are enabled, so the status never leaves
		# THREAD_LOAD_IN_PROGRESS.
		# - https://github.com/godotengine/godot/issues/104498
		# - https://github.com/godotengine/godot/issues/112958
		scene = load(path) as PackedScene
	else:
		ResourceLoader.load_threaded_request(path)
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		scene = ResourceLoader.load_threaded_get(path) as PackedScene

	get_tree().change_scene_to_packed(scene)

	animation_player.play_backwards("fade_in")
	await animation_player.animation_finished
	overlay.visible = false
	transition_finished.emit()
