extends Control
class_name BindingPopup

signal closed

@onready var title_label: Label = $VBox/TitleLabel
@onready var icon_container: HBoxContainer = $VBox/HBox
@onready var hint_label: Label = $VBox/HintLabel

@onready var cancel_button: ButtonFx = $VBox/ColorRect/HBox/CancelButton
@onready var clear_button: ButtonFx = $VBox/ColorRect/HBox/ClearButton
@onready var confirm_button: ButtonFx = $VBox/ColorRect/HBox/ConfirmButton

@onready var cancel_hint_button: ButtonFx = $CancelButton

var _action: StringName
var _new_event: InputEvent = null


func open(action: StringName) -> void:
	_action = action
	title_label.text = tr(action.to_upper())
	_update_icons(_get_icons_by_event(_get_event_by_action(action)))

	show()
	set_process_input(true)


func close() -> void:
	hide()
	closed.emit()

	# Reset state for next opening
	_reset_conflict_hint()
	_new_event = null


func _ready() -> void:
	set_process_input(false)

	cancel_button.pressed.connect(close)
	cancel_hint_button.pressed.connect(close)

	clear_button.pressed.connect(_on_clear_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


func _on_clear_pressed() -> void:
	_update_icons([])
	_new_event = null
	_reset_conflict_hint()


func _on_confirm_pressed() -> void:
	InputMap.action_erase_events(_action)
	if _new_event != null:
		InputMap.action_add_event(_action, _new_event)
	close()


func _input(event: InputEvent) -> void:
	if event.is_released():
		return

	if event is InputEventKey and event.pressed:
		_new_event = event as InputEventKey
		_update_icons(_get_icons_by_event(_new_event))
		_check_conflict(_new_event)


func _check_conflict(event: InputEventKey) -> void:
	var action := _get_action_by_event(event)
	if action.is_empty():
		# No conflict with other actions' events
		hint_label.text = ""
		confirm_button.disabled = false
	elif action == _action:
		# Same event already assigned to this action
		hint_label.text = tr("KEY_UNCHANGED")
		confirm_button.disabled = true
	else:
		# Event conflicts with another action
		hint_label.text = tr("KEY_CONFLICT") % tr(action.to_upper())
		confirm_button.disabled = true


func _reset_conflict_hint() -> void:
	hint_label.text = ""
	confirm_button.disabled = true


func _get_event_by_action(action: StringName) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _get_action_by_event(event: InputEventKey) -> StringName:
	for action in InputMap.get_actions():
		if action.begins_with("ui_"):
			continue
		for other in InputMap.action_get_events(action):
			if other is InputEventKey and _events_match(event, other as InputEventKey):
				return action
	return &""


func _events_match(a: InputEventKey, b: InputEventKey) -> bool:
	return a.physical_keycode == b.physical_keycode \
		and a.ctrl_pressed == b.ctrl_pressed \
		and a.shift_pressed == b.shift_pressed \
		and a.alt_pressed == b.alt_pressed \
		and a.meta_pressed == b.meta_pressed


func _update_icons(icons: Array[Texture2D]) -> void:
	for child in icon_container.get_children():
		child.queue_free()

	for icon in icons:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon_container.add_child(rect)


func _get_icons_by_event(event: InputEventKey) -> Array[Texture2D]:
	var icons: Array[Texture2D] = []

	if event.ctrl_pressed:
		icons.append(_get_icon_by_key_name("control"))
	if event.shift_pressed:
		icons.append(_get_icon_by_key_name("shift"))
	if event.alt_pressed:
		icons.append(_get_icon_by_key_name("alt"))
	if event.meta_pressed:
		icons.append(_get_icon_by_key_name("meta"))

	var key_name := OS.get_keycode_string(event.physical_keycode)
	icons.append(_get_icon_by_key_name(key_name.to_lower()))

	return icons


func _get_icon_by_key_name(key: String) -> Texture2D:
	assert(key == key.to_lower())

	if key.is_empty():
		return null

	match key:
		"up":
			key = "arrow_up"
		"down":
			key = "arrow_down"
		"left":
			key = "arrow_left"
		"right":
			key = "arrow_right"
		"control":
			key = "ctrl"
		"meta":
			key = "win"

	const ICON_PATH := "res://assets/textures/input_prompts/keyboard_mouse/"
	var path := ICON_PATH + "keyboard_%s.svg" % key
	return load(path) as Texture2D
