extends ScrollContainer

@onready var window_mode: OptionButton = $VBox/WindowModePanel/HBox/OptionButton
@onready var vsync: CheckButton = $VBox/VsyncPanel/HBox/CheckButton
@onready var frame_rate_limit: SliderBar = $VBox/FrameRateLimitPanel/HSplit/SliderBar
@onready var scaling_method: OptionButton = $VBox/ScalingMethodPanel/HBox/OptionButton
@onready var upscaled_resolution: SliderBar = $VBox/UpscaledResolutionPanel/HSplit/SliderBar
@onready var fsr_sharpness: SliderBar = $VBox/FsrSharpnessPanel/HSplit/SliderBar

@onready var fov: SliderBar = $VBox/FieldOfViewPanel/HSplit/SliderBar

@onready var screen_space_aa: OptionButton = $VBox/ScreenSpaceAAPanel/HBox/OptionButton
@onready var msaa: OptionButton = $VBox/MsaaPanel/HBox/OptionButton
@onready var taa: CheckButton = $VBox/TaaPanel/HBox/CheckButton

const SECTION_NAME := "video"

const WINDOW_MODES: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_MAXIMIZED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
]

const SCREEN_SPACE_AA_MODES: Array[Viewport.ScreenSpaceAA] = [
	Viewport.SCREEN_SPACE_AA_DISABLED,
	Viewport.SCREEN_SPACE_AA_SMAA,
	Viewport.SCREEN_SPACE_AA_FXAA
]

const MSAA_MODES: Array[Viewport.MSAA] = [
	Viewport.MSAA_DISABLED,
	Viewport.MSAA_2X,
	Viewport.MSAA_4X,
	Viewport.MSAA_8X
]

const SCALING_3D_MODES: Array[Viewport.Scaling3DMode] = [
	Viewport.SCALING_3D_MODE_BILINEAR,
	Viewport.SCALING_3D_MODE_FSR,
	Viewport.SCALING_3D_MODE_FSR2
]


func _ready() -> void:
	_disable_unavailable_features()

	window_mode.item_selected.connect(_on_window_mode_selected)
	vsync.toggled.connect(_on_vsync_toggled)
	frame_rate_limit.value_changed.connect(_on_frame_rate_limit_changed)
	scaling_method.item_selected.connect(_on_scaling_method_selected)
	upscaled_resolution.value_changed.connect(_on_upscaled_resolution_changed)
	fsr_sharpness.value_changed.connect(_on_fsr_sharpness_changed)
	fov.value_changed.connect(_on_fov_changed)
	screen_space_aa.item_selected.connect(_on_screen_space_aa_selected)
	msaa.item_selected.connect(_on_msaa_selected)
	taa.toggled.connect(_on_taa_toggled)

	apply_settings()


func apply_settings() -> void:
	window_mode.select(WINDOW_MODES.find(Settings.get_value(SECTION_NAME, "window_mode")))
	window_mode.item_selected.emit(window_mode.selected)

	vsync.button_pressed = Settings.get_value(SECTION_NAME, "vsync")
	vsync.toggled.emit(vsync.button_pressed)

	var max_fps: int = Settings.get_value(SECTION_NAME, "frame_rate_limit")
	frame_rate_limit.value = frame_rate_limit.max_value if max_fps == 0 else float(max_fps)

	upscaled_resolution.value = Settings.get_value(SECTION_NAME, "scaling_3d_scale")
	upscaled_resolution.value_changed.emit(upscaled_resolution.value)

	fsr_sharpness.value = Settings.get_value(SECTION_NAME, "fsr_sharpness")
	fsr_sharpness.value_changed.emit(fsr_sharpness.value)

	fov.value = Settings.get_value(SECTION_NAME, "fov")

	screen_space_aa.select(SCREEN_SPACE_AA_MODES.find(Settings.get_value(SECTION_NAME, "screen_space_aa")))
	screen_space_aa.item_selected.emit(screen_space_aa.selected)

	msaa.select(MSAA_MODES.find(Settings.get_value(SECTION_NAME, "msaa")))
	msaa.item_selected.emit(msaa.selected)

	taa.button_pressed = Settings.get_value(SECTION_NAME, "taa")
	taa.toggled.emit(taa.button_pressed)

	scaling_method.select(SCALING_3D_MODES.find(Settings.get_value(SECTION_NAME, "scaling_3d_mode")))
	scaling_method.item_selected.emit(scaling_method.selected)


func _disable_unavailable_features() -> void:
	# Disable unavailable features based on the rendering method
	# https://docs.godotengine.org/en/4.6/tutorials/3d/3d_antialiasing.html#antialiasing-comparison
	var rendering_method := RenderingServer.get_current_rendering_method()
	var is_forward_plus := rendering_method == "forward_plus"
	var is_mobile := rendering_method == "mobile"

	var support_fsr := is_forward_plus
	var support_taa := is_forward_plus
	var support_fxaa := is_forward_plus or is_mobile
	var support_smaa := is_forward_plus or is_mobile

	scaling_method.set_item_disabled(SCALING_3D_MODES.find(Viewport.SCALING_3D_MODE_FSR), not support_fsr)
	scaling_method.set_item_disabled(SCALING_3D_MODES.find(Viewport.SCALING_3D_MODE_FSR2), not support_fsr)
	taa.disabled = not support_taa
	screen_space_aa.set_item_disabled(SCREEN_SPACE_AA_MODES.find(Viewport.SCREEN_SPACE_AA_FXAA), not support_fxaa)
	screen_space_aa.set_item_disabled(SCREEN_SPACE_AA_MODES.find(Viewport.SCREEN_SPACE_AA_SMAA), not support_smaa)


func _on_window_mode_selected(index: int) -> void:
	var mode := WINDOW_MODES[index]
	DisplayServer.window_set_mode(mode)
	Settings.set_and_save_value(SECTION_NAME, "window_mode", mode)


func _on_vsync_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		frame_rate_limit.disabled = true
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		frame_rate_limit.disabled = false
	Settings.set_and_save_value(SECTION_NAME, "vsync", DisplayServer.window_get_vsync_mode())


func _on_frame_rate_limit_changed(value: float) -> void:
	if value == 0 or value == frame_rate_limit.max_value:
		frame_rate_limit.value = frame_rate_limit.max_value
		frame_rate_limit.label.text = "UNLIMITED"
		Engine.max_fps = 0
	else:
		Engine.max_fps = int(value)
	Settings.set_and_save_value(SECTION_NAME, "frame_rate_limit", Engine.max_fps)


func _on_fov_changed(value: float) -> void:
	Settings.set_and_save_value(SECTION_NAME, "fov", value)


func _on_screen_space_aa_selected(index: int) -> void:
	var mode := SCREEN_SPACE_AA_MODES[index]
	get_viewport().screen_space_aa = mode
	Settings.set_and_save_value(SECTION_NAME, "screen_space_aa", mode)


func _on_msaa_selected(index: int) -> void:
	var mode := MSAA_MODES[index]
	get_viewport().msaa_3d = mode
	Settings.set_and_save_value(SECTION_NAME, "msaa", mode)


func _on_taa_toggled(toggled_on: bool) -> void:
	get_viewport().use_taa = toggled_on
	Settings.set_and_save_value(SECTION_NAME, "taa", toggled_on)


func _on_scaling_method_selected(index: int) -> void:
	var mode := SCALING_3D_MODES[index]
	var last_mode := get_viewport().scaling_3d_mode
	get_viewport().scaling_3d_mode = mode
	Settings.set_and_save_value(SECTION_NAME, "scaling_3d_mode", mode)

	fsr_sharpness.disabled = not (mode == Viewport.SCALING_3D_MODE_FSR or mode == Viewport.SCALING_3D_MODE_FSR2)
	# Disable AA when using FSR 2.2
	if mode == Viewport.SCALING_3D_MODE_FSR2:
		screen_space_aa.disabled = true
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		taa.disabled = true
		get_viewport().use_taa = false
		msaa.disabled = true
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	elif last_mode == Viewport.SCALING_3D_MODE_FSR2:
		screen_space_aa.disabled = false
		get_viewport().screen_space_aa = screen_space_aa.selected as Viewport.ScreenSpaceAA
		taa.disabled = false
		get_viewport().use_taa = taa.button_pressed
		msaa.disabled = false
		get_viewport().msaa_3d = msaa.selected as Viewport.MSAA


func _on_upscaled_resolution_changed(value: float) -> void:
	get_viewport().scaling_3d_scale = value
	Settings.set_and_save_value(SECTION_NAME, "scaling_3d_scale", value)


func _on_fsr_sharpness_changed(value: float) -> void:
	get_viewport().fsr_sharpness = value
	Settings.set_and_save_value(SECTION_NAME, "fsr_sharpness", value)
