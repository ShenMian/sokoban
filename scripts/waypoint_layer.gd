extends Node3D
class_name WaypointLayer

## Builds the waypoint markers a selected box can be pushed to.

const WAYPOINT_SCENE := preload("res://scenes/waypoint.tscn")

## Emitted when a waypoint is clicked.
signal waypoint_clicked(to: Vector2i)
## Emitted when a waypoint is hovered.
signal waypoint_hovered(to: Vector2i)
## Emitted when the hovered waypoint is left.
signal waypoint_unhovered

## Height of waypoint markers.
@export var waypoint_height: float = 0.01

var _map: LevelMap


## Wires the level map that provides the reachable box positions.
func setup(map: LevelMap) -> void:
	_map = map


## Replaces the markers with the positions reachable by the box at `from`.
func show_for(from: Vector2i) -> void:
	clear()
	if _map == null:
		return

	for to in _map.get_waypoints(from):
		var waypoint = WAYPOINT_SCENE.instantiate()
		waypoint.position = Vector3(to.x, waypoint_height, to.y)
		waypoint.clicked.connect(waypoint_clicked.emit.bind(to))
		waypoint.hovered.connect(waypoint_hovered.emit.bind(to))
		waypoint.unhovered.connect(waypoint_unhovered.emit)
		add_child(waypoint)


## Removes all markers.
func clear() -> void:
	for child in get_children():
		child.queue_free()
