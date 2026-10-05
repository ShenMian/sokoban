shader_type spatial;
render_mode cull_front, unshaded;

uniform vec3 color : source_color = vec3(0.0, 0.0, 0.0);
uniform float width : hint_range(0.0, 1.0, 0.01) = 0.05;

void vertex() {
	VERTEX += width * NORMAL;
}

void fragment() {
	ALBEDO = color;
}
