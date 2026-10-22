extends MultiMeshInstance3D
class_name TunnelLayer

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
	assert(_map != null)

	if not enable:
		multimesh.visible_instance_count = 0
		return

	var tunnels := _map.get_tunnels()
	if multimesh.instance_count < tunnels.size():
		multimesh.instance_count = tunnels.size()
	multimesh.visible_instance_count = tunnels.size()
	for i in range(tunnels.size()):
		var tunnel: Array = tunnels[i]
		multimesh.set_instance_transform(i, _transform(tunnel[0], tunnel[1]))


func _transform(pos: Vector2i, direction: E.Direction) -> Transform3D:
	var angle: float
	match direction:
		E.Direction.UP:
			angle = 0.0
		E.Direction.DOWN:
			angle = PI
		E.Direction.LEFT:
			angle = PI / 2.0
		E.Direction.RIGHT:
			angle = -PI / 2.0
		_:
			assert(false)

	# Offset from the cell corner to the arrow pivot
	const ARROW_OFFSET := Vector3(0.5, 0.002, 0.5)
	return Transform3D(Basis(Vector3.UP, angle), Vector3(pos.x, height, pos.y) + ARROW_OFFSET)
