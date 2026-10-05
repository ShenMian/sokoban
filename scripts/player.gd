class_name Player
extends Node3D

signal selected
signal unselected
signal hovered
signal unhovered
signal move_finished

@export_group("Move Animation")
@export var move_duration: float = 0.4
@export var move_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var move_transition: Tween.TransitionType = Tween.TRANS_LINEAR

@export_group("Rotate Animation")
@export var rotate_90_duration: float = 0.1
@export var rotate_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var rotate_transition: Tween.TransitionType = Tween.TRANS_LINEAR

@export_group("Indicator Animation")
@export var indicator_tween_duration: float = 1.0
@export var indicator_scale_min: float = 0.9
@export var indicator_scale_max: float = 1.1

@export_group("", "")
@export var selectable: bool = true:
	set(value):
		selectable = value
		_apply_selectable()

var is_moving: bool = false

var _is_selected: bool = false
var _is_hovered: bool = false
var _indicator_tween: Tween
var _duration_multiplier: float = 1.0

@onready var level_map: LevelMap = $".."
@onready var meshes: Node3D = $Meshes
@onready var mesh_area: Area3D = $Meshes/Area
@onready var indicator_area: Area3D = $Indicator/Area
@onready var idle_timer: Timer = $IdleTimer
@onready var state_machine: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var hover_indicator: MeshInstance3D = $Indicator/HoverIndicator
@onready var select_indicator: MeshInstance3D = $Indicator/SelectIndicator


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)

	idle_timer.timeout.connect(_on_idle_timer_timeout)

	mesh_area.input_event.connect(_on_area_input_event)
	mesh_area.mouse_entered.connect(_on_area_mouse_entered)
	mesh_area.mouse_exited.connect(_on_area_mouse_exited)
	indicator_area.input_event.connect(_on_area_input_event)
	indicator_area.mouse_entered.connect(_on_area_mouse_entered)
	indicator_area.mouse_exited.connect(_on_area_mouse_exited)

	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_max, indicator_tween_duration / 2.0)
	_indicator_tween.tween_property(select_indicator, "scale", Vector3.ONE * indicator_scale_min, indicator_tween_duration / 2.0)
	_indicator_tween.pause()

	_on_setting_changed("gameplay", "animation_speed", Settings.get_value("gameplay", "animation_speed"))

	if not selectable:
		_apply_selectable()


func move(direction: Vector2, push: bool) -> void:
	if direction == Vector2.ZERO:
		state_machine.travel("EmoteNo")
		return

	var target_rotation: float
	var direction3d := Vector3(direction.x, 0.0, direction.y)
	match direction3d:
		Vector3.RIGHT:
			target_rotation = 90.0
		Vector3.LEFT:
			target_rotation = -90.0
		Vector3.MODEL_REAR:
			target_rotation = 180.0
		Vector3.MODEL_FRONT:
			target_rotation = 0.0
		_:
			assert(false, "unreachable")

	# Constrain rotation angle to [-180°, 180°] to prevent long-way-around turns
	var delta := fposmod(target_rotation - meshes.rotation_degrees.y + 180.0, 360.0) - 180.0
	target_rotation = meshes.rotation_degrees.y + delta

	is_moving = true
	var tween := create_tween().set_parallel(true)

	if meshes.rotation_degrees.y != target_rotation:
		var rotate_duration: float = abs(meshes.rotation_degrees.y - target_rotation) / 90.0 * rotate_90_duration
		tween.tween_property(meshes, "rotation_degrees:y", target_rotation, rotate_duration * _duration_multiplier) \
			.set_ease(rotate_ease) \
			.set_trans(rotate_transition)

	if push:
		state_machine.travel("Pushing")
	else:
		state_machine.travel("Walking")

	tween.tween_property(self, "global_position", global_position + direction3d, move_duration * _duration_multiplier) \
		.set_ease(move_ease) \
		.set_trans(move_transition)

	await tween.finished

	state_machine.travel("Static")
	is_moving = false
	move_finished.emit()


func set_facing(direction: E.Direction) -> void:
	match direction:
		E.Direction.UP:
			meshes.rotation_degrees.y = 180.0
		E.Direction.DOWN:
			meshes.rotation_degrees.y = 0.0
		E.Direction.LEFT:
			meshes.rotation_degrees.y = -90.0
		E.Direction.RIGHT:
			meshes.rotation_degrees.y = 90.0


func deselect() -> void:
	_is_selected = false
	_apply_indicator()


func grid_position() -> Vector2i:
	return Vector2i(round(global_position.x), round(global_position.z))


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "gameplay" and key == "animation_speed":
		match value:
			E.AnimationSpeed.SLOW:
				_duration_multiplier = 1.0
			E.AnimationSpeed.NORMAL:
				_duration_multiplier = 0.5
			E.AnimationSpeed.FAST:
				_duration_multiplier = 0.25
			E.AnimationSpeed.INSTANT:
				pass


func _on_idle_timer_timeout() -> void:
	if state_machine.get_current_node() == "Static":
		state_machine.travel("Idle")
	idle_timer.start()


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_is_selected = not _is_selected
		_apply_indicator()
		if _is_selected:
			selected.emit()
		else:
			unselected.emit()
		get_viewport().set_input_as_handled()


func _on_area_mouse_entered() -> void:
	_is_hovered = true
	_apply_indicator()
	hovered.emit()


func _on_area_mouse_exited() -> void:
	_is_hovered = false
	_apply_indicator()
	unhovered.emit()


func _apply_indicator() -> void:
	select_indicator.visible = _is_selected
	hover_indicator.visible = _is_hovered and not _is_selected

	if _is_selected:
		_start_indicator_tween()
	else:
		_stop_indicator_tween()


func _start_indicator_tween() -> void:
	_indicator_tween.play()


func _stop_indicator_tween() -> void:
	_indicator_tween.pause()
	select_indicator.scale = Vector3.ONE


func _apply_selectable() -> void:
	if not is_node_ready():
		return

	if not selectable:
		mesh_area.input_ray_pickable = false
		indicator_area.input_ray_pickable = false

		if _is_selected:
			deselect()
		if _is_hovered:
			_on_area_mouse_exited()
	else:
		mesh_area.input_ray_pickable = true
		indicator_area.input_ray_pickable = true
