extends LevelMap

const BOX_SCENE = preload("res://scenes/box.tscn")
const WAYPOINT_SCENE = preload("res://scenes/waypoint.tscn")
const HEATMAP_CELL_SCENE = preload("res://scenes/heatmap_cell.tscn")
const TUNNEL_CELL_SCENE = preload("res://scenes/tunnel_cell.tscn")

@onready var gameplay = $".."
@onready var camera: Camera3D = $"../Camera"

@onready var player: Player = $Player
@onready var boxes_container: Node3D = $Boxes
@onready var waypoints_container: Node3D = $Waypoints
@onready var lower_bounds_container: Node3D = $LowerBounds
@onready var tunnels_container: Node3D = $Tunnels
@onready var path_preview_container: Node3D = $PathPreview

@onready var enter_goal_player: AudioStreamPlayer3D = $Player/EnterGoalPlayer
@onready var leave_goal_player: AudioStreamPlayer3D = $Player/LeaveGoalPlayer

@export var solver_algorithm: E.Algorithm
@export var solver_strategy: E.Strategy

@export var pushable_hint: bool

@export var waypoint_height: float = 0.01

@export_group("Path Preview")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var enable_path_preview: bool = true
@export var path_preview_material: StandardMaterial3D
@export var path_preview_width: float = 0.1
@export var path_preview_height: float = 0.02

@export_group("", "")
@export
var show_lower_bounds: bool:
	set(value):
		show_lower_bounds = value
		_build_lower_bounds()

@export var lower_bounds_height := 0.01

@export
var show_tunnels: bool:
	set(value):
		show_tunnels = value
		_build_tunnels()

@export var tunnels_height := 0.015

var _is_instant: bool
var _selected_box: Box
var _solving: bool = false


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	player_moved.connect(_on_player_moved)
	solved.connect(_on_solved)
	box_enter_goal.connect(enter_goal_player.play)
	box_leave_goal.connect(leave_goal_player.play)
	solve_completed.connect(_on_solve_completed)
	solve_failed.connect(_on_solve_failed)

	assert(SceneTransition.level_id != null)
	var level := Database.get_level(SceneTransition.level_id)
	load_from_string(level.get("map_xsb"))

	var snapshot := Database.get_snapshot(SceneTransition.level_id, true)
	fast_forward(snapshot)

	rebuild_player_and_boxes()

	reset_camera_position()

	await get_tree().process_frame
	gameplay.hud.level_label.text = str(SceneTransition.level_index)
	update_ui()


func _process(_delta: float) -> void:
	if _solving:
		poll_solve()
		return

	if Input.is_action_just_pressed("undo_all"):
		do_undo_all()
		return

	if player.is_moving or _is_box_moving():
		return

	if Input.is_action_pressed("move_right"):
		_execute_path([E.Direction.RIGHT])
	elif Input.is_action_pressed("move_left"):
		_execute_path([E.Direction.LEFT])
	elif Input.is_action_pressed("move_up"):
		_execute_path([E.Direction.UP])
	elif Input.is_action_pressed("move_down"):
		_execute_path([E.Direction.DOWN])
	else:
		return


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		var content := DisplayServer.clipboard_get()
		Database.import_level_from_string(content, "Imported")
		load_from_string(content)
		rebuild_player_and_boxes()
		_build_lower_bounds()
		_build_tunnels()
		update_ui()
		reset_camera_position()
	elif Input.is_action_just_pressed("export_to_clipboard"):
		DisplayServer.clipboard_set(get_map_xsb())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _solving or player.is_moving:
			get_viewport().set_input_as_handled()
			return

		var space_state := get_world_3d().direct_space_state
		var ray_origin := camera.project_ray_origin(event.position)
		var ray_end := ray_origin + camera.project_ray_normal(event.position) * 1000.0
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		query.collide_with_bodies = false

		# Checks if the click was on an empty space (without Area3D)
		if space_state.intersect_ray(query).is_empty():
			deselect_box()


func do_undo() -> void:
	undo()
	deselect_box()
	rebuild_player_and_boxes()
	update_ui()


func do_redo() -> void:
	redo()
	deselect_box()
	rebuild_player_and_boxes()
	update_ui()


func do_undo_all() -> void:
	undo_all()
	deselect_box()
	rebuild_player_and_boxes()
	update_ui()


func begin_solve() -> void:
	if _solving:
		return

	deselect_box()
	_solving = true
	update_ui()
	start_solve(solver_algorithm, solver_strategy)


func abort_solve() -> void:
	if not _solving:
		return

	cancel_solve()
	_solving = false
	update_ui()


func _on_solve_completed(directions: Array) -> void:
	_solving = false
	update_ui()
	await _execute_path(directions)


func _on_solve_failed(error: String) -> void:
	_solving = false
	update_ui()
	push_warning("Solver failed: " + error)


func wait_for_moves_finished() -> void:
	if player.is_moving:
		await player.move_finished
	for box in boxes_container.get_children():
		if box.is_moving:
			await box.move_finished


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "gameplay":
		if key == "animation_speed":
			_is_instant = value == E.AnimationSpeed.INSTANT
		elif key == "pathfinding_strategy":
			pathfinding_strategy = value
		elif key == "theme":
			create_theme_variants()
			rebuild()
			rebuild_player_and_boxes()
		elif key == "checkerboard":
			checkerboard_shading = value
			rebuild()
	elif section == "assists":
		if key == "deadlock_hint":
			deadlock_hint = value
			rebuild()
		elif key == "pushable_hint":
			pushable_hint = value
			_update_pushable_hint()
		elif key == "lower_bounds":
			show_lower_bounds = value
		elif key == "tunnels":
			show_tunnels = value
		elif key == "algorithm":
			solver_algorithm = value
		elif key == "solver_strategy":
			solver_strategy = value


func _on_waypoint_clicked(to: Vector2i) -> void:
	deselect_box()
	await _execute_path(get_box_move_path(to))


func _execute_path(directions: Array) -> void:
	for direction in directions:
		if is_solved():
			break
		move_by(direction)
		# Wait for animations to finish if not instant
		if not _is_instant:
			await wait_for_moves_finished()
	if _is_instant:
		rebuild_player_and_boxes()
	update_ui()


func _is_box_moving() -> bool:
	for box in boxes_container.get_children():
		if box.is_moving:
			return true
	return false


func rebuild_player_and_boxes() -> void:
	for child in boxes_container.get_children():
		child.queue_free()

	for box_position in get_box_positions():
		var box: Box = BOX_SCENE.instantiate()
		box.position = Vector3(box_position.x, 0.0, box_position.y)
		box.selected.connect(on_box_selected.bind(box))
		box.unselected.connect(on_box_unselected)
		box.move_finished.connect(_update_pushable_hint)
		boxes_container.add_child(box)

	var player_position := get_player_position()
	player.position = Vector3(player_position.x, 0.0, player_position.y)
	player.set_facing(get_player_direction())

	_update_pushable_hint()


func _update_pushable_hint() -> void:
	if not pushable_hint:
		for box in boxes_container.get_children():
			box.disabled = false
		return

	var pushable_positions := get_pushable_box_positions()
	for box in boxes_container.get_children():
		var grid_pos: Vector2i = box.grid_position()
		var is_pushable := pushable_positions.any(func(pos: Vector2i) -> bool:
			return pos == grid_pos
		)
		box.disabled = not is_pushable


func on_box_selected(box: Box) -> void:
	if _selected_box != null and _selected_box != box:
		_selected_box.deselect()

	_selected_box = box
	_build_waypoints(box.grid_position())


func on_box_unselected() -> void:
	_selected_box = null
	_clear_waypoints()


func deselect_box() -> void:
	if _selected_box != null:
		var selected_box := _selected_box
		_selected_box = null
		selected_box.deselect()
	_clear_waypoints()


func _build_waypoints(from: Vector2i) -> void:
	_clear_waypoints()
	for to in get_waypoints(from):
		var waypoint = WAYPOINT_SCENE.instantiate()
		waypoint.position = Vector3(to.x, waypoint_height, to.y)
		waypoint.clicked.connect(func() -> void:
			_on_waypoint_clicked(to)
		)
		waypoint.hovered.connect(func() -> void:
			_show_path_preview(to)
		)
		waypoint.unhovered.connect(_clear_path_preview)
		waypoints_container.add_child(waypoint)


func _clear_waypoints() -> void:
	for child in waypoints_container.get_children():
		child.queue_free()
	_clear_path_preview()


func _build_lower_bounds() -> void:
	for child in lower_bounds_container.get_children():
		child.queue_free()

	if not show_lower_bounds:
		return

	var min_costs: Dictionary = get_min_costs(solver_strategy)
	if min_costs.is_empty():
		return
	var max_lower_bound: int = min_costs.values().max()
	for pos in min_costs:
		var heatmap_cell: HeatmapCell = HEATMAP_CELL_SCENE.instantiate()
		heatmap_cell.position = Vector3(pos.x, lower_bounds_height, pos.y)
		lower_bounds_container.add_child(heatmap_cell)
		heatmap_cell.setup(min_costs[pos], max_lower_bound)


func _build_tunnels() -> void:
	for child in tunnels_container.get_children():
		child.queue_free()

	if not show_tunnels:
		return

	var positions := get_tunnels()
	for pos in positions:
		var tunnel_cell = TUNNEL_CELL_SCENE.instantiate()
		tunnel_cell.position = Vector3(pos.x, tunnels_height, pos.y)
		tunnels_container.add_child(tunnel_cell)


func _show_path_preview(to: Vector2i) -> void:
	if not enable_path_preview:
		return

	var box_path := get_box_path(to)
	if box_path.size() < 2:
		return
	var path2d := _smooth_path(box_path, 0.3, 8)

	var path3d: Array[Vector3] = []
	for point in path2d:
		path3d.append(Vector3(point.x + 0.5, path_preview_height, point.y + 0.5))

	path_preview_container.mesh = _create_path_mesh(path3d, path_preview_width)
	path_preview_container.material_override = path_preview_material


func _smooth_path(path: Array[Vector2i], corner_radius: float, resolution: int) -> Array[Vector2]:
	if path.size() < 3:
		var raw_path: Array[Vector2] = []
		for point in path:
			raw_path.append(Vector2(point))
		return raw_path

	var smoothed: Array[Vector2] = []
	smoothed.append(Vector2(path[0]))

	for i in range(1, path.size() - 1):
		var prev := Vector2(path[i - 1])
		var curr := Vector2(path[i])
		var next := Vector2(path[i + 1])

		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()

		# If the segment is straight or a 180° U-turn, skip smoothing
		if abs(dir_in.dot(dir_out)) > 0.99:
			smoothed.append(curr)
			continue

		var max_radius = min(curr.distance_to(prev) / 2.0, curr.distance_to(next) / 2.0)
		var actual_radius = min(corner_radius, max_radius)

		var curve_start = curr - dir_in * actual_radius
		var curve_end = curr + dir_out * actual_radius

		# Quadratic Bezier curve interpolation
		for j in range(resolution + 1):
			var t := float(j) / resolution
			var point = curve_start * (1 - t) * (1 - t) + curr * 2 * (1 - t) * t + curve_end * t * t
			smoothed.append(point)

	smoothed.append(Vector2(path[-1]))

	return smoothed


func _create_path_mesh(smoothed_path: Array[Vector3], width: float) -> ImmediateMesh:
	assert(smoothed_path.size() >= 2)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var half_width := width / 2.0
	for i in range(smoothed_path.size()):
		var curr := smoothed_path[i]
		var dir_prev := Vector3.ZERO
		var dir_next := Vector3.ZERO

		if i > 0:
			dir_prev = (curr - smoothed_path[i - 1]).normalized()
		if i < smoothed_path.size() - 1:
			dir_next = (smoothed_path[i + 1] - curr).normalized()

		var side: Vector3
		if dir_prev == Vector3.ZERO:
			# Start point
			side = dir_next.cross(Vector3.UP).normalized() * half_width
		elif dir_next == Vector3.ZERO:
			# End point
			side = dir_prev.cross(Vector3.UP).normalized() * half_width
		else:
			# Corner
			var tangent := (dir_prev + dir_next).normalized()
			if tangent == Vector3.ZERO:
				side = dir_prev.cross(Vector3.UP).normalized() * half_width
			else:
				var miter := tangent.cross(Vector3.UP).normalized()
				var normal_prev := dir_prev.cross(Vector3.UP).normalized()
				var dot_val := miter.dot(normal_prev)

				if abs(dot_val) < 0.001:
					side = normal_prev * half_width
				else:
					var miter_len := half_width / dot_val
					side = miter * miter_len

		mesh.surface_add_vertex(curr + side)
		mesh.surface_add_vertex(curr - side)

	mesh.surface_end()
	return mesh


func _clear_path_preview() -> void:
	path_preview_container.mesh = null


func _on_player_moved(to: Vector2i, pushed: bool) -> void:
	# Skip animation if instant is enabled
	if _is_instant:
		return

	var from := Vector2i(round(player.global_position.x), round(player.global_position.z))
	player.move(to - from, pushed)
	update_ui()


func update_ui() -> void:
	# Update HUD labels
	gameplay.hud.moves_label.text = str(get_move_count())
	gameplay.hud.pushes_label.text = str(get_push_count())

	_update_pushable_hint()

	# Update toolbar buttons
	if _solving:
		gameplay.hud.undo_button.disabled = true
		gameplay.hud.redo_button.disabled = true
		gameplay.hud.undo_all_button.disabled = true
		gameplay.hud.solve_button.disabled = false
		gameplay.hud.transform_button.disabled = true
	else:
		if player.is_moving or _is_box_moving():
			gameplay.hud.undo_button.disabled = true
			gameplay.hud.redo_button.disabled = true
			gameplay.hud.undo_all_button.disabled = true
			gameplay.hud.solve_button.disabled = true
			gameplay.hud.transform_button.disabled = true
		else:
			gameplay.hud.undo_button.disabled = !can_undo()
			gameplay.hud.redo_button.disabled = !can_redo()
			gameplay.hud.undo_all_button.disabled = !can_undo()
			gameplay.hud.solve_button.disabled = false
			gameplay.hud.transform_button.disabled = false


func _on_solved() -> void:
	enter_goal_player.stop()


func reset_camera_position() -> void:
	var center := get_dimensions() / 2.0
	var fit_zoom := get_fit_zoom()

	camera._target_position = Vector3(center.x, fit_zoom, center.y)
	camera.global_position = camera._target_position
	camera.max_zoom_factor = fit_zoom
	camera.zoom_factor = camera.max_zoom_factor


func get_fit_zoom(margin: float = 2.0) -> float:
	var viewport := get_viewport()
	var aspect = float(viewport.size.x) / float(viewport.size.y)
	var dimensions := get_dimensions()
	return max((dimensions.x + margin) / aspect, dimensions.y + margin)
