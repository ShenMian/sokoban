extends ItemList
class_name TouchItemList

## Emitted when an item is clicked with the mouse or tapped on a touchscreen.
signal item_tapped(index: int)

var _is_touch_scrolling: bool
var _scroll_touch_index: int = -1


func _ready() -> void:
	gui_input.connect(_on_gui_input)


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
			_scroll_touch_index = event.index
			_is_touch_scrolling = false
		elif not _is_touch_scrolling:
			if event.index != _scroll_touch_index:
				return
			var item_idx = get_item_at_position(event.position, true)
			if item_idx == -1:
				return
			item_tapped.emit(item_idx)
			_scroll_touch_index = -1
	elif input_event is InputEventScreenDrag:
		var event := input_event as InputEventScreenDrag
		if event.index != _scroll_touch_index:
			return
		get_v_scroll_bar().value -= event.relative.y
		_is_touch_scrolling = true
