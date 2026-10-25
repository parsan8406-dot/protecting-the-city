shader_type canvas_item;
// افزودنی و بی‌اثر از نورِ صحنه: خودش جای نور را گرفته
render_mode blend_add, unshaded;

// جانشینِ ارزانِ کانون‌های نورِ زمین در کیفیتِ کم و متوسط (Arena.gd).
//
// در کیفیتِ زیاد هر کانون دو PointLight2D است (مغز + هاله). روی رندررِ
// gl_compatibility هر نور آیتم‌های زیرش — از جمله کلِ بک‌گراند — را یک بارِ
// دیگر می‌کشد؛ با پنج کانون یعنی ده پاسِ تقریباً تمام‌صفحه. این‌جا هر کانون
// فقط یک کوادِ افزودنی است.
//
// برای اینکه شبیهِ نور بماند و نه مهِ نارنجیِ یکدست، همان کارِ نور را
// دستی انجام می‌دهد: بافتِ کفِ زمین را در همان نقطه می‌خواند، با همان
// تاریکیِ محیط تیره می‌کند و با همان فرمولِ BLEND_MODE_ADDِ نور رویش می‌افزاید:
//     کف × رنگِ نور × انرژی × محوشدنِ بافتِ نور
// کیفیتِ زیاد در HDR (فضای خطی) جمع می‌کند و این‌جا sRGB است؛ پس بهره در
// فضای خطی حساب و بعد به sRGB برده می‌شود تا روشنی و پهنای لکه همان بماند.
//
// مغز و هاله هر دو از همین یک کواد می‌آیند: کواد به اندازه‌ی هاله است و
// مغز با UVِ کوچک‌شده از همان بافت خوانده می‌شود.

uniform sampler2D floor_tex : filter_linear, repeat_disable;
// مستطیلِ بک‌گراند در مختصاتِ دنیا
uniform vec2 floor_origin = vec2(0.0, 0.0);
uniform vec2 floor_size = vec2(2000.0, 1120.0);
// همان ambient_tintِ Arena که روی بک‌گراند نشسته
uniform vec3 floor_tint = vec3(0.115, 0.11, 0.155);
uniform vec3 light_color = vec3(1.0, 0.82, 0.55);
uniform float core_energy = 3.1;
uniform float halo_energy = 1.3;
// هاله چند برابرِ مغز است (halo_scaleِ Arena)
uniform float halo_scale = 1.9;

varying vec2 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// بافتِ نور سفید است و محوشدن در آلفاست — مثلِ LIGHT_COLOR.a
	float halo_a = texture(TEXTURE, UV).a;
	// بیرون از مربعِ مغز، clampِ لبه آلفای ~۰ می‌دهد
	float core_a = texture(TEXTURE, (UV - 0.5) * halo_scale + 0.5).a;

	vec3 lc = pow(light_color, vec3(2.2));
	vec3 gain = pow(vec3(1.0) + lc * (core_energy * core_a + halo_energy * halo_a),
		vec3(1.0 / 2.2)) - 1.0;

	vec3 base = texture(floor_tex, (v_world - floor_origin) / floor_size).rgb * floor_tint;
	COLOR = vec4(base * gain, 1.0);
}
