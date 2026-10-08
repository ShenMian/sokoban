extends Control
class_name HUD

signal undo_requested
signal redo_requested
signal undo_all_requested
signal solve_requested
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
	solve_button.pressed.connect(func() -> void: solve_requested.emit())
	transform_button.pressed.connect(func() -> void: transform_requested.emit())
	previous_level_button.pressed.connect(func() -> void: previous_level_requested.emit())
	next_level_button.pressed.connect(func() -> void: next_level_requested.emit())
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
