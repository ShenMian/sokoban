extends Node3D
class_name TunnelLayer

## Draws the solver-detected tunnel overlay.

const TUNNEL_CELL_SCENE := preload("res://scenes/tunnel_cell.tscn")

## Whether to show the tunnel overlay.
@export
var enable: bool = false:
	set(value):
		enable = value
		rebuild()

## Height of the tunnel cells.
@export var height := 0.015

var _map: LevelMap


## Wires the level map that provides the tunnels.
func setup(map: LevelMap) -> void:
	_map = map
	if enable:
		rebuild()


## Rebuilds the overlay from the map's current tunnels.
func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	if not enable or _map == null:
		return

	for tunnel in _map.get_tunnels():
		var tunnel_cell: TunnelCell = TUNNEL_CELL_SCENE.instantiate()
		tunnel_cell.position = Vector3(tunnel[0].x, height, tunnel[0].y)
		add_child(tunnel_cell)
		tunnel_cell.setup(tunnel[1])
