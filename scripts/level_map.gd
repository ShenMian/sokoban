extends LevelMap

const BOX_SCENE = preload("res://scenes/box.tscn")

@onready var hud = $"../HudLayer/HUD"
@onready var camera: Camera3D = $"../Camera"

@onready var player: Player = $Player
@onready var boxes_container: Node3D = $Boxes
@onready var waypoints: WaypointLayer = $Waypoints
@onready var lower_bounds: LowerBoundsLayer = $LowerBounds
@onready var tunnels: TunnelLayer = $Tunnels
@onready var path_preview: PathPreview = $PathPreview

@onready var enter_goal_player: AudioStreamPlayer3D = $Player/EnterGoalPlayer
@onready var leave_goal_player: AudioStreamPlayer3D = $Player/LeaveGoalPlayer

## Algorithm used by the background solver.
@export var solver_algorithm: E.Algorithm
## Strategy used by the background solver.
@export var solver_strategy: E.Strategy

## Dim boxes that cannot currently be pushed.
@export var pushable_hint: bool

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
	waypoints.setup(self)
	lower_bounds.setup(self)
	tunnels.setup(self)
	waypoints.waypoint_clicked.connect(_on_waypoint_clicked)
	waypoints.waypoint_hovered.connect(path_preview.show_path)
	waypoints.waypoint_unhovered.connect(path_preview.clear)

	MapTheme.apply_theme_for_variants(self)

	assert(SceneTransition.get_level_id() != null)
	var level := Database.get_level(SceneTransition.get_level_id())
	load_from_string(level.get("map_xsb"))

	var snapshot := Database.get_snapshot(SceneTransition.get_level_id(), true)
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
		_execute_path("R")
	elif Input.is_action_pressed("move_left"):
		_execute_path("L")
	elif Input.is_action_pressed("move_up"):
		_execute_path("U")
	elif Input.is_action_pressed("move_down"):
		_execute_path("D")
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

		var ray_origin := camera.project_ray_origin(event.position)
		var ray_end := ray_origin + camera.project_ray_normal(event.position) * 1000.0
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		query.collide_with_bodies = false

		# Checks if the click was on an empty space (without Area3D)
		var space_state := get_world_3d().direct_space_state
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


func _on_solve_completed(lurd: String) -> void:
	_solving = false
	_clear_best_state()
	update_hud()
	await _execute_path(lurd)


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
			lower_bounds.enable = value
		elif key == "tunnels":
			tunnels.enable = value
		elif key == "best_state":
			show_best_state = value
		elif key == "algorithm":
			solver_algorithm = value
		elif key == "solver_strategy":
			solver_strategy = value


func _on_waypoint_clicked(to: Vector2i) -> void:
	deselect_box()
	await _execute_path(get_box_move_path(to))


## Executes a LURD action sequence.
func _execute_path(path: String) -> void:
	if _is_instant:
		move_player_batch(path)
		place_player_and_boxes()
		update_hud()
		return


	const LURD_TO_DIRECTION := {
		"u": E.Direction.UP,
		"r": E.Direction.RIGHT,
		"d": E.Direction.DOWN,
		"l": E.Direction.LEFT,
	}
	for letter in path:
		if is_solved():
			break
		move_player(LURD_TO_DIRECTION[letter.to_lower()])
		await wait_for_moves_finished()
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
	waypoints.show_for(box.grid_position())


## Deselects the current box.
func deselect_box() -> void:
	if _selected_box != null:
		_selected_box.deselect()
		_selected_box = null
	_clear_waypoints()


## Clears the waypoints and the path preview.
func _clear_waypoints() -> void:
	waypoints.clear()
	path_preview.clear()


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
