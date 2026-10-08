extends Node3D

@onready var level_map: LevelMap = $LevelMap
@onready var hud: HUD = $HudLayer/HUD

@onready var pause_menu: PauseMenu = $MenuLayer/PauseMenu
@onready var settings_menu: SettingsMenu = $MenuLayer/SettingsMenu
@onready var credits: Control = $MenuLayer/Credits
@onready var victory_menu: VictoryMenu = $MenuLayer/VictoryMenu

const _TRANSFORM_LABELS := ["", "90°", "180°", "270°", "↔", "↔\n90°", "↔\n180°", "↔\n270°"]

var _transform_state: int = 0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)

	hud.previous_level_button.disabled = not SceneTransition.has_previous_level()
	hud.next_level_button.disabled = not SceneTransition.has_next_level()

	pause_menu.closed.connect(_on_pause_closed)
	pause_menu.request_settings.connect(_on_pause_request_settings)
	pause_menu.request_credits.connect(_on_pause_request_credits)
	pause_menu.request_menu.connect(_on_request_menu)
	settings_menu.closed.connect(pause_menu.show)
	credits.closed.connect(pause_menu.show)

	level_map.solved.connect(_on_level_solved)
	victory_menu.request_next_level.connect(_on_request_next_level)
	victory_menu.request_menu.connect(_on_request_menu)

	hud.undo_requested.connect(level_map.do_undo)
	hud.redo_requested.connect(level_map.do_redo)
	hud.undo_all_requested.connect(_on_undo_all)
	hud.request_start_solve.connect(level_map.begin_solve)
	hud.request_stop_solve.connect(level_map.abort_solve)
	level_map.solve_completed.connect(hud.solve_complete)
	level_map.solve_failed.connect(hud.solve_fail)
	hud.pause_requested.connect(_open_pause_menu)
	hud.transform_requested.connect(_transform_level)
	hud.previous_level_requested.connect(_on_request_previous_level)
	hud.next_level_requested.connect(_on_request_next_level)


func _exit_tree() -> void:
	get_tree().set_quit_on_go_back(true)


func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_request_menu()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_auto_save()


func _on_request_next_level() -> void:
	_auto_save()
	SceneTransition.load_next_level()


func _on_request_previous_level() -> void:
	_auto_save()
	SceneTransition.load_previous_level()


func _on_undo_all() -> void:
	level_map.do_undo_all()
	_auto_save()


func _on_request_menu() -> void:
	_auto_save()
	SceneTransition.load_main_menu()


func _auto_save():
	if level_map.is_solved():
		Database.clear_snapshot(SceneTransition.level_id, true)
	elif level_map.get_actions_lurd().is_empty():
		Database.clear_snapshot(SceneTransition.level_id, true)
	else:
		Database.add_snapshot(SceneTransition.level_id, level_map.get_actions_lurd(), true)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _open_pause_menu():
	level_map.deselect_box()
	hud.hide()
	pause_menu.open()


func _on_pause_closed() -> void:
	hud.show()


func _on_pause_request_settings() -> void:
	pause_menu.hide()
	settings_menu.open()


func _on_pause_request_credits() -> void:
	pause_menu.hide()
	credits.open()


func _on_level_solved() -> void:
	await level_map.wait_for_moves_finished()
	while _transform_state != 0:
		_transform_level()
	victory_menu.open(Actions.new(level_map.get_actions_lurd()))


func _transform_level() -> void:
	level_map.rotate_cw()
	if _transform_state % 4 == 3:
		level_map.flip_horizontal()

	_transform_state = (_transform_state + 1) % 8
	hud.transform_label.text = _TRANSFORM_LABELS[_transform_state]

	level_map.deselect_box()
	level_map.rebuild_player_and_boxes()
	level_map.update_ui()
	level_map.reset_camera_position()
