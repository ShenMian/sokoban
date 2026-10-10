extends PanelContainer
class_name DraggablePanel
## Draggable panel with a title bar. Add custom content to `body`.
##
## Assign the nodes below in the inspector when the scene structure differs.
## They are exported node references, so no lookup is needed at runtime.


## Text shown in the title bar.
@export var title: String = "Panel":
	set(value):
		title = value
		if is_node_ready() and title_label != null:
			title_label.text = value

## Title bar that starts dragging.
@export var handle: Control
## Label that displays `title`.
@export var title_label: Label
## Container for custom content below the title bar.
@export var body: VBoxContainer
## Optional button that collapses `body`. Leave empty for no collapsing.
@export var collapse_button: Button

var _collapsed := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _floating := false


func _ready() -> void:
	if handle == null or title_label == null or body == null:
		push_warning("DraggablePanel: handle, title label or body not assigned, dragging disabled")
		return

	title_label.text = title
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.gui_input.connect(_on_handle_gui_input)
	if collapse_button != null:
		collapse_button.pressed.connect(_on_collapse_pressed)


## Collapses or expands the content below the title bar.
func _on_collapse_pressed() -> void:
	_collapsed = not _collapsed
	body.visible = not _collapsed
	collapse_button.text = "+" if _collapsed else "-"


## Tracks presses anywhere: starts a drag when the press lands inside the
## title bar, so dragging works even if another layer eats the GUI event.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_node_ready() and handle != null and handle.get_global_rect().has_point(get_global_mouse_position()):
				_begin_drag(get_global_mouse_position())
		else:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging:
		_set_clamped_position(get_global_mouse_position() - _drag_offset)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if is_node_ready() and handle != null and handle.get_global_rect().has_point(event.position):
				_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventScreenDrag and _dragging:
		_set_clamped_position(event.position - _drag_offset)


## Handles title bar GUI events directly and marks them handled
## so clicks don't fall through to whatever is behind the panel.
func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(get_global_mouse_position())
		else:
			_end_drag()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_clamped_position(get_global_mouse_position() - _drag_offset)
		accept_event()


## Starts a drag with a grab cursor. Hover already shows a move cursor.
func _begin_drag(from: Vector2) -> void:
	_make_floating()
	_drag_offset = from - global_position
	_dragging = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


## Stops a drag and restores the default cursor.
func _end_drag() -> void:
	_dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Drops the scene anchors so the panel stays where it was dragged.
func _make_floating() -> void:
	if _floating:
		return
	_floating = true
	var pos := global_position
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = pos.x
	offset_top = pos.y
	offset_right = pos.x + size.x
	offset_bottom = pos.y + size.y
	global_position = pos


## Moves the panel while keeping it inside the viewport.
func _set_clamped_position(pos: Vector2) -> void:
	var max_pos := get_viewport_rect().size - size
	global_position = Vector2(clampf(pos.x, 0.0, maxf(max_pos.x, 0.0)), clampf(pos.y, 0.0, maxf(max_pos.y, 0.0)))
