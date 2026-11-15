extends PanelContainer
class_name DraggablePanel
## Draggable and optionally resizable panel with a title bar. Add custom content to `body`.
##
## Assign the nodes below in the inspector when the scene structure differs.
## They are exported node references, so no lookup is needed at runtime.

## Directions the bottom-right corner can resize the panel along.
enum ResizeAxis {
	NONE = 0,
	HORIZONTAL = 1,
	VERTICAL = 2,
	BOTH = 3,
}

## Size of the bottom-right corner that starts a resize.
const RESIZE_GRIP_SIZE := 14.0
## Inset from the panel edge that keeps the grip lines inside the corner radius.
const GRIP_INSET := 6.0
## Grip lines drawn in the bottom-right corner, shortest first.
const GRIP_LINES := 3
const GRIP_LINE_LENGTH := 3.0
const GRIP_LINE_SPACING := 4.0
const GRIP_COLOR := Color(1.0, 1.0, 1.0, 0.35)

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
## Axes the bottom-right corner resizes along. `NONE` disables resizing.
@export var resize_axis: ResizeAxis = ResizeAxis.NONE:
	set(value):
		resize_axis = value
		queue_redraw()
		_update_grip()

var _collapsed := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _floating := false
var _resizing := false
var _resize_origin := Vector2.ZERO
var _resize_start_size := Vector2.ZERO
var _grip: Control


func _ready() -> void:
	_setup_grip()
	if handle == null or title_label == null or body == null:
		push_warning("DraggablePanel: handle, title label or body not assigned, dragging disabled")
		return

	title_label.text = title
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.gui_input.connect(_on_handle_gui_input)
	if collapse_button != null:
		collapse_button.pressed.connect(_on_collapse_pressed)


## Creates the invisible handle above the content that shows the resize
## cursor. Being a real control lets it override cursors of children below.
func _setup_grip() -> void:
	if _grip != null:
		return

	var overlay := Control.new()
	overlay.name = "ResizeOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_grip = Control.new()
	_grip.name = "ResizeGrip"
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(_grip)
	_grip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_grip.offset_left = -RESIZE_GRIP_SIZE
	_grip.offset_top = -RESIZE_GRIP_SIZE
	_update_grip()


## Keeps the grip in sync with the enabled resize directions.
func _update_grip() -> void:
	if _grip == null:
		return
	_grip.visible = resize_axis != ResizeAxis.NONE
	_grip.mouse_default_cursor_shape = _grip_cursor_shape()


## Collapses or expands the content below the title bar.
func _on_collapse_pressed() -> void:
	_collapsed = not _collapsed
	body.visible = not _collapsed
	collapse_button.text = "+" if _collapsed else "-"


## Tracks presses anywhere: starts a drag when the press lands inside the
## title bar and a resize when it lands in the bottom-right corner, so both
## work even if another layer eats the GUI event.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(get_global_mouse_position())
		else:
			_end_drag()
			_end_resize()
	elif event is InputEventMouseMotion:
		if _dragging:
			_set_clamped_position(get_global_mouse_position() - _drag_offset)
		elif _resizing:
			_set_clamped_size(_resize_start_size + get_global_mouse_position() - _resize_origin)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.position)
		else:
			_end_drag()
			_end_resize()
	elif event is InputEventScreenDrag:
		if _dragging:
			_set_clamped_position(event.position - _drag_offset)
		elif _resizing:
			_set_clamped_size(_resize_start_size + event.position - _resize_origin)


## Starts a resize or a drag depending on where the press landed.
func _on_press(pos: Vector2) -> void:
	if _is_in_grip(pos):
		get_viewport().set_input_as_handled()
		_begin_resize(pos)
	elif is_node_ready() and handle != null and handle.get_global_rect().has_point(pos):
		_begin_drag(pos)


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


## Starts a resize from the bottom-right corner with a matching cursor.
func _begin_resize(from: Vector2) -> void:
	_make_floating()
	_resize_origin = from
	_resize_start_size = size
	_resizing = true
	Input.set_default_cursor_shape(_resize_input_cursor())


## Stops a resize and restores the default cursor.
func _end_resize() -> void:
	if not _resizing:
		return
	_resizing = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Whether `pos` lies in the bottom-right corner that starts a resize.
func _is_in_grip(pos: Vector2) -> bool:
	return _grip != null and _grip.visible and _grip.get_global_rect().has_point(pos)


## Whether `resize_axis` allows resizing along `axis`.
func _has_axis(axis: ResizeAxis) -> bool:
	return (resize_axis & axis) != 0


## Cursor shape of the grip for the enabled resize directions.
func _grip_cursor_shape() -> Control.CursorShape:
	match resize_axis:
		ResizeAxis.HORIZONTAL:
			return Control.CURSOR_HSIZE
		ResizeAxis.VERTICAL:
			return Control.CURSOR_VSIZE
		_:
			return Control.CURSOR_FDIAGSIZE


## Cursor shape used while resizing.
func _resize_input_cursor() -> Input.CursorShape:
	match resize_axis:
		ResizeAxis.HORIZONTAL:
			return Input.CURSOR_HSIZE
		ResizeAxis.VERTICAL:
			return Input.CURSOR_VSIZE
		_:
			return Input.CURSOR_FDIAGSIZE


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


## Resizes the panel while keeping it inside the viewport and above the
## minimum size its content needs. Axes not in `resize_axis` keep their size.
func _set_clamped_size(new_size: Vector2) -> void:
	var viewport := get_viewport_rect().size
	var min_size := get_combined_minimum_size()
	var max_size := Vector2(
		maxf(viewport.x - global_position.x, min_size.x), maxf(viewport.y - global_position.y, min_size.y)
	)
	var target := size
	if _has_axis(ResizeAxis.HORIZONTAL):
		target.x = clampf(new_size.x, min_size.x, max_size.x)
	if _has_axis(ResizeAxis.VERTICAL):
		target.y = clampf(new_size.y, min_size.y, max_size.y)
	size = target
	queue_redraw()


## Draws the resize grip in the bottom-right corner.
func _draw() -> void:
	if resize_axis == ResizeAxis.NONE:
		return

	var corner := size - Vector2(GRIP_INSET, GRIP_INSET)
	for i in GRIP_LINES:
		var line_length := GRIP_LINE_LENGTH + i * GRIP_LINE_SPACING
		draw_line(corner - Vector2(line_length, 0.0), corner - Vector2(0.0, line_length), GRIP_COLOR)
