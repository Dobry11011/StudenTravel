shader_type canvas_item;

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	bool inside_panel = pixel.x >= 42.0 && pixel.x <= 1236.0
		&& pixel.y >= 134.0 && pixel.y <= 779.0;
	if (!inside_panel) {
		float brightness = max(COLOR.r, max(COLOR.g, COLOR.b));
		COLOR.a *= smoothstep(0.0, 0.045, brightness);
	}
}
