// Full-screen pass over the finished frame: the tilt-shift that makes the
// city read as a miniature, and a playful colour grade. Reads the finished
// frame, so it works the same on Forward+ and Compatibility.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// Tilt-shift: the top and bottom of the screen go soft, so the city reads as a
// miniature in the god's hand. tilt_blur is set every frame from camera height.
uniform float tilt_blur = 0.0;      // blur radius in pixels at the edges
uniform float tilt_center = 0.55;   // where the sharp band sits (0 = top, 1 = bottom)
uniform float tilt_width = 0.3;     // height of the sharp band

// Colour grade: a toy-box look, vivid and warm.
uniform float vibrance = 0.3;
uniform float contrast = 1.08;
uniform vec3 warmth = vec3(1.03, 1.0, 0.95);

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	float tilt = tilt_blur * smoothstep(tilt_width * 0.5, tilt_width * 0.5 + 0.35, abs(uv.y - tilt_center));
	if (tilt > 0.1) {
		// Golden-angle disc of 16 taps.
		vec3 acc = c;
		for (int k = 1; k < 16; k++) {
			float fk = float(k);
			float a = fk * 2.39996;
			acc += textureLod(screen_tex, uv + vec2(cos(a), sin(a)) * sqrt(fk / 15.0) * tilt * px, 0.0).rgb;
		}
		c = acc / 16.0;
	}

	// Vibrance lifts dull colours more than vivid ones, then a gentle S-curve.
	float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
	c = mix(vec3(lum(c)), c, 1.0 + vibrance * (1.0 - (mx - mn)));
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0) * warmth;

	COLOR = vec4(c, 1.0);
}
