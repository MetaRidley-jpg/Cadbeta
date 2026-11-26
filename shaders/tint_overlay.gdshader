shader_type canvas_item;
// Challenges "tint" prize: recolors Cadavire with an overlay blend on top of
// whatever she wears (stacks with outfits). Shading and line art stay.
uniform vec4 tint : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 b = COLOR.rgb;
	vec3 t = tint.rgb;
	vec3 lo = 2.0 * b * t;
	vec3 hi = 1.0 - 2.0 * (1.0 - b) * (1.0 - t);
	vec3 o = mix(lo, hi, step(0.5, b));
	COLOR.rgb = mix(b, o, amount);
}
