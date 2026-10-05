extends CanvasLayer

signal transition_finished

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var overlay: ColorRect = $ColorRect

var level_id: int

var collection_name: String
var collection_count: int
var level_index: int

func load_level(new_collection_name: String, new_level_index: int) -> void:
	collection_name = new_collection_name
	collection_count = Database.get_collection_size(collection_name)
	level_index = new_level_index
	level_id = Database.get_level_id_by_index(collection_name, level_index)
	change_scene_to_file("res://scenes/gameplay.tscn")


func has_previous_level() -> bool:
	return level_index > 1


func has_next_level() -> bool:
	return level_index < collection_count


func load_previous_level() -> void:
	assert(has_previous_level())
	level_index -= 1
	load_level(collection_name, level_index)


func load_next_level() -> void:
	assert(has_next_level())
	level_index += 1
	load_level(collection_name, level_index)


func load_main_menu() -> void:
	change_scene_to_file("res://scenes/ui/level_list.tscn")


func change_scene_to_file(path: String) -> void:
	overlay.visible = true
	animation_player.play("fade_in")

	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var scene = ResourceLoader.load_threaded_get(path)
	get_tree().change_scene_to_packed(scene)

	animation_player.play_backwards("fade_in")
	await animation_player.animation_finished
	overlay.visible = false
	transition_finished.emit()
