extends TouchItemList
class_name LevelItemList

## Grid of level thumbnails that streams the visible ones to a
## `ThumbnailGenerator`.

## Generator that renders the thumbnails.
@export var thumbnail_generator: ThumbnailGenerator

## Placeholder icon shown until a level thumbnail is generated.
@export var preview_placeholder: GradientTexture2D

## Minimum width of a level thumbnail, in pixels.
@export var level_item_min_width: int = 120

## Background color of unsolved levels.
@export var unsolved_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Background color of solved levels.
@export var solved_color: Color = Color(0.18, 0.44, 0.18, 0.5)
## Background color of levels with a saved in-progress solution.
@export var solving_color: Color = Color(0.44, 0.35, 0.10, 0.5)

var _levels: Array[Dictionary] = []
var _generated_previews: Array[int] = []

var _start_item_index: int
var _end_item_index: int


func _ready() -> void:
	super()
	resized.connect(_on_resized)
	thumbnail_generator.thumbnail_generated.connect(_on_preview_generated)


## Populates the list with the given levels and resets the thumbnail cache.
func set_levels(levels: Array[Dictionary]) -> void:
	get_v_scroll_bar().value = 0
	clear()

	_levels = levels
	_generated_previews.clear()

	_start_item_index = -1
	_end_item_index = -1

	thumbnail_generator.set_levels(_levels)

	for idx in range(_levels.size()):
		var label = str(idx + 1)
		add_item(label, preview_placeholder, true)

		var data := _levels[idx]
		var tooltip := _make_tooltip(data)
		if tooltip.is_empty():
			set_item_tooltip_enabled(idx, false)
		else:
			set_item_tooltip(idx, tooltip)

		if data.get("solved"):
			set_item_custom_bg_color(idx, solved_color)
		elif data.get("solving"):
			set_item_custom_bg_color(idx, solving_color)
		else:
			set_item_custom_bg_color(idx, unsolved_color)


## Returns the database id of the level at the given index.
func get_level_id(index: int) -> int:
	return _levels[index]["id"]


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


func _process(_delta: float):
	var style_box = get_theme_stylebox("panel")
	var start = get_item_at_position(Vector2(style_box.get_margin(SIDE_LEFT), style_box.get_margin(SIDE_TOP)), true)
	var end = get_item_at_position(size - Vector2(style_box.get_margin(SIDE_RIGHT), style_box.get_margin(SIDE_BOTTOM) + 1.0), true)

	if start == -1:
		# No items are visible
		return
	if end == -1:
		end = get_item_count() - 1
	if start == _start_item_index and end == _end_item_index:
		return
	_start_item_index = start
	_end_item_index = end

	var cache_items = max_columns * 2

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
			set_item_icon(idx, preview_placeholder)


func _on_preview_generated(index: int, texture: Texture2D):
	assert(not _generated_previews.has(index))
	_generated_previews.append(index)
	set_item_icon(index, texture)


func _on_resized():
	var content_width := _get_content_width()
	var h_separation := get_theme_constant("h_separation")

	var items_per_row := maxi(int(content_width / level_item_min_width), 1)
	var item_width := int(content_width / items_per_row - h_separation)

	max_columns = items_per_row
	set_fixed_column_width(item_width)
	set_fixed_icon_size(Vector2(item_width, item_width))
	preview_placeholder.width = item_width
	preview_placeholder.height = item_width


## Returns the usable width of the list, excluding margins and scrollbar.
func _get_content_width() -> float:
	var width = size.x

	# Subtract left and right margins
	var style_box = get_theme_stylebox("panel")
	if style_box:
		width -= style_box.get_margin(SIDE_LEFT) + style_box.get_margin(SIDE_RIGHT)

	# Subtract scrollbar width
	var v_scroll_bar = get_v_scroll_bar()
	width -= v_scroll_bar.size.x

	return width
