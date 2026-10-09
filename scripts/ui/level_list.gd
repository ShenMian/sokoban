extends Control

@onready var collection_list: ItemList = $Margin/VBox/HSplit/CollectionList
@onready var level_list: ItemList = $Margin/VBox/HSplit/LevelList
@onready var thumbnail_generator: ThumbnailGenerator = $ThumbnailGenerator

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

var _is_touch_scrolling: bool
var _scroll_touch_index: int = -1


func _ready():
	get_window().files_dropped.connect(_on_files_dropped)

	collection_list.gui_input.connect(_on_collection_list_gui_input)
	level_list.gui_input.connect(_on_level_list_gui_input)
	level_list.resized.connect(_on_level_list_resized)

	thumbnail_generator.thumbnail_generated.connect(_on_preview_generated)

	Database.open("user://database.db")
	if Database.is_empty():
		Database.import_levels_from_dir("res://assets/levels/")

	_load_collections()
	assert(collection_list.item_count > 0)

	if SceneTransition.collection_name == "":
		collection_list.select(0)
		_on_collection_list_clicked(0)
	else:
		# Select the previous collection and level
		var collection_index := 0
		for idx in collection_list.item_count:
			if collection_list.get_item_text(idx) == SceneTransition.collection_name:
				collection_index = idx
				break
		_on_collection_list_clicked(collection_index)
		level_list.select(SceneTransition.level_index - 1)
		level_list.ensure_current_is_visible()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("import_from_clipboard"):
		var content := DisplayServer.clipboard_get()
		Database.import_level_from_string(content, "Imported")
		Database.import_levels_from_string(content, "Imported")
		_load_collections()


func _on_files_dropped(files: PackedStringArray):
	for path in files:
		if DirAccess.dir_exists_absolute(path):
			Database.import_levels_from_dir(path)
		elif FileAccess.file_exists(path):
			Database.import_levels_from_file(path)
	_load_collections()


## Populates the collection list from the database.
func _load_collections():
	collection_list.clear()
	for collection in Database.get_collections():
		var idx = collection_list.add_item(collection["name"])
		collection_list.set_item_tooltip(idx, collection.get("description", ""))


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


func _on_collection_list_clicked(index: int):
	var collection_name := collection_list.get_item_text(index)
	if collection_name == _selected_collection:
		return
	_selected_collection = collection_name
	_load_levels()


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

		var tooltip := _make_tooltip(_levels[idx])
		if tooltip.is_empty():
			level_list.set_item_tooltip_enabled(idx, false)
		else:
			level_list.set_item_tooltip(idx, tooltip)

		if _levels[idx].get("solved"):
			level_list.set_item_custom_bg_color(idx, solved_color)
		elif _levels[idx].get("solving"):
			level_list.set_item_custom_bg_color(idx, solving_color)
		else:
			level_list.set_item_custom_bg_color(idx, unsolved_color)


## Builds the tooltip text shown for a level.
func _make_tooltip(data: Dictionary) -> String:
	var lines := PackedStringArray()
	for key: String in data.keys():
		if key in ["title", "author"]:
			lines.append("%s: %s" % [key.capitalize(), data[key]])
	if data.has("comments"):
		var comment: String = data["comments"]
		if comment.length() > 100:
			comment = comment.left(100 - 1) + "…"
		lines.append("")
		lines.append(comment)
	return "\n".join(lines)


func _on_collection_list_gui_input(event: InputEvent):
	_handle_list_input(collection_list, event, _on_collection_list_clicked)


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

	var items_per_row := int(content_width / level_item_min_width)
	assert(items_per_row > 0)
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
