shader_type canvas_item;
render_mode unshaded;

// نشانگر محدوده‌ی بمب (AoE telegraph).
//
// تکنیک پایه همان روش شناخته‌شده‌ی signed-distance است: فاصله‌ی هر پیکسل تا
// مرکز را می‌گیریم و از رویش حلقه/پرشدگی می‌سازیم. تفاوتش با نمونه‌های ساده
// این است که به‌جای if های تیز، همه‌جا smoothstep با پهنای fwidth استفاده
// می‌شود تا لبه‌ها روی موبایل هم صاف و بدون پله باشند.
//
// progress از GDScript هر فریم ست می‌شود (۰ = تازه افتاده، ۱ = لحظه‌ی انفجار)
// پس موجِ پرشونده دقیقاً با فیوز واقعی بمب هماهنگ است.

uniform vec4 col_edge : source_color = vec4(1.0, 0.16, 0.09, 1.0);
uniform vec4 col_fill : source_color = vec4(1.0, 0.30, 0.06, 1.0);
uniform vec4 col_sweep : source_color = vec4(1.0, 0.80, 0.22, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float ring_w : hint_range(0.005, 0.3) = 0.055;
uniform float ticks = 28.0;
uniform float spin = 0.35;

const float TAU_C = 6.2831853;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;              // ۰ در مرکز، ۱ روی لبه
	float aa = max(fwidth(d) * 1.4, 0.0025);

	float inside = 1.0 - smoothstep(1.0 - aa, 1.0, d);

	// ۱) بدنه‌ی کل محدوده — هرچه به انفجار نزدیک‌تر، پررنگ‌تر
	float body = inside * mix(0.14, 0.30, progress);

	// ۲) موجِ پرشونده‌ی شمارش معکوس: از مرکز تا لبه بزرگ می‌شود
	float sweep = (1.0 - smoothstep(progress - aa * 2.0, progress, d)) * inside;
	// لبه‌ی روشنِ خودِ موج
	float sweep_edge = smoothstep(progress - 0.07, progress, d)
	                 * (1.0 - smoothstep(progress, progress + aa * 2.0, d)) * inside;

	// ۳) حلقه‌ی بیرونی
	float ring = smoothstep(1.0 - ring_w - aa, 1.0 - ring_w, d)
	           * (1.0 - smoothstep(1.0 - aa, 1.0, d));

	// ۴) خط‌چین‌های چرخان روی حلقه (حسِ «هدف‌گیری فعال»)
	float ang = atan(p.y, p.x);
	float seg = fract((ang / TAU_C) * ticks + TIME * spin);
	ring *= mix(0.30, 1.0, step(0.45, seg));

	// ۵) نبض که هرچه به انفجار نزدیک‌تر می‌شویم تندتر می‌زند.
	// دامنه هم کم و پایه بالا می‌رود تا لحظه‌ی آخر حلقه پرنور و ثابت بماند،
	// نه این‌که درست سر بزنگاه در فاز خاموشِ نبض محو شود.
	float pulse = mix(0.70, 0.96, progress)
	            + mix(0.30, 0.06, progress) * sin(TIME * mix(7.0, 30.0, progress));

	vec3 rgb = col_fill.rgb;
	float a = body;

	rgb = mix(rgb, col_sweep.rgb, clamp(sweep * 0.35 + sweep_edge, 0.0, 1.0));
	a = max(a, sweep * 0.20);
	a = max(a, sweep_edge * 0.85);

	rgb = mix(rgb, col_edge.rgb, ring);
	a = max(a, ring * pulse);

	COLOR = vec4(rgb, clamp(a, 0.0, 1.0) * fade);
}
