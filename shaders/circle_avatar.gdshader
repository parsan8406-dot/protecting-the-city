shader_type canvas_item;
// آواتار گرد با حلقه‌ی رنگی دور آن — برای صفحه‌ی چت.
// عکس باید مربع باشد و TextureRect روی stretch_mode = SCALE باشد.

uniform vec4 ring_color : source_color = vec4(0.47, 0.56, 0.7, 1.0);
// ضخامت حلقه نسبت به شعاع
uniform float ring_width : hint_range(0.0, 0.3) = 0.07;
// فاصله‌ی تیره‌ی بین حلقه و عکس
uniform float gap_width : hint_range(0.0, 0.2) = 0.035;

// رنگ رأس (شامل modulate نود) — تا محو شدن با modulate:a هنوز کار کند
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float aa = max(fwidth(d), 0.001) * 1.2;
	vec4 tex = texture(TEXTURE, UV);

	float inside = 1.0 - smoothstep(1.0 - aa, 1.0, d);
	float ring = smoothstep(1.0 - ring_width - aa, 1.0 - ring_width, d);
	float gap = smoothstep(1.0 - ring_width - gap_width - aa, 1.0 - ring_width - gap_width, d) * (1.0 - ring);

	vec3 col = mix(tex.rgb, vec3(0.03, 0.05, 0.09), gap);
	col = mix(col, ring_color.rgb, ring);
	float alpha = max(tex.a, max(gap, ring * ring_color.a));
	COLOR = vec4(col, alpha * inside) * v_modulate;
}
