extends Node3D
class_name LowerBoundsLayer

## Draws the level's heuristic lower-bound heatmap.

const HEATMAP_CELL_SCENE := preload("res://scenes/heatmap_cell.tscn")

## Whether to show the lower-bound heatmap.
@export
var enable: bool = false:
	set(value):
		enable = value
		rebuild()

## Height of the heatmap cells.
@export var height := 0.01

var _map: LevelMap


## Wires the level map that provides the lower-bound costs.
func setup(map: LevelMap) -> void:
	_map = map
	if enable:
		rebuild()


## Rebuilds the heatmap from the map's current lower-bound costs.
func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	if not enable or _map == null:
		return

	var min_costs: Dictionary = _map.get_min_costs(_map.solver_strategy)
	if min_costs.is_empty():
		return
	var max_lower_bound: int = min_costs.values().max()
	for pos in min_costs:
		var heatmap_cell: HeatmapCell = HEATMAP_CELL_SCENE.instantiate()
		heatmap_cell.position = Vector3(pos.x, height, pos.y)
		add_child(heatmap_cell)
		heatmap_cell.setup(min_costs[pos], max_lower_bound)
