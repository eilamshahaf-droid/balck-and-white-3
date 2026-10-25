// Full-screen watercolour pass: soft colour bleed, pigment that pools at edges
// instead of black outlines, granulation, a slight hand-painted wobble, paper
// texture, and borders that melt into the paper. Reads the finished frame, so
// it works the same on Forward+ and Compatibility and also covers see-through
// buildings and effects.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D paper_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 paper_color : source_color = vec3(0.957, 0.933, 0.886);
uniform float bleed = 0.15;
uniform float edge_strength = 0.3;
uniform float edge_threshold = 0.12;
uniform float grain = 0.025;
uniform float paper_strength = 0.025;
uniform float wobble = 0.0012;
uniform float vignette = 0.03;

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	float aspect = px.y / px.x;
	vec2 base = SCREEN_UV;
	vec2 wob = vec2(
		texture(paper_noise, base * vec2(aspect, 1.0) * 0.9).r,
		texture(paper_noise, base * vec2(aspect, 1.0) * 0.9 + vec2(0.5, 0.25)).r) - 0.5;
	vec2 uv = base + wob * wobble * 2.0;

	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 r = textureLod(screen_tex, uv + vec2(px.x, 0.0), 0.0).rgb;
	vec3 l = textureLod(screen_tex, uv - vec2(px.x, 0.0), 0.0).rgb;
	vec3 u = textureLod(screen_tex, uv + vec2(0.0, px.y), 0.0).rgb;
	vec3 d = textureLod(screen_tex, uv - vec2(0.0, px.y), 0.0).rgb;
	vec3 blur = (textureLod(screen_tex, uv + vec2(2.0 * px.x, 0.0), 0.0).rgb
		+ textureLod(screen_tex, uv - vec2(2.0 * px.x, 0.0), 0.0).rgb
		+ textureLod(screen_tex, uv + vec2(0.0, 2.0 * px.y), 0.0).rgb
		+ textureLod(screen_tex, uv - vec2(0.0, 2.0 * px.y), 0.0).rgb) * 0.25;
	c = mix(c, blur, bleed);

	// Pigment pools where colours meet: darken towards the colour itself, never black.
	float e = abs(lum(r) - lum(l)) + abs(lum(u) - lum(d)) + 0.5 * (length(r - l) + length(u - d));
	float edge = smoothstep(edge_threshold, edge_threshold * 3.0, e);
	float patchy = texture(paper_noise, base * vec2(aspect, 1.0) * 3.0).r;
	c = mix(c, c * c * 0.9, edge * edge_strength * (0.6 + 0.8 * patchy));

	// Granulation (fine, settles in the darker washes) and the paper itself.
	float g = texture(paper_noise, FRAGCOORD.xy / 180.0).r;
	c *= 1.0 - (g - 0.5) * grain * 2.0 * (1.0 - lum(c) * 0.5);
	float p = texture(paper_noise, FRAGCOORD.xy / 700.0 + vec2(0.3, 0.7)).r;
	c *= mix(1.0 - paper_strength, 1.0 + paper_strength * 0.4, p);

	// Edges of the screen dissolve into paper, unevenly like a wet border.
	float m = min(min(base.x, 1.0 - base.x) * aspect, min(base.y, 1.0 - base.y));
	float v = smoothstep(0.0, vignette, m + (wob.x) * vignette * 0.8);
	c = mix(paper_color, c, v);

	COLOR = vec4(c, 1.0);
}
