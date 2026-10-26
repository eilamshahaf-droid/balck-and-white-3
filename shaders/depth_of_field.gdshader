// Depth of field like a macro photo of a miniature: whatever stands at the
// distance of the screen's centre stays sharp, and everything further away
// melts softly into the background. Things nearer than the focus (the god's
// hand, a lifted car) stay sharp. Drawn on a screen-covering quad that
// scripts/art_style.gd keeps in front of the camera; the screen
// pass (shaders/screen_pass.gdshader) then reads the result, so the
// tilt-shift blur adds on top.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float blur = 8.0;          // blur radius in pixels far behind the focus
uniform float focus_y = 0.55;      // where on screen the focus is measured (0 = top, 1 = bottom)
uniform float start = 1.15;        // blur starts at this many times the focus distance
uniform float end = 2.2;           // and is full at this many times
uniform bool compat = false;       // Compatibility (OpenGL): depth runs -1..1, see CURVE below
// Compatibility hands this quad the finished picture and then tone maps what
// it draws once more. This curve is that second pass, measured in the city
// (ACES, exposure 1); blurred pixels go through its inverse first. Sharp
// pixels are never redrawn (alpha 0), so they stay exact whatever the curve.
const float CURVE[16] = float[](0.0, 0.0, 0.0706, 0.161, 0.267, 0.376, 0.49, 0.592,
	0.686, 0.765, 0.827, 0.878, 0.922, 0.953, 0.98, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

float dist_of(vec2 uv, float d, mat4 inv_proj) {
	if (compat) {
		d = d * 2.0 - 1.0;
	}
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

float undo_curve(float y) {
	for (int i = 1; i < 16; i++) {
		if (y <= CURVE[i]) {
			float t = (y - CURVE[i - 1]) / max(CURVE[i] - CURVE[i - 1], 0.0001);
			return (float(i - 1) + t) / 15.0;
		}
	}
	return 1.0;
}

// 0 = sharp, 1 = fully blurred.
float coc(float dist, float focus) {
	return smoothstep(focus * start, focus * end, dist);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float focus = min(min(dist_of(vec2(0.5, focus_y), texture(depth_tex, vec2(0.5, focus_y)).r, INV_PROJECTION_MATRIX),
		dist_of(vec2(0.42, focus_y), texture(depth_tex, vec2(0.42, focus_y)).r, INV_PROJECTION_MATRIX)),
		dist_of(vec2(0.58, focus_y), texture(depth_tex, vec2(0.58, focus_y)).r, INV_PROJECTION_MATRIX));
	float k = coc(dist_of(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX), focus);
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (k * blur > 0.3) {
		// Golden-angle disc of 16 taps. A tap only counts as much as it is
		// blurred itself, so sharp near objects never bleed into the background.
		vec3 acc = c;
		float wsum = 1.0;
		for (int i = 1; i < 16; i++) {
			float fi = float(i);
			float a = fi * 2.39996;
			vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * sqrt(fi / 15.0) * k * blur * px;
			float w = coc(dist_of(uv, texture(depth_tex, uv).r, INV_PROJECTION_MATRIX), focus);
			acc += textureLod(screen_tex, uv, 0.0).rgb * w;
			wsum += w;
		}
		c = acc / wsum;
	}
	if (compat) {
		c = vec3(undo_curve(c.r), undo_curve(c.g), undo_curve(c.b));
	}
	ALBEDO = c;
	ALPHA = clamp(k * blur - 0.3, 0.0, 1.0);
}
