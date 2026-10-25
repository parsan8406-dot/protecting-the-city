shader_type canvas_item;
// نورِ صحنه روی خودِ شعله اثر ندارد — شعله خودش منبعِ نور است
render_mode unshaded;

// شعله‌ی مشعلِ دیواری — تماماً رویه‌ای، بدونِ ذره و بدونِ فریمِ ازپیش‌رندرشده.
//
// مراحل:
//   ۱. نویزِ fbm سه‌اکتاوی که رو به بالا حرکت می‌کند.
//   ۲. domain warp: قبل از نمونه‌ی نهایی، مختصات با دو نمونه‌ی نویزِ دیگر کج
//      می‌شود. همین است که شعله به‌جای نویزِ ساکن «می‌پیچد».
//   ۳. ماسکِ شکل: پایینِ پهن با تهِ گرد، رو به بالا باریک تا نوک.
//   ۴. ماسک + نویز از smoothstep با بازه‌ی خیلی تنگ رد می‌شود — لبه‌ی تیز و
//      بریده‌بریده، نه لکه‌ی محو. زبانه‌های جدا شده بالای شعله از همین‌جا
//      می‌آیند: نویز نقطه‌ای بیرون از شکل را از آستانه رد می‌کند.
//   ۵. سه لایه‌ی حرارت با همان آستانه‌ی تیز: لبه‌ی قرمز-نارنجی، میانه‌ی
//      نارنجی، مغزِ HDR سفید-زرد. مقادیرِ بالای ۱ را Glowِ WorldEnvironment
//      به هاله تبدیل می‌کند — هاله عمداً اینجا کشیده نمی‌شود.
//
// فازِ هر مشعل از جایش در دنیا می‌آید (هشِ MODEL_MATRIX در vertex) تا
// مشعل‌ها با هم نبض نزنند. قبلاً هر نمونه متریالِ local_to_scene و
// time_offsetِ خودش را داشت و همین batch را می‌شکست؛ حالا همه‌ی مشعل‌ها یک
// متریالِ مشترک دارند و با هم کشیده می‌شوند.
//
// ldr_fix: در کیفیتِ کم/متوسط viewport دیگر HDR نیست (Arena.gd) و رنگ‌های
// ثابتِ اینجا دیگر خطی تفسیر نمی‌شوند. با این پرچم خروجی خودش به sRGB برده
// می‌شود تا رنگِ شعله همانی بماند که در کیفیتِ زیاد دیده می‌شود.

uniform float time_offset = 0.0;
uniform bool ldr_fix = false;
uniform float speed : hint_range(0.1, 4.0) = 1.25;
// شدتِ پیچش. بیشتر = شعله‌ی آشفته‌تر
uniform float warp_amount : hint_range(0.0, 1.5) = 0.75;
// چقدر نویز لبه را می‌جود. بیشتر = زبانه‌های بلندتر و جداتر
uniform float jaggedness : hint_range(0.0, 2.0) = 1.35;
// نصفِ پهنای بازه‌ی smoothstep. ۰.۰۲ یعنی ۰.۴۸..۰.۵۲ — لبه‌ی بریده
uniform float edge_softness : hint_range(0.002, 0.2) = 0.02;
// نصفِ پهنای شعله در پهن‌ترین نقطه، به واحدِ UV.x
uniform float base_width : hint_range(0.1, 0.5) = 0.40;

// مغز HDR است (بالای ۱) تا Glow رویش هاله بسازد. source_color عمداً ندارد:
// آن hint رنگ را به بازه‌ی ۰..۱ می‌برد و HDR بودنش از بین می‌رود.
uniform vec3 core_color = vec3(2.0, 1.6, 0.6);
uniform vec3 mid_color = vec3(1.0, 0.55, 0.10);
uniform vec3 tip_color = vec3(0.80, 0.18, 0.03);


// هشِ بدونِ sin (Dave Hoskins). هر پیکسل ده بار vnoise و هر vnoise چهار هش
// می‌خواند — با نسخه‌ی sin یعنی ۴۰ sin در هر پیکسل، که روی GPUِ موبایل گران
// است و با دقتِ mediump هم الگوی بلوکی می‌سازد.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// سه اکتاو. چرخشِ بینِ اکتاوها نمی‌گذارد الگوی شبکه‌ایِ value noise دیده شود.
float fbm(vec2 p) {
	const mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return v / 0.875;   // مجموعِ دامنه‌ها — خروجی دوباره ۰..۱ می‌شود
}

// فازِ تصادفیِ همین مشعل — برای هر نمونه ثابت، چون مشعل‌ها تکان نمی‌خورند
varying float v_phase;

void vertex() {
	// vertex با دقتِ highp اجرا می‌شود؛ هش روی مختصاتِ چندهزاری هم سالم است
	v_phase = hash(MODEL_MATRIX[3].xy) * 100.0;
}

void fragment() {
	float h = 1.0 - UV.y;          // ۰ پایین، ۱ بالا
	float t = TIME * speed + time_offset + v_phase;

	// مختصاتِ هم‌مقیاس: کوادِ ۱:۲.۵ است، پس بدونِ این، نویز در عرض کش می‌آمد
	vec2 p = vec2(UV.x - 0.5, h * 2.5);

	// ---------- domain warp ----------
	vec2 q = vec2(
		fbm(p * 1.7 + vec2(0.0, -t * 1.1)),
		fbm(p * 1.7 + vec2(5.2, -t * 1.35)));
	// پیچش نزدیکِ نوک بیشتر است: پایینِ شعله روی فتیله ثابت می‌ماند
	vec2 w = p + (q - 0.5) * warp_amount * vec2(0.8, 0.9) * (0.2 + h);

	// نویزِ نهایی روی مختصاتِ کج‌شده. کشیدگیِ عمودی = زبانه‌های بلند
	float n = fbm(w * vec2(4.6, 1.6) + vec2(0.0, -t * 2.3));

	// ---------- ماسکِ شکل ----------
	// تابِ آرامِ کلِ شعله به چپ و راست، هرچه بالاتر بیشتر
	float sway = (vnoise(vec2(t * 0.7, 3.1)) - 0.5) * 0.16 * h * h;
	// نصفِ پهنا در ارتفاعِ h: تهِ گرد (sqrt یعنی قوس، نه نوکِ V)، بعد باریک
	// شدن تا نوک
	float hw = base_width * pow(max(1.0 - h, 0.0), 1.35) * sqrt(smoothstep(0.0, 0.16, h));
	float d = (hw - abs(w.x - sway)) / base_width;   // مثبت = داخلِ شکل

	// نویز بالاتر قوی‌تر است: پایین یکپارچه، نوک بریده‌بریده
	float value = 0.5 + d * 1.25 + (n - 0.5) * jaggedness * (0.15 + h * 1.2) - h * 0.06;
	// زبانه‌ها نباید به سقفِ کواد برسند، وگرنه نوکشان با یک خطِ صاف بریده می‌شود
	value -= smoothstep(0.80, 0.97, h) * 0.8;

	// ---------- لایه‌های تیز ----------
	float e = edge_softness;
	float outer = smoothstep(0.5 - e, 0.5 + e, value);
	float mid   = smoothstep(0.5 - e, 0.5 + e, value - 0.12 - h * 0.14);
	float core  = smoothstep(0.5 - e, 0.5 + e, value - 0.30 - h * 0.62);

	// ---------- گرادیانِ حرارت ----------
	vec3 rim = mix(mid_color, tip_color, smoothstep(0.15, 0.85, h));
	vec3 body = mix(vec3(1.0, 0.78, 0.25), mid_color, smoothstep(0.1, 0.7, h));
	vec3 col = mix(rim, body, mid);
	col = mix(col, core_color, core);
	if (ldr_fix) {
		col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));
	}

	COLOR = vec4(col, outer);
}
