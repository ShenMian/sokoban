extends Node3D
class_name TunnelCell


## Orients the single 1/4-size arrow along the tunnel push direction.
## Rotation pivots around the cell center (the Arrow node), so the arrow
## lands on the matching edge: Up=top, Down=bottom, Left=left, Right=right.
## Uses get_node directly so it works right after instantiate(),
## before or after entering the tree.
func setup(direction: E.Direction) -> void:
	var arrow: Node3D = $Arrow
	match direction:
		E.Direction.UP:
			arrow.rotation.y = 0.0
		E.Direction.DOWN:
			arrow.rotation.y = PI
		E.Direction.LEFT:
			arrow.rotation.y = PI / 2.0
		E.Direction.RIGHT:
			arrow.rotation.y = -PI / 2.0
		_:
			assert(false)
