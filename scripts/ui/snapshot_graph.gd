class_name SnapshotGraph
extends Control
## State graph of snapshots and the live state. Edges are state transitions.

const NODE_RADIUS := 9.0
const X_GAP := 72.0
const Y_GAP := 48.0
const PADDING := 28.0
const MIN_WIDTH := 360.0
const MIN_HEIGHT := 220.0

@export var node_color := Color(0.27, 0.58, 0.95)
@export var live_color := Color(0.20, 0.84, 0.48)
@export var solved_color := Color(0.96, 0.71, 0.22)
@export var root_color := Color(0.51, 0.57, 0.65)
@export var edge_color := Color(0.30, 0.35, 0.44, 0.75)

var _nodes: Array = []
var _edges: Array = []
var _key_to_index := {}
var _hover_index := -1
var _pointer := Vector2.ZERO
var _pointer_inside := false
var _pulse := 0.0
var _graph_size := Vector2(MIN_WIDTH, MIN_HEIGHT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse = fmod(_pulse + delta, 1.8)
	queue_redraw()


## Replaces the state graph.
func set_graph(nodes: Array, edges: Array) -> void:
	_nodes = nodes.duplicate(true)
	_edges = edges.duplicate(true)
	_rebuild_layout()


## Assigns graph coordinates by distance from the start state.
func _rebuild_layout() -> void:
	_key_to_index.clear()
	var adjacency := {}
	var start_index := -1

	for i in range(_nodes.size()):
		var key := str(_nodes[i].get("key", ""))
		_key_to_index[key] = i
		if start_index < 0 and str(_nodes[i].get("kind", "")) == "start":
			start_index = i

	for edge: Dictionary in _edges:
		adjacency.get_or_add(str(edge.get("from", "")), []).append(str(edge.get("to", "")))

	var depths := {}
	if start_index >= 0:
		var start_key := str(_nodes[start_index].get("key", ""))
		depths[start_key] = 0
		var queue: Array[String] = [start_key]
		while not queue.is_empty():
			var curr: String = queue.pop_front()
			for next_key: String in adjacency.get(curr, []):
				if _key_to_index.has(next_key) and not depths.has(next_key):
					depths[next_key] = depths[curr] + 1
					queue.append(next_key)

	var columns := {}
	var max_depth := 0
	var max_rows := 1
	for i in range(_nodes.size()):
		var depth: int = depths.get(str(_nodes[i].get("key", "")), 0)
		_nodes[i]["depth"] = depth
		columns.get_or_add(depth, []).append(i)
		max_depth = maxi(max_depth, depth)

	for depth: int in columns:
		var indexes: Array = columns[depth]
		indexes.sort_custom(func(a: int, b: int) -> bool:
			var oa := int(_nodes[a].get("order", 0))
			var ob := int(_nodes[b].get("order", 0))
			return str(_nodes[a].get("key", "")) < str(_nodes[b].get("key", "")) if oa == ob else oa < ob
		)
		max_rows = maxi(max_rows, indexes.size())

	var width := maxf(max_depth * X_GAP + (NODE_RADIUS + PADDING) * 2.0, MIN_WIDTH)
	var height := maxf((max_rows - 1) * Y_GAP + (NODE_RADIUS + PADDING) * 2.0, MIN_HEIGHT)
	_graph_size = Vector2(width, height)
	custom_minimum_size = _graph_size

	for depth: int in columns:
		var indexes: Array = columns[depth]
		var start_y := (height - (indexes.size() - 1) * Y_GAP) * 0.5
		var x := PADDING + NODE_RADIUS + int(depth) * X_GAP
		for row in range(indexes.size()):
			_nodes[indexes[row]]["pos"] = Vector2(x, start_y + row * Y_GAP)

	_set_hover(_hit_test(_pointer) if _pointer_inside else -1)
	queue_redraw()


func _draw() -> void:
	_draw_edges()
	_draw_nodes()


func _draw_edges() -> void:
	var hover_key := str(_nodes[_hover_index].get("key", "")) if _hover_index >= 0 else ""
	var edge_keys := {}
	for edge: Dictionary in _edges:
		edge_keys[str(edge.get("from", "")) + "\n" + str(edge.get("to", ""))] = true

	for edge: Dictionary in _edges:
		var from_idx: int = _key_to_index.get(str(edge.get("from", "")), -1)
		var to_idx: int = _key_to_index.get(str(edge.get("to", "")), -1)
		if from_idx < 0 or to_idx < 0 or from_idx == to_idx:
			continue

		var from: Vector2 = _nodes[from_idx]["pos"]
		var to: Vector2 = _nodes[to_idx]["pos"]
		var delta := to - from
		var ctrl1: Vector2
		var ctrl2: Vector2
		if edge_keys.has(str(edge.get("to", "")) + "\n" + str(edge.get("from", ""))):
			var normal := delta.orthogonal().normalized() * 24.0
			ctrl1 = from + delta * 0.3 + normal
			ctrl2 = to - delta * 0.3 + normal
		elif delta.x > 0.0:
			var dx := delta.x
			ctrl1 = from + Vector2(maxf(dx * 0.45, 20.0), 0.0)
			ctrl2 = to - Vector2(maxf(dx * 0.45, 20.0), 0.0)
		else:
			var bend := 40.0 * (1.0 if delta.y >= 0.0 else -1.0)
			ctrl1 = from + Vector2(30.0, bend)
			ctrl2 = to - Vector2(30.0, bend)

		var points := PackedVector2Array()
		for step in range(17):
			points.append(from.bezier_interpolate(ctrl1, ctrl2, to, step / 16.0))

		var tip := to - (to - ctrl2).normalized() * (NODE_RADIUS + 0.5)
		var tip_index := points.size() - 1
		while tip_index > 0 and points[tip_index].distance_to(to) <= NODE_RADIUS + 0.5:
			tip_index -= 1
		var dir := Vector2.ZERO
		if tip_index > 0:
			points.resize(tip_index + 1)
			dir = (tip - points[points.size() - 2]).normalized()
			points[points.size() - 1] = tip
		else:
			points.resize(1)

		var is_connected: bool = hover_key != "" and (edge.from == hover_key or edge.to == hover_key)
		var color := edge_color.lightened(0.35) if is_connected else edge_color
		var width := 2.4 if is_connected else 1.6
		draw_polyline(points, color, width, true)

		if dir != Vector2.ZERO:
			var back := tip - dir * 7.0
			var normal := dir.orthogonal() * 4.0
			draw_line(tip, back + normal, color, width, true)
			draw_line(tip, back - normal, color, width, true)


func _draw_nodes() -> void:
	for i in range(_nodes.size()):
		var node: Dictionary = _nodes[i]
		var center: Vector2 = node["pos"]
		var hovered := _hover_index == i
		var is_live := bool(node.get("is_live", false))

		var fill := node_color
		if str(node.get("kind", "")) == "start":
			fill = root_color
		elif bool(node.get("solved", false)):
			fill = solved_color

		if hovered:
			draw_circle(center, NODE_RADIUS + 4.0, Color(1.0, 1.0, 1.0, 0.12))

		draw_circle(center, NODE_RADIUS, fill)
		draw_arc(center, NODE_RADIUS + 0.5, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.3), 1.0, true)

		if is_live:
			draw_arc(center, NODE_RADIUS + 2.5, 0.0, TAU, 32, live_color, 1.8, true)
			var progress := _pulse / 1.8
			draw_arc(center, NODE_RADIUS + 2.5 + progress * 7.0, 0.0, TAU, 36, Color(live_color, 0.55 * (1.0 - progress)), 1.6, true)
		if hovered:
			draw_arc(center, NODE_RADIUS + (4.5 if is_live else 3.0), 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.65), 1.4, true)


func _hit_test(point: Vector2) -> int:
	for i in range(_nodes.size() - 1, -1, -1):
		if point.distance_to(_nodes[i]["pos"]) <= NODE_RADIUS + 5.0:
			return i
	return -1


func _set_hover(index: int) -> void:
	if index == _hover_index:
		return
	_hover_index = index
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if index >= 0 else Control.CURSOR_ARROW
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = event.position
		_pointer_inside = true
		_set_hover(_hit_test(event.position))


func _on_mouse_exited() -> void:
	_pointer_inside = false
	_set_hover(-1)
