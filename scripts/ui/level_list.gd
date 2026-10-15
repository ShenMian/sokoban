extends Control

## Identifiers of the collection context menu items.
enum CollectionMenuId {
	DELETE,
}

## Identifiers of the level context menu items.
enum LevelMenuId {
	DELETE,
}

## Identifiers of the more menu items.
enum MoreMenuId {
	IMPORT_FROM_FILE,
	IMPORT_FROM_CLIPBOARD,
}

@onready var collection_list: ItemList = $Margin/VBox/HSplit/CollectionList
@onready var level_list: ItemList = $Margin/VBox/HSplit/LevelList
@onready var thumbnail_generator: ThumbnailGenerator = $ThumbnailGenerator

@onready var collection_menu: PopupMenu = $CollectionMenu
@onready var level_menu: PopupMenu = $LevelMenu
@onready var delete_collection_dialog: ConfirmDialog = $DeleteCollectionDialog
@onready var delete_level_dialog: ConfirmDialog = $DeleteLevelDialog

@onready var more_button: ButtonFx = $Margin/VBox/TitleBar/MoreButton
@onready var more_menu: PopupMenu = $MoreMenu
@onready var import_file_dialog: FileDialog = $ImportFileDialog

## Minimum width of a level thumbnail, in pixels.
@export var level_item_min_width: int = 120

## Background color of unsolved levels.
@export var unsolved_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Background color of solved levels.
@export var solved_color: Color = Color(0.18, 0.44, 0.18, 0.5)
## Background color of levels with a saved in-progress solution.
@export var solving_color: Color = Color(0.44, 0.35, 0.10, 0.5)

## Placeholder icon shown until a level thumbnail is generated.
@export var preview_placeholder: GradientTexture2D

var _start_item_index: int
var _end_item_index: int

var _levels: Array[Dictionary] = []
var _generated_previews: Array[int] = []

var _selected_collection: String

## Index of the level the context menu was opened on, or -1 if there is none.
var _menu_level_index: int = -1

var _is_touch_scrolling: bool
var _scroll_touch_index: int = -1


func _ready():
	get_window().files_dropped.connect(_on_files_dropped)

	more_button.pressed.connect(_on_more_pressed)
	more_menu.id_pressed.connect(_on_more_menu_id_pressed)
	import_file_dialog.file_selected.connect(_on_import_file_selected)

	collection_list.item_selected.connect(_on_collection_item_selected)
	collection_list.item_clicked.connect(_on_collection_item_clicked)
	level_list.gui_input.connect(_on_level_list_gui_input)
	level_list.item_clicked.connect(_on_level_item_clicked)
	level_list.resized.connect(_on_level_list_resized)

	collection_menu.id_pressed.connect(_on_collection_menu_id_pressed)
	level_menu.id_pressed.connect(_on_level_menu_id_pressed)
	delete_collection_dialog.confirmed.connect(_delete_collection)
	delete_level_dialog.confirmed.connect(_delete_level)

	thumbnail_generator.thumbnail_generated.connect(_on_preview_generated)

	Database.open("user://database.db")
	if Database.is_empty():
		Database.import_levels_from_dir("res://assets/levels/")

	_load_collections()

	# Select the first or previously selected collection
	if collection_list.item_count == 0:
		return
	var collection_idx = 0 if SceneTransition.collection_name == "" else _get_collection_index(SceneTransition.collection_name)
	collection_list.select(collection_idx)
	_on_collection_item_selected(collection_idx)

	# Select the first or previously selected level
	if level_list.item_count == 0:
		return
	var level_idx := 0 if SceneTransition.level_index == -1 else SceneTransition.level_index - 1
	level_list.select(level_idx)
	level_list.ensure_current_is_visible()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		_import_from_clipboard()


func _on_files_dropped(files: PackedStringArray):
	for path in files:
		if DirAccess.dir_exists_absolute(path):
			Database.import_levels_from_dir(path)
		elif FileAccess.file_exists(path):
			Database.import_levels_from_file(path)
	_load_collections()


## Opens the more menu below the more button.
func _on_more_pressed() -> void:
	more_menu.position = Vector2i(more_button.global_position + Vector2(0, more_button.size.y))
	more_menu.reset_size()
	more_menu.popup()


func _on_more_menu_id_pressed(id: int) -> void:
	match id:
		MoreMenuId.IMPORT_FROM_FILE:
			import_file_dialog.popup_file_dialog()
		MoreMenuId.IMPORT_FROM_CLIPBOARD:
			_import_from_clipboard()


## Imports the selected file into a collection named after the file.
func _on_import_file_selected(path: String) -> void:
	Database.import_levels_from_file(path)
	_load_collections()


## Imports a level or a solution from the clipboard.
func _import_from_clipboard() -> void:
	var content := DisplayServer.clipboard_get()
	Database.import_level_from_string(content, "Imported")
	Database.import_levels_from_string(content, "Imported")
	_load_collections()


## Populates the collection list from the database.
func _load_collections():
	collection_list.clear()
	for collection in Database.get_collections():
		var idx = collection_list.add_item(collection["name"])
		collection_list.set_item_tooltip(idx, collection.get("description", ""))

	# Keeps the previously selected collection selected, if it still exists.
	var selected := _get_collection_index(_selected_collection)
	if selected != -1:
		collection_list.select(selected)


## Returns the index of the given collection in the list, or -1 if it is absent.
func _get_collection_index(collection_name: String) -> int:
	for idx in collection_list.item_count:
		if collection_list.get_item_text(idx) == collection_name:
			return idx
	return -1


func _process(_delta: float):
	var style_box = level_list.get_theme_stylebox("panel")
	var start = level_list.get_item_at_position(Vector2(style_box.get_margin(SIDE_LEFT), style_box.get_margin(SIDE_TOP)), true)
	var end = level_list.get_item_at_position(level_list.size - Vector2(style_box.get_margin(SIDE_RIGHT), style_box.get_margin(SIDE_BOTTOM) + 1.0), true)

	if start == -1:
		# No items are visible
		return
	if end == -1:
		end = level_list.get_item_count() - 1
	if start == _start_item_index and end == _end_item_index:
		return
	_start_item_index = start
	_end_item_index = end

	var cache_items = level_list.max_columns * 2

	# Submits preview rendering tasks
	var queue: Array[int] = []
	for i in range(start - cache_items, end + cache_items + 1):
		if i >= 0 and i < _levels.size():
			if not _generated_previews.has(i):
				queue.append(i)
	thumbnail_generator.submit_queue(queue)

	# Frees distant preview textures
	for i in range(_generated_previews.size() - 1, -1, -1):
		var idx: int = _generated_previews[i]
		if idx < start - cache_items or idx > end + cache_items:
			_generated_previews.remove_at(i)
			level_list.set_item_icon(idx, preview_placeholder)


func _on_preview_generated(index: int, texture: Texture2D):
	assert(not _generated_previews.has(index))
	_generated_previews.append(index)
	level_list.set_item_icon(index, texture)


func _on_collection_item_selected(index: int):
	var collection_name := collection_list.get_item_text(index)
	if collection_name == _selected_collection:
		return
	_selected_collection = collection_name
	_load_levels()


## Opens the collection context menu at the given list local position.
func _open_collection_menu(pos: Vector2) -> void:
	collection_menu.position = Vector2i(collection_list.get_global_position() + pos)
	collection_menu.reset_size()
	collection_menu.popup()


func _on_collection_menu_id_pressed(id: int) -> void:
	if id == CollectionMenuId.DELETE:
		delete_collection_dialog.confirm_button.theme_type_variation = &"DangerButton"
		delete_collection_dialog.open(tr("DELETE_COLLECTION_CONFIRM") % _selected_collection)


func _delete_collection() -> void:
	var index := _get_collection_index(_selected_collection)

	Database.delete_collection(_selected_collection)
	_selected_collection = ""
	_load_collections()

	if collection_list.item_count == 0:
		# No collection is left to display.
		_load_levels()
	else:
		# Selects the closest remaining collection.
		var closest := mini(index, collection_list.item_count - 1)
		collection_list.select(closest)
		_on_collection_item_selected(closest)


## Populates the level list for the selected collection.
func _load_levels():
	level_list.get_v_scroll_bar().value = 0
	level_list.clear()

	_levels.clear()
	_generated_previews.clear()

	_start_item_index = -1
	_end_item_index = -1

	_levels = Database.get_collection_levels(_selected_collection)
	thumbnail_generator.set_levels(_levels)

	for idx in range(_levels.size()):
		var label = str(idx + 1)
		level_list.add_item(label, preview_placeholder, true)

		var data := _levels[idx]
		var tooltip := _make_tooltip(data)
		if tooltip.is_empty():
			level_list.set_item_tooltip_enabled(idx, false)
		else:
			level_list.set_item_tooltip(idx, tooltip)

		if data.get("solved"):
			level_list.set_item_custom_bg_color(idx, solved_color)
		elif data.get("solving"):
			level_list.set_item_custom_bg_color(idx, solving_color)
		else:
			level_list.set_item_custom_bg_color(idx, unsolved_color)


## Builds the tooltip text shown for a level.
func _make_tooltip(data: Dictionary) -> String:
	var lines := PackedStringArray()
	for key: String in ["title", "author"]:
		if data.has(key):
			lines.append("%s: %s" % [key.capitalize(), data[key]])
	if data.has("comments"):
		var comment: String = data["comments"]
		if comment.length() > 100:
			comment = comment.left(100 - 1) + "…"
		lines.append("")
		lines.append(comment)
	return "\n".join(lines)


## Opens the context menu when a collection is right-clicked. Selecting is left
## to the `item_selected` signal, which the engine also emits for right clicks.
func _on_collection_item_clicked(_index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_open_collection_menu(at_position)


## Opens the context menu when a level is right-clicked.
func _on_level_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_open_level_menu(index, at_position)


## Opens the level context menu at the given list local position.
func _open_level_menu(index: int, pos: Vector2) -> void:
	_menu_level_index = index
	level_menu.position = Vector2i(level_list.get_global_position() + pos)
	level_menu.reset_size()
	level_menu.popup()


func _on_level_menu_id_pressed(id: int) -> void:
	if id == LevelMenuId.DELETE:
		delete_level_dialog.confirm_button.theme_type_variation = &"DangerButton"
		delete_level_dialog.open(tr("DELETE_LEVEL_CONFIRM") % (_menu_level_index + 1))


func _delete_level() -> void:
	if _menu_level_index == -1:
		return

	var level_id: int = _levels[_menu_level_index]["id"]
	var scroll_value := level_list.get_v_scroll_bar().value

	Database.delete_level(_selected_collection, level_id)
	_load_levels()

	# Keeps the viewport in place
	level_list.get_v_scroll_bar().value = scroll_value

	_menu_level_index = -1


func _on_level_list_gui_input(event: InputEvent):
	_handle_list_input(level_list, event, _on_level_clicked)


## Handles mouse and touch clicks on an item list.
func _handle_list_input(list: ItemList, input_event: InputEvent, item_click_callback: Callable):
	if input_event is InputEventMouseButton:
		var event := input_event as InputEventMouseButton
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var item_idx = list.get_item_at_position(event.position, true)
		if item_idx == -1:
			return
		item_click_callback.call(item_idx)
	elif input_event is InputEventScreenTouch:
		var event := input_event as InputEventScreenTouch
		if event.pressed:
			_scroll_touch_index = event.index
			_is_touch_scrolling = false
		elif not _is_touch_scrolling:
			if event.index != _scroll_touch_index:
				return
			var item_idx = list.get_item_at_position(event.position, true)
			if item_idx == -1:
				return
			item_click_callback.call(item_idx)
			_scroll_touch_index = -1
	elif input_event is InputEventScreenDrag:
		var event := input_event as InputEventScreenDrag
		if event.index != _scroll_touch_index:
			return
		list.get_v_scroll_bar().value -= event.relative.y
		_is_touch_scrolling = true


func _on_level_clicked(index: int):
	SceneTransition.load_level(_selected_collection, index + 1)


func _on_level_list_resized():
	var content_width := _get_content_width(level_list)
	var h_separation := level_list.get_theme_constant("h_separation")

	var items_per_row := maxi(int(content_width / level_item_min_width), 1)
	var item_width := int(content_width / items_per_row - h_separation)

	level_list.max_columns = items_per_row
	level_list.set_fixed_column_width(item_width)
	level_list.set_fixed_icon_size(Vector2(item_width, item_width))
	preview_placeholder.width = item_width
	preview_placeholder.height = item_width


## Returns the usable width of an item list, excluding margins and scrollbar.
func _get_content_width(item_list: ItemList) -> float:
	var width = item_list.size.x

	# Subtract left and right margins
	var style_box = item_list.get_theme_stylebox("panel")
	if style_box:
		width -= style_box.get_margin(SIDE_LEFT) + style_box.get_margin(SIDE_RIGHT)

	# Subtract scrollbar width
	var v_scroll_bar = item_list.get_v_scroll_bar()
	width -= v_scroll_bar.size.x

	return width
