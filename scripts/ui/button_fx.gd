extends Button
class_name ButtonFx

@export var smooth_factor: float = 20.0

const SCALE_SNAP_DISTANCE: float = 0.001

var _target_scale := Vector2.ONE


func _ready() -> void:
	set_process(false)
	pivot_offset_ratio = Vector2.ONE / 2.0
	if not disabled:
		_on_enabled()


func _process(delta: float) -> void:
	scale = lerp(scale, _target_scale, clamp(delta * smooth_factor, 0.0, 1.0))
	if scale.distance_squared_to(_target_scale) < SCALE_SNAP_DISTANCE * SCALE_SNAP_DISTANCE:
		set_process(false)
		scale = _target_scale


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		_on_disabled()
	elif what == NOTIFICATION_ENABLED:
		_on_enabled()


func _on_enabled() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hovered)
	mouse_exited.connect(_on_unhovered)
	focus_entered.connect(_on_hovered)
	focus_exited.connect(_on_unhovered)


func _on_disabled() -> void:
	set_process(false)
	_reset()
	pressed.disconnect(_on_pressed)
	mouse_entered.disconnect(_on_hovered)
	mouse_exited.disconnect(_on_unhovered)
	focus_entered.disconnect(_on_hovered)
	focus_exited.disconnect(_on_unhovered)


func _on_pressed() -> void:
	Sounds.play_button_press()


func _on_hovered() -> void:
	_target_scale = Vector2.ONE * 1.1
	Sounds.play_button_hover()
	set_process(true)


func _on_unhovered() -> void:
	_target_scale = Vector2.ONE
	set_process(true)


func _reset() -> void:
	_target_scale = Vector2.ONE
	scale = Vector2.ONE
