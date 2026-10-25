shader_type canvas_item;
render_mode unshaded, blend_add;

// هاله‌ی شیطانِ وسطِ زمین.
//
// همه‌چیز از روی فاصله تا مرکز (d) و زاویه (ang) ساخته می‌شود — نه بافت و نه
// نویزِ گران. روی رندررِ gl_compatibility و گوشیِ ضعیف هم یک کوآدِ ساده است.
//
// چهار لایه روی هم:
//   ۱. هاله‌ی نرم که نفس می‌کشد (تنها چیزی که از دور دیده می‌شود)
//   ۲. دو حلقه‌ی رونیِ خط‌چین که خلافِ هم می‌چرخند
//   ۳. زبانه‌های انرژی که از بیرون به سمتِ مرکز کشیده می‌شوند
//   ۴. مغزِ داغِ وسط
//
// blend_add است چون زمین تاریک است: هاله باید نور اضافه کند، نه روی
// چیزی بیفتد.

uniform vec4 col_core : source_color = vec4(1.0, 0.88, 0.58, 1.0);
uniform vec4 col_mid  : source_color = vec4(1.0, 0.34, 0.10, 1.0);
uniform vec4 col_rim  : source_color = vec4(0.88, 0.08, 0.26, 1.0);

// شدتِ کلی. GDScript با آن نفسِ آرام و تپشِ تندِ «زخم خورد» را می‌سازد.
uniform float energy : hint_range(0.0, 3.0) = 1.0;
// سرعتِ چرخشِ حلقه‌ها
uniform float spin = 0.55;
// چند خط‌چین روی هر حلقه
uniform float runes = 13.0;
// ۰ تا ۱ — لحظه‌ی ضربه خوردن، کلِ هاله سفید-داغ می‌شود
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
// ۰ زنده، ۱ مرده: هاله فرو می‌ریزد
uniform float death : hint_range(0.0, 1.0) = 0.0;

const float TAU_C = 6.2831853;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;                 // ۰ مرکز، ۱ لبه‌ی کوآد
	float ang = atan(p.y, p.x);
	float aa = max(fwidth(d) * 1.4, 0.0025);
	float inside = 1.0 - smoothstep(1.0 - aa * 2.0, 1.0, d);

	// با مرگ، همه‌چیز به سمتِ مرکز جمع و خاموش می‌شود
	float shrink = mix(1.0, 0.25, death);
	d /= max(shrink, 0.05);

	// --- ۱) هاله‌ی نفس‌کش ---
	float breath = 0.86 + 0.14 * sin(TIME * 1.35);
	float halo = pow(max(1.0 - d, 0.0), 2.6) * breath;

	// --- ۲) دو حلقه‌ی رونی، خلافِ هم ---
	float r1 = 0.58;
	float r2 = 0.80;
	float w1 = 0.035;
	float w2 = 0.022;
	float ring1 = 1.0 - smoothstep(0.0, w1, abs(d - r1));
	float ring2 = 1.0 - smoothstep(0.0, w2, abs(d - r2));
	// خط‌چین: نیمی از هر قطاع روشن است
	float seg1 = fract((ang / TAU_C) * runes + TIME * spin);
	float seg2 = fract((ang / TAU_C) * (runes * 1.6) - TIME * spin * 0.72);
	ring1 *= mix(0.12, 1.0, step(0.42, seg1));
	ring2 *= mix(0.10, 1.0, step(0.50, seg2));

	// --- ۳) زبانه‌های انرژی که به مرکز کشیده می‌شوند ---
	// موجِ شعاعی که به سمتِ داخل می‌آید، ضرب‌در یک الگوی زاویه‌ای
	float flow = fract(d * 2.6 - TIME * 0.62);
	float wisp = pow(1.0 - flow, 6.0);
	float lobes = 0.5 + 0.5 * sin(ang * 7.0 + TIME * 0.9);
	wisp *= smoothstep(0.18, 0.55, d) * (1.0 - smoothstep(0.86, 1.0, d)) * lobes;

	// --- ۴) مغزِ داغ ---
	float core = pow(max(1.0 - d * 2.6, 0.0), 2.0);

	// --- ترکیب ---
	//
	// روی blend_add و زمینِ سیاه، رنگِ تیره عملاً دیده نمی‌شود: هرچه اضافه
	// می‌کنی نزدیکِ صفر است. پس هر لایه رنگِ خودش را کاملاً می‌گیرد (mix با
	// وزنِ خودِ لایه) و آلفاها سخاوتمندند — وگرنه هاله فقط یک لکه‌ی
	// خاکستریِ محو می‌شد.
	vec3 rgb = col_rim.rgb;
	rgb = mix(rgb, col_mid.rgb, clamp(halo * 1.8 + wisp * 1.2, 0.0, 1.0));
	rgb = mix(rgb, col_mid.rgb * 1.25, clamp(ring1, 0.0, 1.0));
	rgb = mix(rgb, col_core.rgb, clamp(core * 1.4 + ring2, 0.0, 1.0));
	// ضربه که خورد، یک فریمِ سفیدِ داغ
	rgb = mix(rgb, vec3(1.0, 0.95, 0.88), hurt * 0.85);

	float a = halo * 0.92 + ring1 * 0.95 + ring2 * 0.68 + wisp * 0.72 + core * 1.0;
	a *= energy * inside * (1.0 - death * 0.6);
	a += hurt * halo * 1.1;

	COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
