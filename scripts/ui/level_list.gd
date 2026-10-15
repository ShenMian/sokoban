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

## Collection that imported levels go into when the source has no usable name.
const IMPORTED_COLLECTION := "Imported"

@onready var collection_list: ItemList = $Margin/VBox/HSplit/CollectionList
@onready var level_list: LevelItemList = $Margin/VBox/HSplit/LevelList

@onready var collection_menu: PopupMenu = $CollectionMenu
@onready var level_menu: PopupMenu = $LevelMenu
@onready var delete_collection_dialog: ConfirmDialog = $DeleteCollectionDialog
@onready var delete_level_dialog: ConfirmDialog = $DeleteLevelDialog

@onready var more_button: ButtonFx = $Margin/VBox/TitleBar/MoreButton
@onready var more_menu: PopupMenu = $MoreMenu
@onready var import_file_dialog: FileDialog = $ImportFileDialog

var _selected_collection: String

## Index of the level the context menu was opened on, or -1 if there is none.
var _menu_level_index: int = -1


func _ready():
	get_window().files_dropped.connect(_on_files_dropped)

	more_button.pressed.connect(_on_more_pressed)
	more_menu.id_pressed.connect(_on_more_menu_id_pressed)
	import_file_dialog.file_selected.connect(_on_import_file_selected)

	collection_list.item_selected.connect(_on_collection_item_selected)
	collection_list.item_clicked.connect(_on_collection_item_clicked)
	collection_list.item_long_pressed.connect(_on_collection_item_long_pressed)
	level_list.item_tapped.connect(_on_level_tapped)
	level_list.item_clicked.connect(_on_level_item_clicked)
	level_list.item_long_pressed.connect(_on_level_item_long_pressed)

	collection_menu.id_pressed.connect(_on_collection_menu_id_pressed)
	level_menu.id_pressed.connect(_on_level_menu_id_pressed)
	delete_collection_dialog.confirmed.connect(_delete_collection)
	delete_level_dialog.confirmed.connect(_delete_level)

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
	var content := FileAccess.get_file_as_string(path)
	if content.is_empty():
		push_warning("failed to read the file: %s (%s)" % [
			path,
			error_string(FileAccess.get_open_error())
		])
		return

	# Android file pickers return content URIs. Some providers percent-encode the file path in the
	# last segment, so decode it before taking the name
	var decoded := path.get_file().uri_decode()
	var collection_name := decoded.get_file().get_basename()
	if collection_name.is_empty():
		collection_name = IMPORTED_COLLECTION

	Database.import_levels_from_string(content, collection_name)
	_load_collections()


## Imports a level or a solution from the clipboard.
func _import_from_clipboard() -> void:
	var content := DisplayServer.clipboard_get()
	Database.import_level_from_string(content, IMPORTED_COLLECTION)
	Database.import_levels_from_string(content, IMPORTED_COLLECTION)
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


func _on_collection_item_selected(index: int):
	var collection_name := collection_list.get_item_text(index)
	if collection_name == _selected_collection:
		return
	_selected_collection = collection_name
	_load_levels()


## Opens the context menu when a collection is right-clicked. Selecting is left
## to the `item_selected` signal, which the engine also emits for right clicks.
func _on_collection_item_clicked(_index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_open_collection_menu(at_position)


## Opens the context menu when a collection is long-pressed on a touchscreen.
func _on_collection_item_long_pressed(_index: int, at_position: Vector2) -> void:
	_open_collection_menu(at_position)


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
	level_list.set_levels(Database.get_collection_levels(_selected_collection))


## Opens the context menu when a level is right-clicked.
func _on_level_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_open_level_menu(index, at_position)


## Opens the context menu when a level is long-pressed on a touchscreen.
func _on_level_item_long_pressed(index: int, at_position: Vector2) -> void:
	_open_level_menu(index, at_position)


func _on_level_tapped(index: int):
	SceneTransition.load_level(_selected_collection, index + 1)


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

	var level_id: int = level_list.get_level_id(_menu_level_index)
	var scroll_value := level_list.get_v_scroll_bar().value

	Database.delete_level(_selected_collection, level_id)
	_load_levels()

	# Keeps the viewport in place
	level_list.get_v_scroll_bar().value = scroll_value

	_menu_level_index = -1
