shader_type canvas_item;
render_mode unshaded;

// پفِ دودِ کارتونیِ ناک‌اوت (سبکِ «پوف!» کارتون‌ها، نه دودِ واقع‌گرا).
//
// تکنیک همان «فرسایشِ آلفا» (alpha erosion) در افکت‌های استایلایز است:
// پف محو نمی‌شود، بلکه با یک نویز از لبه‌ها و نقطه‌های کم‌نویز «خورده»
// می‌شود تا تکه‌تکه ناپدید شود — لبه همیشه تیز می‌ماند و کارتونی دیده می‌شود.
// سایه‌زنیِ دو‌رنگِ (toon) نور از بالا-چپ به پف حجم می‌دهد.
//
// داده‌ی هر پف از modulateِ خودِ نود می‌آید تا همه‌ی پف‌ها یک متریال مشترک
// داشته باشند (در Godot 4، COLORِ vertex یعنی رنگِ رأس × modulate):
//   modulate.a  = ۱ − مقدارِ فرسایش (۱ یعنی پفِ کامل، ۰ یعنی کاملاً خورده‌شده)
//   modulate.r  = بذرِ نویز، تا دو پف شبیهِ هم خورده نشوند
// برای همین رنگِ واقعیِ پف فقط از uniformها می‌آید، نه از modulate.
//
// outline_only روشن = همان پف، یکدست به رنگِ خطِ دور. این نسخه کمی
// بزرگ‌تر پشتِ پف‌های اصلی کشیده می‌شود تا کلِ ابر یک خطِ دورِ یکپارچه
// داشته باشد (نه دایره‌ای جدا دورِ تک‌تکِ پف‌ها).

uniform vec4 fill_color : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 shade_color : source_color = vec4(0.72, 0.70, 0.84, 1.0);
uniform vec4 outline_color : source_color = vec4(0.17, 0.13, 0.23, 1.0);
uniform bool outline_only = false;
uniform float noise_scale = 2.6;
// سهمِ نویز در شکلِ فرسایش؛ صفر یعنی پف فقط یکدست کوچک می‌شود
uniform float noise_amount : hint_range(0.0, 1.0) = 0.5;

varying float v_erode;
varying float v_seed;

void vertex() {
	v_erode = 1.0 - COLOR.a;
	v_seed = COLOR.r * 57.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d2 = dot(p, p);

	// دو لایه نویز: لکه‌های درشت + جزئیاتِ ریزتر
	float n = vnoise(p * noise_scale + v_seed) * 0.65
		+ vnoise(p * noise_scale * 2.3 - v_seed) * 0.35;

	// شکلِ پایه گنبدی است (وسط بیشترین مقدار) و نویز رویش ضرب می‌شود؛
	// با فرسایشِ صفر دایره‌ی کامل است، با بالا رفتنش تکه‌تکه کوچک می‌شود
	float mask = (1.0 - d2) * (1.0 - noise_amount + noise_amount * n);
	float aa = max(fwidth(mask), 0.002);
	float alpha = smoothstep(v_erode - aa, v_erode + aa, mask);

	if (outline_only) {
		COLOR = vec4(outline_color.rgb, alpha * outline_color.a);
	} else {
		// نورِ دو‌رنگ از بالا-چپ (محورِ y در بوم رو به پایین است)
		vec3 nrm = vec3(p, sqrt(max(1.0 - d2, 0.0)));
		float lit = dot(nrm, normalize(vec3(-0.55, -0.75, 0.45)));
		float band = smoothstep(-0.12, -0.06, lit);
		vec3 col = mix(shade_color.rgb, fill_color.rgb, band);

		// لبه‌ی در حالِ خورده‌شدن کمی تیره می‌شود تا تکه‌ها عمق داشته باشند
		float edge = 1.0 - smoothstep(v_erode + 0.02, v_erode + 0.09, mask);
		col = mix(col, shade_color.rgb, edge * smoothstep(0.02, 0.12, v_erode));

		COLOR = vec4(col, alpha * fill_color.a);
	}
}
