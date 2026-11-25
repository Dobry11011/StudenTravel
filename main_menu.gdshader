shader_type canvas_item;

uniform int count: hint_range(0, 2000) = 150;
uniform float slant: hint_range(-0.1, 0.1) = -0.01;
uniform float speed: hint_range(25.0, 100.0) = 50.0;
uniform float blur: hint_range(0.0005, 0.1) = 0.002;
uniform vec4 colour: source_color = vec4(1.0);
uniform vec2 size = vec2(0.005, 0.2);

// The menu mesh has 128 vertical strips. A triangle's flat values may
// come from either edge, so include one strip width on both sides.
const float STRIP_MARGIN = 1.0 / 128.0 + 0.0001;
varying flat int nearby_count;
varying flat ivec4 first_lines;
varying flat ivec4 next_lines;

float line_seed(float i) {
	return fract(sin(i * 18.34) * 51.78);
}

void vertex() {
	VERTEX = UV;
	nearby_count = 0;
	first_lines = ivec4(0);
	next_lines = ivec4(0);
	for (int i = 1; i <= count; i++) {
		float h1 = line_seed(float(i));
		float top = h1 * 1.2;
		float bottom = top - (1.0 + h1) * slant;
		float margin = size.x * 0.1 + STRIP_MARGIN;
		if (UV.x < min(top, bottom) - margin || UV.x > max(top, bottom) + margin) {
			continue;
		}
		if (nearby_count < 4) {
			first_lines[nearby_count] = i;
		} else if (nearby_count < 8) {
			next_lines[nearby_count - 4] = i;
		} else {
			nearby_count++;
			break;
		}
		nearby_count++;
	}
}

float coverage(int index, vec2 uv, float time) {
	float i = float(index);
	float h1 = line_seed(i);
	float h2 = fract(sin(i * 25.42) * 21.24);
	float pos_x = h1 * 1.2;
	float rate = max(h2 * speed, pos_x * speed);
	vec2 center = vec2(pos_x + h1 * uv.y * -slant, -mod(-rate * time * 0.1, -1.0));
	// Outside the rectangle the clamped signed distance contributes zero.
	vec2 inset = size * 0.1 - abs(uv - center);
	return clamp(min(inset.x, inset.y) / blur, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * slant;
	float time = TIME + 1000.0;
	float opacity = 0.0;
	if (nearby_count <= 8) {
		for (int i = 0; i < nearby_count; i++) {
			int index = i < 4 ? first_lines[i] : next_lines[i - 4];
			opacity += coverage(index, uv, time);
		}
	} else {
		// Crowded strips use the full sum, including every overlap.
		for (int i = 1; i <= count; i++) {
			opacity += coverage(i, uv, time);
		}
	}
	COLOR = vec4(colour.rgb, opacity);
}
