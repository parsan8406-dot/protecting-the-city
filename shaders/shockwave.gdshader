shader_type canvas_item;
render_mode unshaded, blend_add;

// موجِ ضربه‌ی انفجار: یک حلقه‌ی نازکِ درخشان که به بیرون باز می‌شود.
// radius و thickness از GDScript انیمیت می‌شوند (باز می‌شود و نازک‌تر می‌شود).

uniform vec4 col : source_color = vec4(1.0, 0.72, 0.32, 1.0);
uniform float radius : hint_range(0.0, 1.0) = 0.4;
uniform float thickness : hint_range(0.002, 0.5) = 0.10;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;

	// نوارِ نرم دور شعاع فعلی
	float band = 1.0 - smoothstep(0.0, thickness, abs(d - radius));
	band *= band;                       // لبه‌ی تیزتر، مرکزِ پرنورتر

	// جلوی بیرون‌زدن از مربعِ نود را می‌گیرد
	float inside = 1.0 - smoothstep(0.97, 1.0, d);

	COLOR = vec4(col.rgb, band * fade * inside);
}
