shader_type canvas_item;
// پرکننده‌ی نوارِ بارگذاری: گرادیانِ قرمز به طلایی، براقیِ بالا، سایه‌ی پایین
// و یک برقِ کم‌رنگ که روی نوار می‌دود.

uniform vec2 rect_size = vec2(400.0, 22.0);
uniform vec4 color_start : source_color = vec4(0.72, 0.06, 0.08, 1.0);
uniform vec4 color_end : source_color = vec4(1.0, 0.8, 0.26, 1.0);

float rounded_mask(vec2 uv) {
	float r = rect_size.y * 0.5;
	vec2 p = (uv - 0.5) * rect_size;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(r));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	return clamp(0.5 - d, 0.0, 1.0);
}

void fragment() {
	vec3 col = mix(color_start.rgb, color_end.rgb, UV.x);
	// براقیِ نیمه‌ی بالا و سایه‌ی لبه‌ی پایین — حسِ برجستگی
	col += vec3(0.28) * (1.0 - smoothstep(0.0, 0.5, UV.y));
	col *= 1.0 - 0.45 * smoothstep(0.55, 1.0, UV.y);
	// برقِ متحرک؛ عرضش به پیکسل ثابت است تا روی نوارِ کوتاه پهن نشود
	float x = UV.x * rect_size.x;
	float band = mod(TIME * 360.0, rect_size.x + 240.0) - 120.0;
	col += vec3(0.35) * (1.0 - smoothstep(0.0, 60.0, abs(x - band)));
	COLOR = vec4(col, rounded_mask(UV));
}
