extends Node3D
class_name WaypointLayer

## Builds the waypoint markers a selected box can be pushed to.

## Emitted when a waypoint is clicked.
signal waypoint_clicked(pos: Vector2i)
## Emitted when a waypoint is hovered.
signal waypoint_hovered(pos: Vector2i)
## Emitted when the hovered waypoint is left.
signal waypoint_unhovered

## Height of waypoint markers.
@export var waypoint_height: float = 0.01

@onready var _markers: MultiMeshInstance3D = $Markers
@onready var _hover_marker: MeshInstance3D = $HoverMarker

var _map: LevelMap
# Instance index of every shown waypoint.
var _indices: Dictionary = {}
var _hovered_position: Variant = null


## Wires the level map that provides the reachable box positions.
func setup(map: LevelMap) -> void:
	_map = map


## Replaces the markers with the positions reachable by the box at `from`.
func show_for(from: Vector2i) -> void:
	clear()
	if _map == null:
		return

	var positions := _map.get_waypoints(from)
	var multimesh := _markers.multimesh
	multimesh.instance_count = positions.size()
	for i in range(positions.size()):
		_indices[positions[i]] = i
		multimesh.set_instance_transform(i, _transform(positions[i]))


## Removes all markers.
func clear() -> void:
	_hovered_position = null
	_hover_marker.visible = false
	_indices.clear()
	_markers.multimesh.instance_count = 0


func _unhandled_input(event: InputEvent) -> void:
	if _indices.is_empty():
		return

	if event is InputEventMouseMotion:
		_update_hover(_waypoint_at(event.position))
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		var pos: Variant = _waypoint_at(event.position)
		if pos != null:
			get_viewport().set_input_as_handled()
			waypoint_clicked.emit(pos)


## Returns the waypoint at the given screen position, or `null`.
func _waypoint_at(screen_position: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_normal := camera.project_ray_normal(screen_position)
	var ray_end: Variant = Plane(Vector3.UP, waypoint_height).intersects_ray(
		ray_origin, ray_normal
	)
	if ray_end == null:
		return null

	var pos := Vector2i(floori(ray_end.x), floori(ray_end.z))
	if not _indices.has(pos):
		return null

	return pos


## Moves the hover marker to `pos`, or hides it when `pos` is `null`.
func _update_hover(pos: Variant) -> void:
	if pos == _hovered_position:
		return

	if _hovered_position != null:
		_markers.multimesh.set_instance_transform(
			_indices[_hovered_position], _transform(_hovered_position)
		)
		waypoint_unhovered.emit()

	_hovered_position = pos
	if pos == null:
		_hover_marker.visible = false
		return

	# Hide the normal marker at the hovered position
	_markers.multimesh.set_instance_transform(
		_indices[pos], Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	)
	_hover_marker.position = Vector3(pos.x, waypoint_height, pos.y)
	_hover_marker.visible = true
	waypoint_hovered.emit(pos)


func _transform(to: Vector2i) -> Transform3D:
	return Transform3D(Basis(), Vector3(to.x, waypoint_height, to.y))
