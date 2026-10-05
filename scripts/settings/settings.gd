extends Node

signal setting_changed(section: String, key: String, value: Variant)

const DEFAULT_CONFIG = {
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
		"taa": false
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"mute_on_unfocused": true
	}
}

const CONFIG_PATH = "user://settings.ini"
const BINDINGS_PATH = "user://bindings.ini"

const LEVEL_PATH = "res://assets/levels/"

var _config := ConfigFile.new()
var _bindings := ConfigFile.new()


func _ready() -> void:
	get_window().size_changed.connect(_on_window_size_changed)

	print("User path: ", ProjectSettings.globalize_path("user://"))

	var config_status := _config.load(CONFIG_PATH)
	if config_status or not _is_config_valid(_config):
		if config_status:
			printerr("failed to load config: ", error_string(config_status))
		else:
			printerr("failed to load config: structure is invalid or outdated.")

		# Resets to default settings
		print("Restore default settings")
		reset_gameplay_settings()
		reset_assists_settings()
		reset_video_settings()
		reset_audio_settings()

	_apply_basic_settings()

	var bindings_error := _bindings.load(BINDINGS_PATH)
	if bindings_error:
		printerr("failed to load bindings: ", error_string(bindings_error))
		save_bindings()

	for action in _bindings.get_section_keys("bindings"):
		InputMap.action_erase_events(action)
		for event in _bindings.get_value("bindings", action):
			InputMap.action_add_event(action, event)


func set_and_save_value(section: String, key: String, value: Variant) -> void:
	set_value(section, key, value)
	_config.save(CONFIG_PATH)


func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	setting_changed.emit(section, key, value)


func get_value(section: String, key: String) -> Variant:
	return _config.get_value(section, key)


func reset_gameplay_settings() -> void:
	_config.erase_section("gameplay")
	for key in DEFAULT_CONFIG.gameplay:
		var value: Variant = DEFAULT_CONFIG.gameplay[key]
		set_value("gameplay", key, value)

	var locale := OS.get_locale_language()
	if locale in TranslationServer.get_loaded_locales():
		_config.set_value("gameplay", "language", locale)

	_config.save(CONFIG_PATH)


func reset_assists_settings() -> void:
	_config.erase_section("assists")
	for key in DEFAULT_CONFIG.assists:
		var value: Variant = DEFAULT_CONFIG.assists[key]
		set_value("assists", key, value)
	_config.save(CONFIG_PATH)


func reset_video_settings() -> void:
	_config.erase_section("video")
	for key in DEFAULT_CONFIG.video:
		var value: Variant = DEFAULT_CONFIG.video[key]
		set_value("video", key, value)

	if OS.get_name() == "Android":
		_config.set_value("video", "window_mode", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	_config.save(CONFIG_PATH)


func reset_audio_settings() -> void:
	_config.erase_section("audio")
	for key in DEFAULT_CONFIG.audio:
		var value: Variant = DEFAULT_CONFIG.audio[key]
		set_value("audio", key, value)
	_config.save(CONFIG_PATH)


func reset_input_settings() -> void:
	InputMap.load_from_project_settings()
	save_bindings()


func save_bindings() -> void:
	for action in InputMap.get_actions():
		if action.begins_with("ui_"):
			continue
		_bindings.set_value("bindings", action, InputMap.action_get_events(action))
	var error := _bindings.save(BINDINGS_PATH)
	if error:
		printerr("failed to save bindings: ", error_string(error))


func _is_config_valid(config: ConfigFile) -> bool:
	# Checks sections
	if Array(config.get_sections()) != DEFAULT_CONFIG.keys():
		return false

	for section in DEFAULT_CONFIG:
		# Checks keys
		if Array(config.get_section_keys(section)) != DEFAULT_CONFIG[section].keys():
			return false

		# Checks value types
		for key in DEFAULT_CONFIG[section]:
			var current_value: Variant = config.get_value(section, key)
			var default_value: Variant = DEFAULT_CONFIG[section][key]
			if typeof(current_value) != typeof(default_value):
				return false
	return true


func _apply_basic_settings() -> void:
	TranslationServer.set_locale(Settings.get_value("gameplay", "language"))
	DisplayServer.window_set_mode(Settings.get_value("video", "window_mode"))


func _on_window_size_changed() -> void:
	set_and_save_value("video", "window_mode", DisplayServer.window_get_mode())
