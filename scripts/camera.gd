extends Camera3D

@export var drag_sensitivity: float = 1.5
@export var zoom_sensitivity: float = 1.0
@export var smooth_factor: float = 15.0

var zoom_factor: float:
	set(value):
		zoom_factor = value
		if self.is_3d_view():
			_target_position.y = zoom_factor / (2.0 * tan(deg_to_rad(fov) / 2.0))
		else:
			_target_size = zoom_factor

var min_zoom_factor: float = 2.0
var max_zoom_factor: float = INF

var _is_dragging = false
var _target_position: Vector3
var _target_size: float = 10.0

# Touch state
var _touches: Dictionary = {} # index -> position
var _touch_initial_distance: float = 0.0
var _touch_initial_zoom: float = 0.0


func _ready():
	Settings.setting_changed.connect(_on_setting_changed)
	_target_position = global_position

	_on_setting_changed("gameplay", "2d_view", Settings.get_value("gameplay", "2d_view"))


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "video" and key == "fov":
		set_fov(value)
	elif section == "gameplay" and key == "2d_view":
		if value:
			projection = PROJECTION_ORTHOGONAL
			self.zoom_factor = zoom_factor
			size = _target_size
		else:
			projection = PROJECTION_PERSPECTIVE
			self.zoom_factor = zoom_factor
			global_position = _target_position


func _process(delta: float):
	if abs(self.size - _target_size) > 0.001:
		size = lerp(size, _target_size, clamp(delta * smooth_factor, 0.0, 1.0))
	else:
		size = _target_size

	if global_position.distance_to(_target_position) > 0.001:
		global_position = lerp(global_position, _target_position, clamp(delta * smooth_factor, 0.0, 1.0))
	else:
		global_position = _target_position


func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
	elif event is InputEventMouseMotion and _is_dragging:
		_target_position.x -= event.relative.x * drag_sensitivity * zoom_factor * 0.001
		_target_position.z -= event.relative.y * drag_sensitivity * zoom_factor * 0.001
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch):
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var points: Array = _touches.values()
			_touch_initial_distance = (points[0] as Vector2).distance_to(points[1] as Vector2)
			_touch_initial_zoom = zoom_factor
	else:
		_touches.erase(event.index)
		# If one finger remains, reset its position to avoid a jump
		if _touches.size() == 1:
			var remaining_index: int = _touches.keys()[0]
			_touches[remaining_index] = event.position


func _handle_screen_drag(event: InputEventScreenDrag):
	_touches[event.index] = event.position

	if _touches.size() == 1:
		# Single finger drag: pan
		_target_position.x -= event.relative.x * drag_sensitivity * zoom_factor * 0.001
		_target_position.z -= event.relative.y * drag_sensitivity * zoom_factor * 0.001
	elif _touches.size() == 2:
		# Two finger pinch: zoom
		var points: Array = _touches.values()
		var current_distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
		if _touch_initial_distance > 0.0:
			var ratio: float = _touch_initial_distance / current_distance
			zoom_factor = clampf(_touch_initial_zoom * ratio, 2.0, max_zoom_factor)

		# Two finger drag: pan (use average relative motion)
		_target_position.x -= event.relative.x * drag_sensitivity * zoom_factor * 0.001 * 0.5
		_target_position.z -= event.relative.y * drag_sensitivity * zoom_factor * 0.001 * 0.5


func zoom_in():
	zoom_factor = max(zoom_factor - zoom_sensitivity, min_zoom_factor)


func zoom_out():
	zoom_factor = min(zoom_factor + zoom_sensitivity, max_zoom_factor)


func is_3d_view() -> bool:
	return projection == PROJECTION_PERSPECTIVE
