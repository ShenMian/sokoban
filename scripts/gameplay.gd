extends Node3D

@onready var level_map: LevelMap = $LevelMap

@onready var hud: Control = $HudLayer/HUD
@onready var pause_menu: PauseMenu = $MenuLayer/PauseMenu
@onready var settings_menu: SettingsMenu = $MenuLayer/SettingsMenu
@onready var credits: Control = $MenuLayer/Credits
@onready var victory_menu: VictoryMenu = $MenuLayer/VictoryMenu

@onready var status_panel: PanelContainer = $HudLayer/HUD/StatusPanel
@onready var toolbar_panel: PanelContainer = $HudLayer/HUD/ToolbarPanel

@onready var level_label: Label = %LevelValue
@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue

@onready var undo_button: ButtonFx = %UndoButton
@onready var redo_button: ButtonFx = %RedoButton
@onready var undo_all_button: ButtonFx = %UndoAllButton
@onready var solve_button: ButtonFx = %SolveButton
@onready var transform_button: ButtonFx = %TransformButton
@onready var transform_label: Label = %TransformLabel
@onready var previous_button: ButtonFx = %PreviousButton
@onready var next_button: ButtonFx = %NextButton
@onready var pause_button: ButtonFx = %PauseButton

## The scaling factor applied to HUD panels on touchscreen devices.
@export var touch_ui_scale: float = 1.25

const _TRANSFORM_LABELS := ["", "90°", "180°", "270°", "↔", "↔\n90°", "↔\n180°", "↔\n270°"]

var _transform_state: int = 0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)

	if DisplayServer.is_touchscreen_available():
		status_panel.pivot_offset = Vector2(status_panel.size.x / 2.0, 0.0)
		status_panel.scale = Vector2(touch_ui_scale, touch_ui_scale)
		toolbar_panel.pivot_offset = Vector2(toolbar_panel.size.x / 2.0, toolbar_panel.size.y)
		toolbar_panel.scale = Vector2(touch_ui_scale, touch_ui_scale)
		pause_button.visible = true

	previous_button.disabled = not SceneTransition.has_previous_level()
	next_button.disabled = not SceneTransition.has_next_level()

	pause_menu.closed.connect(_on_pause_closed)
	pause_menu.request_settings.connect(_on_pause_request_settings)
	pause_menu.request_credits.connect(_on_pause_request_credits)
	pause_menu.request_menu.connect(_on_request_menu)
	settings_menu.closed.connect(pause_menu.show)
	credits.closed.connect(pause_menu.show)

	level_map.solved.connect(_on_level_solved)
	victory_menu.request_next_level.connect(_on_request_next_level)
	victory_menu.request_menu.connect(_on_request_menu)

	undo_button.pressed.connect(level_map.do_undo)
	redo_button.pressed.connect(level_map.do_redo)
	undo_all_button.pressed.connect(_on_undo_all)
	solve_button.pressed.connect(level_map.do_solve)
	pause_button.pressed.connect(_open_pause_menu)
	transform_button.pressed.connect(_transform_level)
	previous_button.pressed.connect(_on_request_previous_level)
	next_button.pressed.connect(_on_request_next_level)


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
	transform_label.text = _TRANSFORM_LABELS[_transform_state]

	level_map.deselect_box()
	level_map.rebuild_player_and_boxes()
	level_map.update_ui()
	level_map.reset_camera_position()
