shader_type canvas_item;
// Turns the low-resolution 3D render into "pixel art":
// a limited number of colour steps with ordered (Bayer) dithering.

uniform float levels : hint_range(2.0, 32.0) = 10.0;
uniform float dither : hint_range(0.0, 2.0) = 0.9;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	int idx = (p.x & 3) + ((p.y & 3) * 4);
	float t = (BAYER[idx] / 16.0 - 0.5) * dither / levels;
	COLOR = vec4(floor((c.rgb + t) * levels + 0.5) / levels, 1.0);
}
