extends MeshInstance3D
class_name HeatmapCell

const TRANSPARENCY = 0.7

@onready var label: Label3D = $Label


func setup(lower_bound: int, max_lower_bound: int) -> void:
	assert(max_lower_bound <= max_lower_bound)
	var ratio: float = 0.0 if max_lower_bound == 0 else float(lower_bound) / float(max_lower_bound)
	var color := Color.RED.lerp(Color.BLUE, ratio)
	color.a = TRANSPARENCY

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	set_surface_override_material(0, material)

	label.text = str(lower_bound)
	var digits := label.text.length()
	if digits > 2:
		label.pixel_size *= 2.0 / digits
