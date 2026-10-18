extends MeshInstance3D
class_name PathPreview

## Draws the smoothed guidance ribbon toward a hovered waypoint.

@export_group("Path Preview")
## Whether hovering a waypoint shows a path preview.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var enable: bool = true
## Material of the path preview ribbon.
@export var material: StandardMaterial3D
## Width of the path preview ribbon.
@export var width: float = 0.1
## Height of the path preview ribbon above the floor.
@export var height: float = 0.02

@export_group("", "")

var _map: LevelMap


## Wires the level map the preview asks for box paths.
func setup(map: LevelMap) -> void:
	_map = map


## Draws the preview toward `to`.
func show_path(to: Vector2i) -> void:
	if not enable or _map == null:
		return

	var box_path := _map.get_box_path(to)
	if box_path.size() < 2:
		return
	var path2d := _smooth_path(box_path, 0.3, 8)

	var path3d: Array[Vector3] = []
	for point in path2d:
		path3d.append(Vector3(point.x + 0.5, height, point.y + 0.5))

	mesh = _create_path_mesh(path3d, width)
	material_override = material


## Clears the preview mesh.
func clear() -> void:
	mesh = null


## Rounds the corners of a tile path into a smooth polyline.
func _smooth_path(path: Array[Vector2i], corner_radius: float, resolution: int) -> Array[Vector2]:
	if path.size() < 3:
		var raw_path: Array[Vector2] = []
		for point in path:
			raw_path.append(Vector2(point))
		return raw_path

	var smoothed: Array[Vector2] = []
	smoothed.append(Vector2(path[0]))

	for i in range(1, path.size() - 1):
		var prev := Vector2(path[i - 1])
		var curr := Vector2(path[i])
		var next := Vector2(path[i + 1])

		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()

		# If the segment is straight or a 180° U-turn, skip smoothing
		if abs(dir_in.dot(dir_out)) > 0.99:
			smoothed.append(curr)
			continue

		var max_radius = min(curr.distance_to(prev) / 2.0, curr.distance_to(next) / 2.0)
		var actual_radius = min(corner_radius, max_radius)

		var curve_start = curr - dir_in * actual_radius
		var curve_end = curr + dir_out * actual_radius

		# Quadratic Bezier curve interpolation
		for j in range(resolution + 1):
			var t := float(j) / resolution
			var point = curve_start * (1 - t) * (1 - t) + curr * 2 * (1 - t) * t + curve_end * t * t
			smoothed.append(point)

	smoothed.append(Vector2(path[-1]))

	return smoothed


## Builds a triangle-strip ribbon mesh along the given path.
func _create_path_mesh(smoothed_path: Array[Vector3], ribbon_width: float) -> ImmediateMesh:
	assert(smoothed_path.size() >= 2)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var half_width := ribbon_width / 2.0
	for i in range(smoothed_path.size()):
		var curr := smoothed_path[i]
		var dir_prev := Vector3.ZERO
		var dir_next := Vector3.ZERO

		if i > 0:
			dir_prev = (curr - smoothed_path[i - 1]).normalized()
		if i < smoothed_path.size() - 1:
			dir_next = (smoothed_path[i + 1] - curr).normalized()

		var side: Vector3
		if dir_prev == Vector3.ZERO:
			# Start point
			side = dir_next.cross(Vector3.UP).normalized() * half_width
		elif dir_next == Vector3.ZERO:
			# End point
			side = dir_prev.cross(Vector3.UP).normalized() * half_width
		else:
			# Corner
			var tangent := (dir_prev + dir_next).normalized()
			if tangent == Vector3.ZERO:
				side = dir_prev.cross(Vector3.UP).normalized() * half_width
			else:
				var miter := tangent.cross(Vector3.UP).normalized()
				var normal_prev := dir_prev.cross(Vector3.UP).normalized()
				var dot_val := miter.dot(normal_prev)

				if abs(dot_val) < 0.001:
					side = normal_prev * half_width
				else:
					var miter_len := half_width / dot_val
					side = miter * miter_len

		mesh.surface_add_vertex(curr + side)
		mesh.surface_add_vertex(curr - side)

	mesh.surface_end()
	return mesh
