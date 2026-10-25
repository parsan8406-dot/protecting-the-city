shader_type canvas_item;
// گنبدِ محافظِ تولد — پنج ثانیه‌ی اولِ هر بار زنده شدن.
//
// حبابِ بلوریِ زرد: وجه‌های تراش‌خورده (مثل نگین)، لبه‌ی نورانی، و یک حلقه‌ی
// نورِ چرخان. تا وقتی این روی بازیکن است، سرور هیچ تیری را روی او قبول
// نمی‌کند (validateHit → InvulnerableUntil)، پس این افکت دقیقاً همان چیزی
// را نشان می‌دهد که واقعاً در بازی اتفاق می‌افتد.
//
// UV صفر تا یک است و مرکزِ حباب (۰.۵,۰.۵). بیرونِ دایره اصلاً کشیده نمی‌شود.

// رنگِ پایه — طلاییِ تمِ بازی
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.24, 1.0);
// ۱ یعنی تازه ساخته شده، ۰ یعنی لحظه‌ی محو شدن
uniform float progress : hint_range(0.0, 1.0) = 1.0;
// چند وجهِ تراش دورِ حباب
uniform float facets = 14.0;
// شفافیتِ کلی. کم است چون بازیکن باید از پشتش دیده شود.
uniform float alpha_scale : hint_range(0.0, 2.0) = 0.85;

// تصادفِ ثابت برای هر وجه، تا وجه‌ها یک‌دست نباشند
float facet_noise(float i) {
	return fract(sin(i * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}

	float ang = atan(p.y, p.x);

	// --- وجه‌های تراش‌خورده ---
	float f = (ang / (2.0 * PI) + 0.5) * facets;
	float fi = floor(f);
	float ff = fract(f);
	// خطِ بینِ دو وجه. نزدیکِ مرکز محو می‌شود، وگرنه همه‌ی خط‌ها وسط جمع
	// می‌شوند و به‌جای نگین، یک ستاره درمی‌آید.
	float facet_edge = smoothstep(0.06, 0.0, min(ff, 1.0 - ff)) * smoothstep(0.30, 0.95, d);
	// هر وجه کمی روشنایی خودش را دارد (نورِ شکسته در بلور)
	float facet_fill = 0.05 + 0.10 * facet_noise(fi);

	// --- لبه‌ی حباب ---
	// توانِ بالا یعنی فقط چند پیکسلِ آخر روشن می‌شود: حسِ شیشه
	float rim = pow(d, 7.0);

	// --- حلقه‌ی نورِ چرخان ---
	float ring = fract(d * 2.2 - TIME * 0.35);
	float ring_edge = smoothstep(0.10, 0.0, min(ring, 1.0 - ring)) * 0.14 * smoothstep(0.2, 0.7, d);

	// --- برقِ چرخان روی سطح ---
	float sweep = smoothstep(0.6, 1.0, sin(ang * 2.0 - TIME * 1.6)) * (1.0 - d) * 0.10;

	float glow = clamp(rim * 1.15 + facet_edge * 0.42 + ring_edge + sweep, 0.0, 1.0);

	// آخرین ثانیه: حباب می‌لرزد و می‌رود. تپشِ سریع یعنی «مواظب باش، تمام شد».
	float fade = smoothstep(0.0, 0.22, progress);
	float blink = 1.0;
	if (progress < 0.22) {
		blink = 0.55 + 0.45 * sin(TIME * 26.0);
	}

	// شفافیت: داخلِ حباب باید بازیکن دیده شود، پس فقط لبه و رگه‌ها جان دارند.
	float a = (facet_fill + glow * 0.75) * alpha_scale * fade * blink;
	a = clamp(a, 0.0, 0.72);

	// رنگ عمداً ضربِ ساده در glow نیست: با ضرب، هر سه کانال از یک جایی به
	// بعد به ۱ می‌رسند و گنبد سفیدِ مات می‌شود (همان چیزی که اول درآمد).
	// حالا فقط لبه‌ی داغ کمی به کهربایی روشن می‌زند و بقیه طلاییِ خودمان است.
	vec3 col = mix(tint.rgb, vec3(1.0, 0.93, 0.66), clamp(glow * 0.55, 0.0, 0.55));
	COLOR = vec4(col, a * tint.a);
}
