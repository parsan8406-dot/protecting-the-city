shader_type canvas_item;

// دیوارِ کاشی‌شده با سه بافتِ سنگِ مذاب‌دار (assets/tiles/wall_variant_*.png).
//
// هر دیوار (یک مستطیل از نقشه) به خانه‌های تقریباً مربع تقسیم می‌شود و هر
// خانه یکی از سه بافت را نشان می‌دهد. انتخابِ بافت در Arena.gd انجام می‌شود
// (هیچ دو خانه‌ی هم‌مرزی یکسان نیستند) و به‌شکلِ یک بافتِ دادهٔ کوچک به اینجا
// می‌رسد: هر پیکسلِ variant_map یک خانه است و مقدارش شماره‌ی بافت.
//
// چرا شیدر و نه یک Sprite2D برای هر خانه: نقشه چند صد خانه دارد و با سه
// بافتِ درهم هر اسپرایت batch را می‌شکند. اینجا هر دیوار یک draw است.
//
// مذابِ داخلِ بافت (درزها و گل‌میخ‌های گوشه) از روی رنگ جدا می‌شود و HDR
// می‌گیرد، پس Glowِ WorldEnvironment رویش هاله می‌سازد و در تاریکیِ زمین
// هم می‌سوزد. بقیه‌ی سنگ هم‌پای تاریکیِ کف تیره می‌ماند.

uniform sampler2D variant_0 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D variant_1 : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D variant_2 : source_color, filter_linear_mipmap, repeat_disable;
// یک پیکسل برای هر خانه؛ R = شماره‌ی بافت / ۲۵۵
uniform sampler2D variant_map : filter_nearest, repeat_disable;
uniform vec2 cells = vec2(1.0, 1.0);

// روشناییِ سنگ بدونِ نور. زمین تاریک است؛ سنگِ کاملاً روشن وسطِ آن وصله
// به‌نظر می‌رسد.
uniform float brightness : hint_range(0.0, 2.0) = 0.62;
// چند برابر مذاب روشن‌تر شود. بالای ۱ یعنی HDR و هاله.
uniform float lava_boost : hint_range(0.0, 4.0) = 1.5;
// نبضِ آرامِ مذاب. ۰ = ثابت
uniform float lava_pulse : hint_range(0.0, 1.0) = 0.22;
// سهمِ نورِ چراغ‌ها روی سنگ. پایین است چون کانون‌های نورِ زمین انرژیِ ~۳
// دارند و سنگ را سفیدِ سوخته می‌کردند.
uniform float diffuse : hint_range(0.0, 1.0) = 0.32;
// کیفیتِ کم/متوسط: viewport دیگر HDR نیست (Arena.gd)، پس ضرایبِ روشنایی
// دیگر در فضای خطی ضرب نمی‌شوند. ضریبِ خطیِ f روی صفحه همان f^(1/2.2) در
// sRGB است؛ با این پرچم همان را مستقیم ضرب می‌کنیم تا سنگ و مذاب همان
// روشنایی‌ای را داشته باشند که در کیفیتِ زیاد دارند.
uniform bool ldr_fix = false;

void fragment() {
	vec2 g = UV * cells;                           // مختصاتِ پیوسته‌ی خانه‌ها
	vec2 cid = min(floor(g), cells - 1.0);
	vec2 luv = g - cid;                            // ۰..۱ داخلِ خانه

	// گرادیان از مختصاتِ پیوسته، نه از luv: luv سرِ مرزِ خانه‌ها از ۱ به ۰
	// می‌پرد و اگر GPU از روی آن mip انتخاب کند، روی هر درز یک خطِ تار
	// (کوچک‌ترین mip) می‌افتد.
	vec2 dx = dFdx(g);
	vec2 dy = dFdy(g);

	int v = int(texelFetch(variant_map, ivec2(cid), 0).r * 255.0 + 0.5);
	vec4 c;
	if (v == 1) {
		c = textureGrad(variant_1, luv, dx, dy);
	} else if (v == 2) {
		c = textureGrad(variant_2, luv, dx, dy);
	} else {
		c = textureGrad(variant_0, luv, dx, dy);
	}

	// مذاب: پیکسل‌های نارنجی-قرمزِ روشن. سنگِ زنگ‌زده هم قرمزی دارد ولی
	// روشن نیست، پس شرطِ دوم (r بالا) جدایش می‌کند. روی خودِ بافت‌ها ۲ تا ۵
	// درصدِ پیکسل‌ها رد می‌شوند — همان درزها و گل‌میخ‌ها.
	float lava = smoothstep(0.25, 0.55, c.r - c.b) * smoothstep(0.45, 0.85, c.r);
	float pulse = 1.0 - lava_pulse + lava_pulse * sin(TIME * 2.1 + (cid.x + cid.y) * 1.7);

	float gain = brightness + lava * lava_boost * pulse;
	if (ldr_fix) {
		gain = pow(gain, 1.0 / 2.2);
	}

	// آلفای بافت حفظ می‌شود: بعضی بافت‌های مانع لبه‌ی نیمه‌شفاف دارند
	COLOR = vec4(c.rgb * gain, c.a);
}

void light() {
	// LIGHT_COLOR.a محوشدنِ بافتِ چراغ است؛ بدونِ آن نور در کلِ مستطیلِ
	// خودش با شدتِ کامل می‌افتد و لبه‌اش روی دیوار پله می‌سازد.
	float fall = LIGHT_COLOR.a;
	LIGHT = vec4(COLOR.rgb * diffuse * LIGHT_COLOR.rgb * LIGHT_ENERGY * fall, fall);
}
