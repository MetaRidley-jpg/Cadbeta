shader_type canvas_item;
// Dogfight units layer. Jet pixels baked with alpha 250/255 are VISOR pixels
// (DfSprites.VISOR_ALPHA): a red stepped shimmer scrolls across them. The original
// pixel brightness is kept, so the visor keeps its shading. Other draws pass through.
uniform float speed = 1.6;

vec3 band(float s) {
	// T's cyclops visor: red shimmer in 5 flat steps (pixel look):
	// deep crimson -> red -> hot pink-white -> orange-red -> crimson
	float k = floor(fract(s) * 5.0);
	if (k < 1.0) return vec3(0.45, 0.02, 0.10);
	if (k < 2.0) return vec3(1.00, 0.08, 0.20);
	if (k < 3.0) return vec3(1.00, 0.85, 0.88);
	if (k < 4.0) return vec3(1.00, 0.35, 0.18);
	return vec3(0.80, 0.04, 0.16);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a > 0.975 && t.a < 0.99) {
		float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
		float s = (FRAGCOORD.x + FRAGCOORD.y * 0.6) * 0.05 - TIME * speed;
		vec3 g = band(s) * (0.7 + lum * 0.5);
		COLOR = vec4(g, COLOR.a / t.a);
	}
}
