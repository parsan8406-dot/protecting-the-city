shader_type canvas_item;
render_mode unshaded;

// اخطارِ نفرینِ شیطان — «این‌جا دو ثانیه‌ی دیگر می‌ترکد».
//
// خویشاوندِ aoe_zone (نشانگرِ بمب) است ولی کارش فرق دارد و عمداً هم فرق
// دارد: بمب را خودت انداخته‌ای، پس نشانگرش فقط باید بگوید «کجا». این یکی
// را دشمن انداخته و تو باید در دو ثانیه بفهمی و فرار کنی، پس باید داد بزند:
//
//   • حلقه‌ی بیرونی ثابت می‌ماند (مرزِ خطر — همیشه معلوم است تا کجا امن است)
//   • یک حلقه‌ی دوم از بیرون به مرکز فرو می‌ریزد؛ رسیدنش به مرکز = انفجار
//   • رونِ چرخان + پره‌های مثلثی که رو به داخل اشاره می‌کنند
//   • چشمکی که هرچه به آخر نزدیک‌تر، تندتر و قرمزتر
//
// progress از GDScript هر فریم ست می‌شود: ۰ لحظه‌ی علامت خوردن، ۱ لحظه‌ی
// انفجار. پس هرچه روی صفحه دیده می‌شود دقیقاً با تایمرِ سرور هماهنگ است.

uniform vec4 col_ring : source_color = vec4(1.0, 0.13, 0.20, 1.0);
uniform vec4 col_fill : source_color = vec4(0.62, 0.03, 0.12, 1.0);
uniform vec4 col_hot  : source_color = vec4(1.0, 0.72, 0.30, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float runes = 18.0;
uniform float spin = 0.9;

const float TAU_C = 6.2831853;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float ang = atan(p.y, p.x);
	float aa = max(fwidth(d) * 1.4, 0.0025);
	float inside = 1.0 - smoothstep(1.0 - aa, 1.0, d);

	// --- ۱) بدنه: کم‌رنگ شروع می‌شود و تا آخر پررنگ می‌شود ---
	float body = inside * mix(0.10, 0.34, progress * progress);

	// --- ۲) حلقه‌ی مرزی ثابت ---
	float edge = 1.0 - smoothstep(0.0, 0.055, abs(d - 0.96));

	// --- ۳) حلقه‌ی فروریزنده: از لبه تا مرکز ---
	// نمای نمایی تا آخرِ کار سریع‌تر جمع شود — حسِ «وقت تمام شد»
	float collapse = mix(0.96, 0.0, pow(progress, 1.35));
	float ring = 1.0 - smoothstep(0.0, 0.05, abs(d - collapse));
	ring *= inside;
	// دنباله‌ی محوِ پشتِ حلقه‌ی فروریزنده
	float trail = smoothstep(collapse, collapse + 0.30, d)
	            * (1.0 - smoothstep(0.92, 1.0, d)) * 0.28;

	// --- ۴) رون‌های چرخان روی مرز ---
	float seg = fract((ang / TAU_C) * runes + TIME * spin);
	edge *= mix(0.22, 1.0, step(0.46, seg));

	// --- ۵) چهار پره‌ی مثلثی که رو به مرکز اشاره می‌کنند ---
	// با نزدیک شدن به انفجار، به سمتِ داخل سُر می‌خورند
	float spokes = 0.0;
	float sa = abs(fract(ang / TAU_C * 4.0 + 0.5) - 0.5) * 2.0;   // ۰ روی محورها
	float tip = mix(0.88, 0.30, progress);
	float band = 1.0 - smoothstep(0.0, 0.16, abs(d - tip));
	spokes = band * (1.0 - smoothstep(0.0, 0.42, sa)) * inside;

	// --- ۶) چشمکِ شتاب‌گیرنده ---
	float blink = 0.62 + 0.38 * sin(TIME * mix(6.0, 34.0, progress));

	vec3 rgb = col_fill.rgb;
	rgb = mix(rgb, col_ring.rgb, clamp(edge + ring * 0.8, 0.0, 1.0));
	rgb = mix(rgb, col_hot.rgb, clamp(ring * 0.7 + spokes * 0.8, 0.0, 1.0));

	float a = body;
	a = max(a, trail * inside);
	a = max(a, edge * blink * 0.95);
	a = max(a, ring * 0.95);
	a = max(a, spokes * mix(0.35, 0.85, progress));

	COLOR = vec4(rgb, clamp(a, 0.0, 1.0) * fade);
}
