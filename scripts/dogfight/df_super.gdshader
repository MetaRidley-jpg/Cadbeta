// SEGA "Super Scaler" style ground + sky (Mode-7 with roll).
// Every screen pixel casts a ray from the chase camera; below the horizon it hits the
// flat world (sea level) and samples the painted map in 4 m texels (nearest = chunky).
// Above the horizon: flat sky bands. Distance haze blends into the horizon color.
shader_type canvas_item;

uniform vec3 cam_pos = vec3(0.0, 50.0, 0.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);
uniform float focal = 200.0;
uniform vec2 view_size = vec2(240.0, 346.0);
uniform sampler2D world_map : filter_nearest;
uniform vec2 map_origin = vec2(-1280.0, -1280.0);
uniform float map_m = 4.0;
uniform float map_px = 640.0;
uniform vec4 sea_deep : source_color = vec4(0.04, 0.24, 0.57, 1.0);
uniform vec4 sea : source_color = vec4(0.06, 0.44, 0.84, 1.0);
uniform vec4 sea_light : source_color = vec4(0.13, 0.71, 1.0, 1.0);
uniform vec4 sky_top : source_color = vec4(0.11, 0.44, 0.88, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.31, 0.66, 1.0, 1.0);
uniform vec4 horizon : source_color = vec4(0.66, 0.86, 1.0, 1.0);
uniform vec4 fog : source_color = vec4(0.66, 0.86, 1.0, 0.55);
uniform float fog_end = 2400.0;
// daylight on the ground (weather preset "ambient"): land, sand and the shallows take it;
// the open sea already has per-weather colors; lava is light and ignores it
uniform vec4 ambient : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const vec3 FOAM = vec3(0.902, 0.984, 1.0);
// beach v2 (T's reference: a tropical cove): white sand, lush jungle, mossy dark rock
const vec3 SAND_WET = vec3(0.84, 0.83, 0.75);
const vec3 SAND = vec3(0.97, 0.95, 0.87);
const vec3 GRASS_L = vec3(0.30, 0.70, 0.27);
const vec3 GRASS = vec3(0.16, 0.52, 0.21);
const vec3 GRASS_D = vec3(0.09, 0.36, 0.17);
const vec3 ROCK = vec3(0.29, 0.36, 0.30);
// shallows, shore -> deep: sand under clear water, bright emerald, emerald, teal
const vec3 SH_0 = vec3(0.62, 0.97, 0.86);
const vec3 SH_1 = vec3(0.22, 0.88, 0.66);
const vec3 SH_2 = vec3(0.07, 0.72, 0.55);
const vec3 SH_3 = vec3(0.04, 0.55, 0.60);
const vec3 REEF = vec3(0.05, 0.30, 0.26);
const vec3 CAUSTIC = vec3(0.88, 1.0, 0.95);
const vec3 VOLC = vec3(0.231, 0.153, 0.278);
const vec3 SCORCH = vec3(0.235, 0.137, 0.161);
const vec3 LAVA = vec3(1.0, 0.302, 0.0);
const vec3 LAVA_HOT = vec3(1.0, 0.78, 0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec4 texel(vec2 m) {
	return texelFetch(world_map, ivec2(clamp(m, vec2(0.0), vec2(map_px - 1.0))), 0);
}

void fragment() {
	vec2 pix = floor(UV * view_size) + 0.5;
	vec2 s = pix - view_size * 0.5;
	vec3 dir = normalize(cam_fwd * focal + cam_right * s.x - cam_up * s.y);
	if (dir.y > -0.002) {
		// sky: flat bands, no gradients
		float e = dir.y;
		vec3 c = e < 0.05 ? horizon.rgb : (e < 0.22 ? sky_mid.rgb : sky_top.rgb);
		COLOR = vec4(c, 1.0);
	} else {
		float t = cam_pos.y / -dir.y;
		vec3 hit = cam_pos + dir * t;
		vec2 m = floor((hit.xz - map_origin) / map_m);
		vec3 col;
		float band = -1.0;
		if (m.x >= 0.0 && m.y >= 0.0 && m.x < map_px && m.y < map_px) {
			vec4 d = texel(m);
			band = floor(d.r * 255.0 + 0.5);
			float g = floor(d.g * 255.0 + 0.5);
			if (band < 0.5) {
				band = 0.0;
			} else if (g > 1.5) {
				col = mix(LAVA, LAVA_HOT, step(0.6, hash(m + floor(TIME * 5.0))));
			} else if (g > 0.5) {
				col = SCORCH;
			} else if (band < 1.5) { col = SAND_WET; }
			else if (band < 2.5) { col = SAND; }
			else if (band < 3.5) { col = GRASS_L; }
			else if (band < 4.5) { col = GRASS; }
			else if (band < 5.5) { col = GRASS_D; }
			else if (band < 6.5) { col = ROCK; }
			else { col = VOLC; }
			if (g < 1.5) { col *= ambient.rgb; }
			// speed texture: two-tone checker on land, like the old arcade floors
			if (band > 0.5 && g < 0.5 && hash(m) > 0.72) { col *= band < 2.5 ? 0.94 : 0.86; }
		} else {
			band = 0.0;
		}
		if (band < 0.5) {
			vec2 q = floor(hit.xz / map_m) * map_m;
			float big = sin(q.x * 0.004 + TIME * 0.2) + sin(q.y * 0.005 - TIME * 0.15);
			col = big < -1.3 ? sea_deep.rgb : sea.rgb;
			float swell = q.y * 0.03 + sin(q.x * 0.013 + TIME * 0.9) * 2.0 + TIME * 2.0;
			float crest = step(0.93, fract(swell / 6.2832)) * step(0.4, fract(q.x * 0.009 + floor(swell / 6.2832) * 0.37));
			// depth near islands (B channel): clear emerald shallows over white sand
			float depth = 1.0;
			if (m.x >= 0.0 && m.y >= 0.0 && m.x < map_px && m.y < map_px) {
				float bd = floor(texel(m).b * 255.0 + 0.5);
				if (bd > 0.5) { depth = (bd - 1.0) / 254.0; }
			}
			float day = clamp(dot(ambient.rgb, vec3(0.333)), 0.0, 1.0);
			if (depth < 1.0) {
				float dd = depth + (hash(m * 1.7) - 0.5) * 0.05;          // dithered band edges
				vec3 sh = dd < 0.07 ? SH_0 : (dd < 0.2 ? SH_1 : (dd < 0.38 ? SH_2 : (dd < 0.62 ? SH_3 : col)));
				// weather: the clear-water colors need daylight. In storm / at night they sink
				// toward this weather's own sea color, so the shallows never glow against it.
				if (dd < 0.62) { sh = mix(col, sh * ambient.rgb, 0.3 + 0.7 * day * day); }
				// reef / rock patches on the bottom in the mid shallows
				float rn = sin(q.x * 0.021 + 1.3) * sin(q.y * 0.017 - 0.4) + sin((q.x + q.y) * 0.011);
				if (dd > 0.12 && dd < 0.55 && rn > 0.95) { sh = mix(sh, REEF, 0.55); }
				col = sh;
				// caustics: a moving net of light on the bottom, chunky 2 m cells
				if (dd < 0.6) {
					vec2 cq = floor(hit.xz / 2.0) * 2.0 * 0.07;
					float ca = sin(cq.x * 1.3 + TIME * 1.1 + sin(cq.y * 0.9 + TIME * 0.7) * 1.6);
					float cb = sin(cq.y * 1.1 - TIME * 0.9 + sin(cq.x * 0.8 - TIME * 0.6) * 1.6);
					float net = 1.0 - abs(ca + cb) * 0.5;
					float lit = step(0.86, net) * (1.0 - dd / 0.6) * day * day;   // no sun, no caustics
					col = mix(col, CAUSTIC, lit * 0.75);
				}
				crest *= smoothstep(0.35, 0.8, dd);                         // no open-sea swell lines in the shallows
			}
			col = mix(col, sea_light.rgb, crest);
			// shore foam: any land in the 4 neighbours; it laps in and out
			if (m.x > 0.0 && m.y > 0.0 && m.x < map_px - 1.0 && m.y < map_px - 1.0) {
				float land = texel(m + vec2(1.0, 0.0)).r + texel(m - vec2(1.0, 0.0)).r + texel(m + vec2(0.0, 1.0)).r + texel(m - vec2(0.0, 1.0)).r;
				if (land > 0.001) {
					vec3 foam_c = mix(sea_light.rgb, FOAM * ambient.rgb, 0.4 + 0.6 * day);
					col = fract(TIME * 0.35 + hash(floor(m / 3.0)) * 0.5) < 0.7 ? foam_c : mix(col, SH_0 * ambient.rgb, day);
				}
			}
		}
		// distance haze into the horizon band
		float k = clamp(t / fog_end, 0.0, 1.0);
		col = mix(col, fog.rgb, fog.a * k * k);
		col = mix(col, horizon.rgb, smoothstep(0.7, 1.0, k));
		COLOR = vec4(col, 1.0);
	}
}
