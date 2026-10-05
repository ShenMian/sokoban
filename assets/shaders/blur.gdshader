shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount: hint_range(0.0, 5.0);
uniform float brightness: hint_range(0.0, 2.0) = 1.0;

void fragment() {
	COLOR.rgb = textureLod(screen_texture, SCREEN_UV, amount).rgb * brightness;
}
