extends ItemList
class_name TouchItemList

## Emitted when an item is clicked with the mouse or tapped on a touchscreen.
signal item_tapped(index: int)
## Emitted when an item is pressed and held on a touchscreen.
signal item_long_pressed(index: int, at_position: Vector2)

## Seconds a touch has to stay down on an item before it opens its context menu.
@export var long_press_duration: float = 0.5
## Distance in pixels a touch may travel before it counts as a drag.
@export var drag_deadzone: float = 16.0

var _touch_index: int = -1
var _touch_position: Vector2
var _is_touch_scrolling: bool

var _long_press_index: int = -1
var _long_press_triggered: bool
var _long_press_timer: Timer


func _ready() -> void:
	gui_input.connect(_on_gui_input)

	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)


## Handles mouse and touch clicks on the list.
func _on_gui_input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseButton:
		var event := input_event as InputEventMouseButton
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var item_idx = get_item_at_position(event.position, true)
		if item_idx == -1:
			return
		item_tapped.emit(item_idx)
	elif input_event is InputEventScreenTouch:
		var event := input_event as InputEventScreenTouch
		if event.pressed:
			_begin_touch(event)
		elif event.index == _touch_index:
			_end_touch(event)
	elif input_event is InputEventScreenDrag:
		var event := input_event as InputEventScreenDrag
		if event.index != _touch_index:
			return
		if event.position.distance_to(_touch_position) > drag_deadzone:
			_is_touch_scrolling = true
			_long_press_timer.stop()
		get_v_scroll_bar().value -= event.relative.y


## Starts tracking a touch and arms the long press when it lands on an item.
func _begin_touch(event: InputEventScreenTouch) -> void:
	_touch_index = event.index
	_touch_position = event.position
	_is_touch_scrolling = false
	_long_press_triggered = false
	_long_press_index = get_item_at_position(event.position, true)

	_long_press_timer.stop()
	if _long_press_index != -1:
		_long_press_timer.start(long_press_duration)


## Emits `item_tapped` unless the touch scrolled, was cancelled, or already
## opened the context menu.
func _end_touch(event: InputEventScreenTouch) -> void:
	_long_press_timer.stop()
	_touch_index = -1

	if _long_press_triggered or _is_touch_scrolling or event.canceled:
		return

	var item_idx = get_item_at_position(event.position, true)
	if item_idx == -1:
		return
	item_tapped.emit(item_idx)


## Opens the context menu of the item that was held down.
func _on_long_press_timeout() -> void:
	if _is_touch_scrolling:
		return

	_long_press_triggered = true
	Input.vibrate_handheld(50)
	item_long_pressed.emit(_long_press_index, _touch_position)
