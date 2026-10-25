shader_type canvas_item;

// پترن تفنگی پس‌زمینه‌ی صفحه‌ی چت.
//
// یک شبکه‌ی مورب از فشنگ و ضامن (crosshair) می‌کشد با همان تم بازی:
// زمینه‌ی سیاه، خط‌های طلایی و لکه‌های قرمز. همه‌چیز محاسباتی است
// (بدون تکسچر) تا روی هر رزولوشنی تمیز بماند و حجم اضافه نکند.

uniform vec4 bg_color : source_color = vec4(0.043, 0.043, 0.047, 1.0);
uniform vec4 gold_color : source_color = vec4(0.85, 0.65, 0.20, 1.0);
uniform vec4 red_color : source_color = vec4(0.75, 0.13, 0.13, 1.0);

// اندازه‌ی هر خانه‌ی پترن به پیکسل — بزرگ‌تر یعنی نقش‌های درشت‌تر
uniform float cell_size = 132.0;
// پررنگی کل پترن؛ عمداً کم است تا متن چت خوانا بماند
uniform float pattern_alpha = 0.15;
// زاویه‌ی چرخش شبکه (درجه)
uniform float tilt_degrees = -22.0;
// سرعت سُر خوردن آرام پترن (پیکسل بر ثانیه)
uniform float drift_speed = 4.0;
// شدت تاریک شدن گوشه‌ها
uniform float vignette_strength = 0.55;

// ---------------------------------------------------------------- کمکی‌ها

// hash شبه‌تصادفی برای اینکه خانه‌ها شبیه هم نباشند
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// فاصله‌ی علامت‌دار تا یک مستطیل
float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// فاصله‌ی علامت‌دار تا یک حلقه
float sd_ring(vec2 p, float radius, float width) {
	return abs(length(p) - radius) - width;
}

// شکل فشنگ: پوکه‌ی مستطیلی + نوکِ بیضی، رو به بالا
float sd_bullet(vec2 p) {
	float casing = sd_box(p - vec2(0.0, -0.17), vec2(0.075, 0.20)) - 0.025;

	vec2 nose = p - vec2(0.0, 0.04);
	nose.y *= 0.52;
	float tip = length(nose) - 0.098;

	// خط طوقه‌ی ته پوکه
	float rim = sd_box(p - vec2(0.0, -0.36), vec2(0.105, 0.022)) - 0.01;

	return min(min(casing, tip), rim);
}

// شکل ضامن/نشانه‌گیری: یک حلقه با چهار خط صلیبی
float sd_crosshair(vec2 p) {
	float ring = sd_ring(p, 0.24, 0.018);
	float bar_h = sd_box(p, vec2(0.34, 0.014));
	float bar_v = sd_box(p, vec2(0.014, 0.34));
	// وسط صلیب خالی می‌ماند تا شبیه دوربین اسلحه شود
	float gap = 0.10 - length(p);
	float bars = max(min(bar_h, bar_v), -gap);
	return min(ring, bars);
}

// تبدیل فاصله به پوششِ نرم (anti-alias مستقل از رزولوشن)
float fill(float dist, float softness) {
	return 1.0 - smoothstep(0.0, softness, dist);
}

// ---------------------------------------------------------------- فرگمنت

void fragment() {
	// مختصات پیکسلی، چرخیده و در حال سُر خوردن آرام
	float angle = radians(tilt_degrees);
	float cs = cos(angle);
	float sn = sin(angle);
	vec2 p = FRAGCOORD.xy;
	p = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
	p += vec2(drift_speed, drift_speed * 0.45) * TIME;

	// شبکه‌ی آجرچین: ردیف‌های فرد نصف خانه جابه‌جا می‌شوند
	vec2 grid = p / cell_size;
	float row = floor(grid.y);
	grid.x += mod(row, 2.0) * 0.5;

	vec2 cell_id = vec2(floor(grid.x), row);
	vec2 local = fract(grid) - 0.5;

	float variant = hash21(cell_id);
	float spin = (hash21(cell_id + 7.13) - 0.5) * 0.9;

	// چرخش کوچک هر نقش نسبت به خانه‌ی خودش
	float rc = cos(spin);
	float rs = sin(spin);
	vec2 q = vec2(local.x * rc - local.y * rs, local.x * rs + local.y * rc);

	// حدود یک‌سوم خانه‌ها ضامن‌اند، بقیه فشنگ
	float dist = variant < 0.34 ? sd_crosshair(q * 1.35) : sd_bullet(q * 1.55);

	float softness = 0.012;
	float shape = fill(dist, softness);
	// هاله‌ی محوِ دور هر نقش، برای عمق
	float glow = fill(dist - 0.045, 0.09) * 0.35;

	// یک‌ششم نقش‌ها قرمزند، بقیه طلایی
	vec3 ink = variant > 0.83 ? red_color.rgb : gold_color.rgb;

	vec3 color = bg_color.rgb;
	color = mix(color, ink, (shape + glow) * pattern_alpha);

	// تاریک شدن گوشه‌ها تا وسط صفحه (محل خواندن پیام‌ها) روشن‌تر بماند
	vec2 centered = UV - 0.5;
	float vignette = 1.0 - vignette_strength * dot(centered, centered) * 2.4;
	color *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(color, bg_color.a);
}
