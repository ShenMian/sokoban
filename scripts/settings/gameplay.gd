extends ScrollContainer

@onready var language: OptionButton = $VBox/LanguagePanel/HBox/OptionButton
@onready var animation_speed: OptionButton = $VBox/AnimationSpeedPanel/HBox/OptionButton
@onready var pathfinding_strategy: OptionButton = $VBox/PathfindingStrategyPanel/HBox/OptionButton
@onready var map_theme: OptionButton = $VBox/ThemePanel/HBox/OptionButton
@onready var view_2d: SwitchFx = $"VBox/2dViewPanel/HBox/CheckButton"
@onready var checkerboard: SwitchFx = $VBox/CheckerboardPanel/HBox/CheckButton

const SECTION_NAME := "gameplay"
const LOCALES: Array[String] = ["en", "zh"]


func _ready() -> void:
	language.item_selected.connect(_on_language_selected)
	animation_speed.item_selected.connect(_on_animation_speed_selected)
	view_2d.toggled.connect(_on_2d_view_toggled)
	checkerboard.toggled.connect(_on_checkerboard_toggled)
	pathfinding_strategy.item_selected.connect(_on_pathfinding_strategy_selected)
	map_theme.item_selected.connect(_on_theme_selected)

	apply_settings()


func apply_settings() -> void:
	language.select(LOCALES.find(Settings.get_value(SECTION_NAME, "language")))
	language.item_selected.emit(language.selected)

	animation_speed.select(Settings.get_value(SECTION_NAME, "animation_speed"))
	animation_speed.item_selected.emit(animation_speed.selected)

	pathfinding_strategy.select(Settings.get_value(SECTION_NAME, "pathfinding_strategy"))
	pathfinding_strategy.item_selected.emit(pathfinding_strategy.selected)

	map_theme.select(Settings.get_value(SECTION_NAME, "theme"))
	map_theme.item_selected.emit(map_theme.selected)

	view_2d.button_pressed = Settings.get_value(SECTION_NAME, "2d_view")
	view_2d.toggled.emit(view_2d.button_pressed)

	checkerboard.button_pressed = Settings.get_value(SECTION_NAME, "checkerboard")
	checkerboard.toggled.emit(checkerboard.button_pressed)


func _on_language_selected(index: int) -> void:
	var locale := LOCALES[index]
	TranslationServer.set_locale(locale)
	Settings.set_and_save_value(SECTION_NAME, "language", locale)


func _on_animation_speed_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "animation_speed", index)


func _on_pathfinding_strategy_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "pathfinding_strategy", index)


func _on_theme_selected(index: int) -> void:
	Settings.set_and_save_value(SECTION_NAME, "theme", index)


func _on_2d_view_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "2d_view", toggled_on)


func _on_checkerboard_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "checkerboard", toggled_on)
