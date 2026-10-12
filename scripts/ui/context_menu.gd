class_name ContextMenu
extends PopupMenu


func _ready() -> void:
	window_input.connect(_on_window_input)


## Closes on clicks outside the popup and forwards them to the viewport underneath.
func _on_window_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var button_event := event as InputEventMouseButton
	if not button_event.pressed:
		return
	if button_event.button_index != MOUSE_BUTTON_LEFT and button_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	# Outside clicks are forwarded below; inside ones are left to the popup.
	if Rect2(Vector2.ZERO, Vector2(size)).has_point(button_event.position):
		return

	var forwarded := InputEventMouseButton.new()
	forwarded.button_index = button_event.button_index
	forwarded.pressed = true
	forwarded.device = button_event.device
	forwarded.position = button_event.position + Vector2(position)
	forwarded.global_position = forwarded.position

	hide()
	set_input_as_handled()
	get_parent().get_viewport().push_input.call_deferred(forwarded, true)
