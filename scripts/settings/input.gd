extends ScrollContainer

@onready var binding_popup: BindingPopup = $"../../../../../BindingPopup"

@onready var action_buttons := {
	"move_up": $VBox/GridContainer/UpButton,
	"move_down": $VBox/GridContainer/DownButton,
	"move_left": $VBox/GridContainer/LeftButton,
	"move_right": $VBox/GridContainer/RightButton,
	"undo": $VBox/GridContainer/UndoButton,
	"redo": $VBox/GridContainer/RedoButton,
	"undo_all": $VBox/GridContainer/UndoAllButton,
	"solve": $VBox/GridContainer/SolveButton,
	"import_from_clipboard": $VBox/GridContainer/ImportFromClipboardButton,
	"export_to_clipboard": $VBox/GridContainer/ExportToClipboardButton,
}


func _ready() -> void:
	apply_settings()

	for action in action_buttons:
		action_buttons[action].pressed.connect(_on_button_pressed.bind(action))

	binding_popup.closed.connect(_on_binding_popup_closed)


func _on_binding_popup_closed() -> void:
	apply_settings()
	Settings.save_bindings()


func apply_settings() -> void:
	for action in action_buttons:
		var button: Button = action_buttons[action]
		var event := _get_event_by_action(action)
		_update_button_icons(button, _get_icons_by_event(event))


func _on_button_pressed(action: StringName) -> void:
	binding_popup.open(action)


func _get_event_by_action(action: StringName) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func _update_button_icons(button: Button, icons: Array[Texture2D]) -> void:
	var icon_container := button.get_node("HBox")
	for child in icon_container.get_children():
		child.queue_free()

	for icon in icons:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
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
