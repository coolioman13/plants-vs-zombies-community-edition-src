shader_type canvas_item;
// GPU port of PoolEffect::UpdateWaterEffect + BilinearLookupFixedPoint (same integer math),
// sampled like the original 128x64 caustic texture (bilinear filtering, wrap addressing).
render_mode blend_mix;

uniform sampler2D caustic_gray : filter_nearest, repeat_enable;
uniform int pool_counter = 0;

varying vec4 vc;

void vertex() {
	vc = COLOR;
}

uint gray_at(uint ix, uint iy) {
	return uint(texelFetch(caustic_gray, ivec2(int(ix), int(iy)), 0).r * 255.0 + 0.5);
}

uint lookup(uint u, uint v) {
	uint time_u = u & 0xFFFF0000u;
	uint time_v = v & 0xFFFF0000u;
	uint fu1 = ((u - time_u) & 0x0000FFFEu) + 1u;
	uint fv1 = ((v - time_v) & 0x0000FFFEu) + 1u;
	uint fu0 = 65536u - fu1;
	uint fv0 = 65536u - fv1;
	uint iu0 = (time_u >> 16u) % 256u;
	uint iu1 = ((time_u >> 16u) + 1u) % 256u;
	uint iv0 = (time_v >> 16u) % 256u;
	uint iv1 = ((time_v >> 16u) + 1u) % 256u;
	return (((fu0 * fv1) / 65536u) * gray_at(iu0, iv1)) / 65536u
		+ (((fu1 * fv1) / 65536u) * gray_at(iu1, iv1)) / 65536u
		+ (((fu0 * fv0) / 65536u) * gray_at(iu0, iv0)) / 65536u
		+ (((fu1 * fv0) / 65536u) * gray_at(iu1, iv0)) / 65536u;
}

float texel_alpha(int x, int y) {
	int time_v1 = (256 - y) << 17;
	int time_v0 = y << 17;
	int time_u = x << 17;
	int pool0 = pool_counter << 16;
	int pool1 = ((pool_counter & 65535) + 1) << 16;
	uint a1 = lookup(uint(time_u - pool1 / 6), uint(time_v1 + pool0 / 8)) & 255u;
	uint a0 = lookup(uint(time_u + pool0 / 10), uint(time_v0)) & 255u;
	uint a = ((a0 + a1) / 2u) & 255u;
	uint alpha = 0u;
	if (a >= 160u) {
		alpha = (255u - 2u * (a - 160u)) & 255u;
	} else if (a >= 128u) {
		alpha = (5u * (a - 128u)) & 255u;
	}
	return float(alpha / 3u) / 255.0;
}

void fragment() {
	vec2 p = UV * vec2(128.0, 64.0) - vec2(0.5);
	vec2 f = fract(p);
	ivec2 i0 = ivec2(floor(p));
	int x0 = ((i0.x % 128) + 128) % 128;
	int y0 = ((i0.y % 64) + 64) % 64;
	int x1 = (x0 + 1) % 128;
	int y1 = (y0 + 1) % 64;
	float a = mix(mix(texel_alpha(x0, y0), texel_alpha(x1, y0), f.x), mix(texel_alpha(x0, y1), texel_alpha(x1, y1), f.x), f.y);
	COLOR = vec4(vc.rgb, a * vc.a);
}
