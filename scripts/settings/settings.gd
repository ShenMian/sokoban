extends Node

signal setting_changed(section: String, key: String, value: Variant)

const CONFIG_PATH = "user://settings.ini"
const BINDINGS_PATH = "user://bindings.ini"

const LEVEL_PATH = "res://assets/levels/"

var _default_config = {
	"gameplay": {
		"language": "en",
		"animation_speed": E.AnimationSpeed.NORMAL,
		"pathfinding_strategy": E.Strategy.PUSH_OPTIMAL,
		"theme": 0,
		"2d_view": false,
		"checkerboard": true,
	},
	"assists": {
		"deadlock_hint": true,
		"pushable_hint": true,
		"algorithm": E.Algorithm.A_STAR,
		"solver_strategy": E.Strategy.QUICK,
		"lower_bounds": false,
		"tunnels": false,
	},
	"video": {
		"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
		"vsync": DisplayServer.VSYNC_ENABLED,
		"frame_rate_limit": 0,
		"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR,
		"scaling_3d_scale": 1.0,
		"fsr_sharpness": 0.2,
		"fov": 60.0,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
		"msaa": Viewport.MSAA_DISABLED,
		"taa": false,
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"mute_on_unfocused": true,
	},
}

var _config := ConfigFile.new()
var _bindings := ConfigFile.new()


func _ready() -> void:
	get_window().size_changed.connect(_on_window_size_changed)

	print("User path: ", ProjectSettings.globalize_path("user://"))

	var locale := OS.get_locale_language()
	if locale in TranslationServer.get_loaded_locales():
		_default_config["gameplay"]["language"] = locale

	if OS.has_feature("mobile"):
		_default_config["video"]["window_mode"] = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

	var config_status := _config.load(CONFIG_PATH)
	if config_status or not _is_config_valid(_config):
		if config_status:
			printerr("failed to load config: ", error_string(config_status))
		else:
			printerr("failed to load config: structure is invalid or outdated.")

		# Resets to default settings
		print("Restore default settings")
		for section in _default_config:
			reset_section(section)

	_apply_basic_settings()

	var bindings_error := _bindings.load(BINDINGS_PATH)
	if bindings_error:
		printerr("failed to load bindings: ", error_string(bindings_error))
		save_bindings()

	for action in _bindings.get_section_keys("bindings"):
		InputMap.action_erase_events(action)
		for event in _bindings.get_value("bindings", action):
			InputMap.action_add_event(action, event)


## Sets a setting and writes the config file to disk.
func set_and_save_value(section: String, key: String, value: Variant) -> void:
	set_value(section, key, value)
	_config.save(CONFIG_PATH)


## Sets a setting and emits `setting_changed`.
func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	setting_changed.emit(section, key, value)


## Returns the value of a setting.
func get_value(section: String, key: String) -> Variant:
	return _config.get_value(section, key)


## Erases a section and fills it with values from _default_config.
func reset_section(section: String) -> void:
	if _config.has_section(section):
		_config.erase_section(section)
	for key in _default_config[section]:
		var value: Variant = _default_config[section][key]
		set_value(section, key, value)
	_config.save(CONFIG_PATH)


## Restores the default input bindings and saves them.
func reset_input_settings() -> void:
	InputMap.load_from_project_settings()
	save_bindings()


## Writes the current input bindings to disk.
func save_bindings() -> void:
	for action in InputMap.get_actions():
		if action.begins_with("ui_"):
			continue
		_bindings.set_value("bindings", action, InputMap.action_get_events(action))
	var error := _bindings.save(BINDINGS_PATH)
	if error:
		printerr("failed to save bindings: ", error_string(error))


## Returns true if the loaded config matches the default structure and types.
func _is_config_valid(config: ConfigFile) -> bool:
	# Checks sections
	if Array(config.get_sections()) != _default_config.keys():
		return false

	for section in _default_config:
		# Checks keys
		if Array(config.get_section_keys(section)) != _default_config[section].keys():
			return false

		# Checks value types
		for key in _default_config[section]:
			var current_value: Variant = config.get_value(section, key)
			var default_value: Variant = _default_config[section][key]
			if typeof(current_value) != typeof(default_value):
				return false
	return true


## Applies the settings needed before the game starts.
func _apply_basic_settings() -> void:
	TranslationServer.set_locale(Settings.get_value("gameplay", "language"))
	DisplayServer.window_set_mode(Settings.get_value("video", "window_mode"))


func _on_window_size_changed() -> void:
	set_and_save_value("video", "window_mode", DisplayServer.window_get_mode())
