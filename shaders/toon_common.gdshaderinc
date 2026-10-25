// Soft cel shading for Black & White 3: the "dollhouse in watercolour" look.
// Shared by toon.gdshader (solid) and toon_ghost.gdshader (see-through buildings).
// Every number is driven from data/art_style.tres by scripts/art_style.gd.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float alpha = 1.0;

// Watercolour wash: a seamless noise sampled in world space (triplanar), so
// placeholder boxes and real models both get uneven pigment without UVs.
uniform sampler2D wash_tex : filter_linear_mipmap, repeat_enable;
uniform float wash_scale = 0.08;
uniform float wash_strength = 0.5;
uniform vec3 paper_color : source_color = vec3(0.957, 0.933, 0.886);
uniform float pigment_lift = 0.05;
uniform float saturation = 1.15;

// Three soft light levels. The dark side keeps band_low of the colour.
uniform float band_low = 0.36;
uniform float band_mid = 0.56;
uniform float band_high = 0.68;
uniform float step1 = 0.45;
uniform float step2 = 0.65;
uniform float softness = 0.06;
uniform vec3 shadow_tint : source_color = vec3(0.66, 0.6, 0.82);
// How much of the sky/ambient light reaches the surface (keeps the wash from washing out).
uniform float ambient_amount = 0.45;

varying vec3 v_wpos;
varying vec3 v_wnorm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float wash_at() {
	vec3 b = pow(abs(v_wnorm), vec3(4.0));
	b /= max(b.x + b.y + b.z, 0.0001);
	float x = texture(wash_tex, v_wpos.zy * wash_scale).r;
	float y = texture(wash_tex, v_wpos.xz * wash_scale + vec2(0.37, 0.11)).r;
	float z = texture(wash_tex, v_wpos.xy * wash_scale + vec2(0.71, 0.53)).r;
	return x * b.x + y * b.y + z * b.z;
}

float bands(float t) {
	return band_low
		+ (band_mid - band_low) * smoothstep(step1 - softness, step1 + softness, t)
		+ (band_high - band_mid) * smoothstep(step2 - softness, step2 + softness, t);
}

void fragment() {
	float w = wash_at();
	vec3 col = albedo.rgb;
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	col = clamp(mix(vec3(grey), col, saturation), 0.0, 1.0);
	col = mix(col, paper_color, pigment_lift);
	col *= mix(1.0, 0.8 + 0.4 * w, wash_strength);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	AO = ambient_amount;
	AO_LIGHT_AFFECT = 0.0;
#ifdef GHOST
	ALPHA = alpha;
#endif
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		// Half-lambert into three soft bands; cast shadows drop to the lowest band
		// instead of black, and darker bands lean lavender like a transparent wash.
		float lv = bands(ndl * 0.5 + 0.5);
		lv = mix(band_low, lv, clamp(ATTENUATION, 0.0, 1.0));
		float k = clamp((lv - band_low) / max(band_high - band_low, 0.001), 0.0, 1.0);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lv * mix(shadow_tint, vec3(1.0), k);
	} else {
		// Lamps and fire: soft-edged pools of light.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * smoothstep(0.0, 0.35, ndl) * ATTENUATION;
	}
}
