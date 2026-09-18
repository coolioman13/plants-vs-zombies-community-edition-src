shader_type canvas_item;
// Single material used for all PopCap-style drawing. The per-draw vertex color alpha carries
// an encoded mode: alpha + 4 * (drawMode + 2 * filter)
//   drawMode: 0 = normal, 1 = additive
//   filter:   0 = none, 1 = washed out (imitater), 2 = less washed out, 3 = white, 4 = zombie sun (yellow -> purple)
render_mode blend_premul_alpha;

varying vec4 vc;

void vertex() {
	vc = COLOR;
}

// Port of FilterEffect RGB_to_HSL / HSL_to_RGB so imitater tinting matches the original exactly.
vec3 lum_sat(vec3 c, float lum, float sat) {
	float r = c.r; float g = c.g; float b = c.b;
	float maxval = max(max(r, g), b);
	float minval = min(min(r, g), b);
	float h = 0.0; float s = 0.0;
	float l = (minval + maxval) / 2.0;
	if (l > 0.0) {
		float delta = maxval - minval;
		s = delta;
		if (s > 0.0) {
			s /= (l <= 0.5) ? (minval + maxval) : (2.0 - minval - maxval);
			float r2 = (maxval - r) / delta;
			float g2 = (maxval - g) / delta;
			float b2 = (maxval - b) / delta;
			if (maxval == r) h = (g == minval) ? (5.0 + b2) : (1.0 - g2);
			else if (maxval == g) h = (b == minval) ? (1.0 + r2) : (3.0 - b2);
			else h = (r == minval) ? (3.0 + g2) : (5.0 - r2);
			h /= 6.0;
		}
	}
	s *= sat;
	l *= lum;
	float v = (l <= 0.5) ? (l * (1.0 + s)) : (l + s - l * s);
	if (v <= 0.0) return vec3(0.0);
	float y = 2.0 * l - v;
	float sv = (v - y) / v;
	h *= 6.0;
	float sextant = clamp(floor(h), 0.0, 5.0);
	float vsf = v * sv * (h - sextant);
	float x = y + vsf;
	float z = v - vsf;
	vec3 o;
	if (sextant < 0.5) o = vec3(v, x, y);
	else if (sextant < 1.5) o = vec3(z, v, y);
	else if (sextant < 2.5) o = vec3(y, v, x);
	else if (sextant < 3.5) o = vec3(y, z, v);
	else if (sextant < 4.5) o = vec3(x, y, v);
	else o = vec3(v, y, z);
	return clamp(o, 0.0, 1.0);
}

void fragment() {
	float code = floor((vc.a + 0.0005) / 4.0);
	float a = vc.a - code * 4.0;
	float draw_mode = mod(code, 2.0);
	float filt = floor(code / 2.0 + 0.001);
	vec4 t = texture(TEXTURE, UV);
	vec3 rgb = t.rgb;
	if (filt > 0.5 && filt < 1.5) rgb = lum_sat(rgb, 1.8, 0.2);
	else if (filt > 1.5 && filt < 2.5) rgb = lum_sat(rgb, 1.2, 0.3);
	else if (filt > 2.5 && filt < 3.5) rgb = vec3(1.0);
	else if (filt > 3.5) rgb = vec3(rgb.r * 0.72 + rgb.b * 0.1, rgb.g * 0.28 + rgb.b * 0.25, max(rgb.r, rgb.g) * 0.95 + rgb.b * 0.05);
	vec4 o = vec4(rgb * vc.rgb, t.a * a);
	o.rgb *= o.a;
	if (draw_mode > 0.5) o.a = 0.0;
	COLOR = o;
}
