extends LevelMap

const BOX_SCENE = preload("res://scenes/box.tscn")
const WAYPOINT_SCENE = preload("res://scenes/waypoint.tscn")
const HEATMAP_CELL_SCENE = preload("res://scenes/heatmap_cell.tscn")
const TUNNEL_CELL_SCENE = preload("res://scenes/tunnel_cell.tscn")

@onready var hud = $"../HudLayer/HUD"
@onready var camera: Camera3D = $"../Camera"

@onready var player: Player = $Player
@onready var boxes_container: Node3D = $Boxes
@onready var waypoints_container: Node3D = $Waypoints
@onready var lower_bounds_container: Node3D = $LowerBounds
@onready var tunnels_container: Node3D = $Tunnels
@onready var path_preview: PathPreview = $PathPreview

@onready var enter_goal_player: AudioStreamPlayer3D = $Player/EnterGoalPlayer
@onready var leave_goal_player: AudioStreamPlayer3D = $Player/LeaveGoalPlayer

## Algorithm used by the background solver.
@export var solver_algorithm: E.Algorithm
## Strategy used by the background solver.
@export var solver_strategy: E.Strategy

## Dim boxes that cannot currently be pushed.
@export var pushable_hint: bool

## Height of waypoint markers.
@export var waypoint_height: float = 0.01

## Show lower-bound heatmap.
@export
var show_lower_bounds: bool:
	set(value):
		show_lower_bounds = value
		_build_lower_bounds()

## Height of lower-bound heatmap cells.
@export var lower_bounds_height := 0.01

## Show tunnel overlay.
@export
var show_tunnels: bool:
	set(value):
		show_tunnels = value
		_build_tunnels()

## Height of tunnel overlay cells.
@export var tunnels_height := 0.015

## Teleport the pieces to the solver's current best state while solving.
@export
var show_best_state: bool = true:
	set(value):
		show_best_state = value
		if not value and is_node_ready():
			_clear_best_state()

var _is_instant: bool
var _selected_box: Box
var _solving: bool = false
# Last best-state snapshot, to skip redundant rebuilds.
var _last_best_state := {}


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	player_moved.connect(_on_player_moved)
	solved.connect(_on_solved)
	box_enter_goal.connect(func(_position: Vector2i) -> void: enter_goal_player.play())
	box_leave_goal.connect(func(_position: Vector2i) -> void: leave_goal_player.play())
	solve_completed.connect(_on_solve_completed)
	solve_no_solution.connect(_on_solve_no_solution)
	solve_cancelled.connect(_on_solve_cancelled)

	path_preview.setup(self)

	MapTheme.apply_theme_for_variants(self)

	assert(SceneTransition.level_id != null)
	var level := Database.get_level(SceneTransition.level_id)
	load_from_string(level.get("map_xsb"))

	var snapshot := Database.get_snapshot(SceneTransition.level_id, true)
	fast_forward(snapshot)

	_respawn_player_and_boxes()

	camera.reset_for_map(get_dimensions())

	await get_tree().process_frame
	hud.level_label.text = str(SceneTransition.level_index)
	update_hud()


func _process(_delta: float) -> void:
	if _solving:
		poll_solver()
		# `poll_solver()` may have just ended the solve.
		if _solving:
			_update_best_state()
		return

	if Input.is_action_just_pressed("undo_all"):
		undo_all()
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
	if Input.is_action_just_pressed("export_to_clipboard"):
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


## Applies one undo step.
func undo() -> void:
	undo_inner()
	deselect_box()
	place_player_and_boxes()
	update_hud()


## Applies one redo step.
func redo() -> void:
	redo_inner()
	deselect_box()
	place_player_and_boxes()
	update_hud()


## Undoes all moves.
func undo_all() -> void:
	undo_all_inner()
	deselect_box()
	place_player_and_boxes()
	update_hud()


## Starts solver.
func start_solver() -> void:
	if _solving:
		return

	deselect_box()
	_solving = true
	update_hud()
	start_solver_inner(solver_algorithm, solver_strategy)


## Stops solver.
func stop_solver() -> void:
	if not _solving:
		return

	stop_solver_inner()


func _on_solve_completed(directions: Array) -> void:
	_solving = false
	_clear_best_state()
	update_hud()
	await _execute_path(directions)


func _on_solve_no_solution() -> void:
	_solving = false
	_clear_best_state()
	update_hud()


func _on_solve_cancelled() -> void:
	_solving = false
	_clear_best_state()
	update_hud()


## Teleports the pieces to the solver's best state, so the search can be
## watched converging. The solver works on a copy, so the real game state is
## untouched and `place_player_and_boxes()` restores it.
func _update_best_state() -> void:
	if not show_best_state:
		return
	var best_state: Dictionary = get_solver_best_state()
	if best_state == _last_best_state:
		return
	_last_best_state = best_state
	if _last_best_state.is_empty():
		return
	place_player_and_boxes(_last_best_state["boxes"], _last_best_state["player"])


func _clear_best_state() -> void:
	_last_best_state = {}
	if not is_node_ready():
		return
	place_player_and_boxes()


## Waits for player and box animations to finish.
func wait_for_moves_finished() -> void:
	if player.is_moving:
		await player.move_finished
	for box in boxes_container.get_children():
		if box.is_moving:
			await box.move_finished


## Returns true if any box is animating.
func _is_box_moving() -> bool:
	for box in boxes_container.get_children():
		if box.is_moving:
			return true
	return false


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "gameplay":
		if key == "animation_speed":
			_is_instant = value == E.AnimationSpeed.INSTANT
		elif key == "pathfinding_strategy":
			pathfinding_strategy = value
		elif key == "theme":
			MapTheme.apply_theme_for_variants(self)
			rebuild()
			_respawn_player_and_boxes()
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
		elif key == "best_state":
			show_best_state = value
		elif key == "algorithm":
			solver_algorithm = value
		elif key == "solver_strategy":
			solver_strategy = value


func _on_waypoint_clicked(to: Vector2i) -> void:
	deselect_box()
	await _execute_path(get_box_move_path(to))


## Executes a sequence of move directions.
func _execute_path(directions: Array) -> void:
	for direction in directions:
		if is_solved():
			break
		move_player(direction)
		# Wait for animations to finish if not instant
		if not _is_instant:
			await wait_for_moves_finished()
	if _is_instant:
		place_player_and_boxes()
	update_hud()


## Moves the boxes and player to the given positions.
func place_player_and_boxes(
	box_positions: Array = get_box_positions(),
	player_position: Vector2i = get_player_position(),
) -> void:
	var boxes := boxes_container.get_children()
	for i in range(boxes.size()):
		boxes[i].position = Vector3(box_positions[i].x, 0.0, box_positions[i].y)
	player.position = Vector3(player_position.x, 0.0, player_position.y)
	player.set_facing(get_player_direction())

	_update_pushable_hint()


## Recreates the box nodes and places everything from the model state.
func _respawn_player_and_boxes() -> void:
	for child in boxes_container.get_children():
		boxes_container.remove_child(child)
		child.queue_free()

	var box_positions := get_box_positions()
	for box_position in box_positions:
		var box: Box = BOX_SCENE.instantiate()
		box.selected.connect(_on_box_selected.bind(box))
		box.unselected.connect(_on_box_unselected)
		box.move_finished.connect(_update_pushable_hint)
		boxes_container.add_child(box)

	place_player_and_boxes(box_positions)


## Updates pushable hint for all boxes.
##
## The hint reflects the live game state, so it is turned off while the solver
## runs with the best state shown, since the pieces are teleported away.
func _update_pushable_hint() -> void:
	if not pushable_hint or (_solving and show_best_state):
		_clear_pushable_hint()
		return

	var pushable_positions := get_pushable_box_positions()
	for box in boxes_container.get_children():
		var grid_pos: Vector2i = box.grid_position()
		var is_pushable := pushable_positions.any(func(pos: Vector2i) -> bool:
			return pos == grid_pos
		)
		box.disabled = not is_pushable


## Shows every box as pushable, clearing the dimming.
func _clear_pushable_hint() -> void:
	for box in boxes_container.get_children():
		box.disabled = false


func _on_box_selected(box: Box) -> void:
	select_box(box)


func _on_box_unselected() -> void:
	_selected_box = null
	_clear_waypoints()


## Selects a box and shows its waypoints.
func select_box(box: Box) -> void:
	if _selected_box == box:
		return
	deselect_box()
	_selected_box = box
	_build_waypoints(box.grid_position())


## Deselects the current box.
func deselect_box() -> void:
	if _selected_box != null:
		_selected_box.deselect()
		_selected_box = null
	_clear_waypoints()


## Builds waypoints from a box position.
func _build_waypoints(from: Vector2i) -> void:
	_clear_waypoints()
	for to in get_waypoints(from):
		var waypoint = WAYPOINT_SCENE.instantiate()
		waypoint.position = Vector3(to.x, waypoint_height, to.y)
		waypoint.clicked.connect(func() -> void: _on_waypoint_clicked(to))
		waypoint.hovered.connect(path_preview.show_path.bind(to))
		waypoint.unhovered.connect(path_preview.clear)
		waypoints_container.add_child(waypoint)


## Clears all waypoints and path preview.
func _clear_waypoints() -> void:
	for child in waypoints_container.get_children():
		child.queue_free()
	path_preview.clear()


## Builds lower-bound heatmap.
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


## Builds tunnel overlay.
func _build_tunnels() -> void:
	for child in tunnels_container.get_children():
		child.queue_free()

	if not show_tunnels:
		return

	var tunnels := get_tunnels()
	for tunnel in tunnels:
		var tunnel_cell: TunnelCell = TUNNEL_CELL_SCENE.instantiate()
		tunnel_cell.position = Vector3(tunnel[0].x, tunnels_height, tunnel[0].y)
		tunnels_container.add_child(tunnel_cell)
		tunnel_cell.setup(tunnel[1])


func _on_player_moved(to: Vector2i, pushed: bool) -> void:
	# Skip animation if instant is enabled
	if _is_instant:
		return

	var from := Vector2i(round(player.global_position.x), round(player.global_position.z))
	player.move(to - from, pushed)
	update_hud()


## Refreshes the HUD counters and toolbar button states.
func update_hud() -> void:
	# Update HUD labels
	hud.moves_label.text = str(get_move_count())
	hud.pushes_label.text = str(get_push_count())

	_update_pushable_hint()

	# Update toolbar buttons
	if _solving:
		hud.undo_button.disabled = true
		hud.redo_button.disabled = true
		hud.undo_all_button.disabled = true
		hud.solve_button.disabled = false
		hud.transform_button.disabled = true
	else:
		if player.is_moving or _is_box_moving():
			hud.undo_button.disabled = true
			hud.redo_button.disabled = true
			hud.undo_all_button.disabled = true
			hud.solve_button.disabled = true
			hud.transform_button.disabled = true
		else:
			hud.undo_button.disabled = !can_undo()
			hud.redo_button.disabled = !can_redo()
			hud.undo_all_button.disabled = !can_undo()
			hud.solve_button.disabled = false
			hud.transform_button.disabled = false


func _on_solved() -> void:
	enter_goal_player.stop()
