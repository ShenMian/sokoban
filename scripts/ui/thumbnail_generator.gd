extends SubViewport
class_name ThumbnailGenerator

signal thumbnail_generated(index: int, texture: Texture2D)

@onready var level_map: LevelMap = $LevelMap
@onready var boxes: MultiMeshInstance3D = $LevelMap/Boxes
@onready var player: Node3D = $LevelMap/Player
@onready var camera: Camera3D = $Camera

var levels: Array[Dictionary] = []
var _queue: Array[int] = []
var _generation: int = 0

var _is_processing: bool = false


func _ready() -> void:
	if Settings.get_value("gameplay", "2d_view"):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE


func set_levels(new_levels: Array[Dictionary]) -> void:
	_generation += 1
	levels = new_levels
	_queue.clear()


func submit_queue(new_queue: Array[int]) -> void:
	_queue = new_queue


func set_preview_size(new_size: Vector2) -> void:
	size = new_size


func _process(_delta: float) -> void:
	if _queue.is_empty() or _is_processing:
		return

	_is_processing = true
	var generation := _generation
	var index: int = _queue.pop_front()

	level_map.load_from_string(levels[index]["map_xsb"])
	rebuild_player_and_boxes()

	var dimensions := Vector2(level_map.get_dimensions())
	var center := dimensions / 2.0
	var fit_zoom = get_fit_zoom(level_map)

	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.global_position = Vector3(center.x, fit_zoom / (2.0 * tan(deg_to_rad(camera.fov) / 2.0)), center.y)
	elif camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = fit_zoom
	else:
		assert(false, "unreachable")

	render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	if generation != _generation:
		_is_processing = false
		return

	var image := get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)

	thumbnail_generated.emit(index, texture)
	_is_processing = false


func rebuild_player_and_boxes() -> void:
	const OFFSET = Vector3(0.5, 0.0, 0.5)

	var box_positions := level_map.get_box_positions()

	var multi_mesh := boxes.multimesh
	multi_mesh.instance_count = box_positions.size()
	for i in range(box_positions.size()):
		var position = Vector3(box_positions[i].x, 0.0, box_positions[i].y) + OFFSET
		multi_mesh.set_instance_transform(i, Transform3D().translated(position))

	var player_position := level_map.get_player_position()
	player.position = Vector3(player_position.x, 0.0, player_position.y) + OFFSET


func get_fit_zoom(map: LevelMap, margin: float = 1.0) -> float:
	var aspect = float(size.x) / float(size.y)
	var dimensions := map.get_dimensions()
	return max((dimensions.x + margin) / aspect, dimensions.y + margin)
