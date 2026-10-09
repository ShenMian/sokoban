extends Control
class_name HUD

signal undo_requested
signal redo_requested
signal undo_all_requested
signal request_start_solve
signal request_stop_solve
signal transform_requested
signal previous_level_requested
signal next_level_requested
signal pause_requested

@onready var status_panel: PanelContainer = $StatusPanel
@onready var toolbar_panel: PanelContainer = $ToolbarPanel

@onready var level_label: Label = %LevelValue
@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue

@onready var undo_button: ButtonFx = %UndoButton
@onready var redo_button: ButtonFx = %RedoButton
@onready var undo_all_button: ButtonFx = %UndoAllButton
@onready var solve_button: ButtonFx = %SolveButton
@onready var transform_button: ButtonFx = %TransformButton
@onready var transform_label: Label = %TransformLabel
@onready var previous_level_button: ButtonFx = %PreviousButton
@onready var next_level_button: ButtonFx = %NextButton
@onready var pause_button: ButtonFx = %PauseButton

## The scaling factor applied to HUD panels on touchscreen devices.
@export var touch_ui_scale: float = 1.25

var _solving: bool = false
var _solve_icon_tween: Tween


func _ready() -> void:
	if DisplayServer.is_touchscreen_available():
		status_panel.pivot_offset = Vector2(status_panel.size.x / 2.0, 0.0)
		status_panel.scale = Vector2(touch_ui_scale, touch_ui_scale)
		toolbar_panel.pivot_offset = Vector2(toolbar_panel.size.x / 2.0, toolbar_panel.size.y)
		toolbar_panel.scale = Vector2(touch_ui_scale, touch_ui_scale)
		pause_button.visible = true

	undo_button.pressed.connect(func() -> void: undo_requested.emit())
	redo_button.pressed.connect(func() -> void: redo_requested.emit())
	undo_all_button.pressed.connect(func() -> void: undo_all_requested.emit())
	solve_button.pressed.connect(_on_solve_button_pressed)
	transform_button.pressed.connect(func() -> void: transform_requested.emit())
	previous_level_button.pressed.connect(func() -> void: previous_level_requested.emit())
	next_level_button.pressed.connect(func() -> void: next_level_requested.emit())
	pause_button.pressed.connect(func() -> void: pause_requested.emit())


func _on_solve_button_pressed() -> void:
	if _solving:
		_solving = false
		_stop_solving_tween()
		solve_button.modulate = Color.WHITE
		request_stop_solve.emit()
	else:
		_solving = true
		_start_solving_tween()
		request_start_solve.emit()


## Resets the solve button after a successful solve.
func solve_complete(_directions: Array) -> void:
	_solving = false
	_stop_solving_tween()
	solve_button.modulate = Color.WHITE


## Flashes the solve button red after a failed solve.
func solve_fail(_error: String) -> void:
	_solving = false
	_stop_solving_tween()
	solve_button.modulate = Color.RED
	create_tween() \
			.tween_property(solve_button, "modulate", Color.WHITE, 2.0) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)


## Pulses the solve button while a solve is running.
func _start_solving_tween() -> void:
	_stop_solving_tween()
	_solve_icon_tween = create_tween().set_loops()
	_solve_icon_tween \
			.tween_property(solve_button, "modulate", Color(0.5, 0.8, 1.0), 0.6) \
			.set_trans(Tween.TRANS_SINE)
	_solve_icon_tween \
			.tween_property(solve_button, "modulate", Color(0.0, 0.567, 0.823, 1.0), 0.6) \
			.set_trans(Tween.TRANS_SINE)


## Stops the solve button pulse.
func _stop_solving_tween() -> void:
	if _solve_icon_tween:
		_solve_icon_tween.kill()
		_solve_icon_tween = null
