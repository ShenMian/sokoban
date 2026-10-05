extends ScrollContainer

@onready var master_volume: SliderBar = $VBox/MasterVolumePanel/HSplit/SliderBar
@onready var music_volume: SliderBar = $VBox/MusicVolumePanel/HSplit/SliderBar
@onready var sfx_volume: SliderBar = $VBox/SfxVolumePanel/HSplit/SliderBar
@onready var mute_on_unfocused: CheckButton = $VBox/MuteOnUnfocusedPanel/HBox/CheckButton

@onready var master_bus_index := AudioServer.get_bus_index("Master")
@onready var music_bus_index := AudioServer.get_bus_index("Music")
@onready var sfx_bus_index := AudioServer.get_bus_index("Sfx")

const SECTION_NAME := "audio"


func _ready() -> void:
	master_volume.value_changed.connect(_on_volume_changed.bind(master_bus_index))
	music_volume.value_changed.connect(_on_volume_changed.bind(music_bus_index))
	sfx_volume.value_changed.connect(_on_volume_changed.bind(sfx_bus_index))

	mute_on_unfocused.toggled.connect(_on_mute_on_unfocused_toggled)

	apply_settings()


func apply_settings() -> void:
	master_volume.value = Settings.get_value("audio", "master_volume")
	music_volume.value = Settings.get_value("audio", "music_volume")
	sfx_volume.value = Settings.get_value("audio", "sfx_volume")
	mute_on_unfocused.button_pressed = Settings.get_value("audio", "mute_on_unfocused")


func _on_volume_changed(value: float, bus_index: int) -> void:
	var volume := linear_to_db(value)
	AudioServer.set_bus_volume_db(bus_index, volume)
	Settings.set_and_save_value(SECTION_NAME, "%s_volume" % AudioServer.get_bus_name(bus_index).to_lower(), value)


func _on_mute_on_unfocused_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "mute_on_unfocused", toggled_on)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_window_minimized()

		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_window_restored()


func _on_window_minimized() -> void:
	if not mute_on_unfocused.button_pressed:
		return
	AudioServer.set_bus_mute(master_bus_index, true)


func _on_window_restored() -> void:
	if not mute_on_unfocused.button_pressed:
		return
	AudioServer.set_bus_mute(master_bus_index, false)
