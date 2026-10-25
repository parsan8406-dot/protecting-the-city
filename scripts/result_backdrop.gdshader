shader_type canvas_item;
// پس‌زمینه‌ی صفحه‌ی برد/باخت، در یک پاس:
//   ۱. زمینِ بازیِ زیرش تار می‌شود
//   ۲. آرتِ پس‌زمینه («cover»، مثل TextureRect) با تاریِ جدا رویش می‌آید
//   ۳. رنگِ تیره + ویگنت + هاله‌ی رنگیِ بالای صفحه
//
// انیمیشنِ ورود فقط uniformها را جابه‌جا می‌کند: اول همه‌چیز کاملاً تار و
// آرت پُررنگ است، بعد آرت نیمه‌شفاف می‌شود تا زمینِ بازی از زیرش دیده شود.
//
// زمینِ بازی دیگر هر فریم از hint_screen_texture خوانده نمی‌شود: آن یعنی
// کپیِ کاملِ صفحه + ساختنِ mipmap در هر فریم، در حالی که دنیای زیرش هم
// کامل کشیده می‌شد. match_result_screen.gd لحظه‌ی باز شدن یک عکس از صفحه
// می‌گیرد (world_tex، نصفِ رزولوشن با mipmap — تاری هیچ‌وقت سطحِ ۰ را
// نمی‌خواند) و وقتی پس‌زمینه کاملاً پوشاند، خودِ دنیا را پنهان می‌کند.
// زیرِ این تاری و آرت، ثابت شدنِ زمینِ بازی دیده نمی‌شود.
//
// world_tex عمداً source_color ندارد: عکس در همان فضای رنگیِ رندر است
// (sRGB، یا خطی وقتی Arena viewport را HDR کرده) و نباید دوباره تبدیل شود.
//
// محو شدنِ اولیه با آلفاست، نه با نمونه‌ی خامِ صفحه: (۱−fade)×دنیای زنده +
// fade×پس‌زمینه همان mix(raw, col, fade)ِ قبلی است.

uniform sampler2D world_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D art_tex : source_color, filter_linear_mipmap, repeat_disable;

// world_tex چند سطحِ mip کوچک‌تر از صفحه است (نصف = ۱)
uniform float world_lod_offset = 1.0;
uniform vec2 art_size = vec2(1536.0, 1024.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
// کدام بخشِ آرت وقتی بریده می‌شود در کادر بماند (۰ تا ۱)
uniform vec2 art_focus = vec2(0.5, 0.5);

// ۰ = صحنه‌ی خامِ بازی، ۱ = پس‌زمینه‌ی کامل (برای محو شدنِ اولیه)
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// شعاعِ تاریِ زمینِ بازی به پیکسلِ صفحه
uniform float blur_px = 12.0;
uniform float art_lod = 1.0;
uniform float art_alpha : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(0.02, 0.02, 0.03, 0.35);
uniform float vignette = 0.55;
uniform vec4 accent : source_color = vec4(1.0, 0.7, 0.2, 0.25);

const int TAPS = 12;
// همان مارپیچِ طلاییِ قبلی (شعاع sqrt((i+0.5)/12)، زاویه i×2.39996) از قبل
// حساب‌شده — به‌جای ۲۴ sin/cos برای هر پیکسل فقط یک چرخش
const vec2 SPIRAL[12] = vec2[](
	vec2(0.2041, 0.0000),
	vec2(-0.2607, 0.2388),
	vec2(0.0399, -0.4547),
	vec2(0.3286, 0.4286),
	vec2(-0.6030, -0.1067),
	vec2(0.5712, -0.3634),
	vec2(-0.1911, 0.7107),
	vec2(-0.3644, -0.7016),
	vec2(0.7906, 0.2887),
	vec2(-0.8224, 0.3395),
	vec2(0.3965, -0.8472),
	vec2(0.2930, 0.9341)
);

// نویزِ پیکسلی برای چرخاندنِ الگوی نمونه‌ها — لبه‌ی تکراری را از بین می‌برد
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;

	float lod = max(log2(max(blur_px * 0.35, 1.0)) - world_lod_offset, 0.0);
	float spin = ign(FRAGCOORD.xy) * 6.2831853;
	float cs = cos(spin);
	float sn = sin(spin);
	mat2 rot = mat2(vec2(cs, sn), vec2(-sn, cs));
	vec3 acc = textureLod(world_tex, SCREEN_UV, lod).rgb;
	for (int i = 0; i < TAPS; i++) {
		vec2 uv = clamp(SCREEN_UV + rot * SPIRAL[i] * blur_px * px, vec2(0.0), vec2(1.0));
		acc += textureLod(world_tex, uv, lod).rgb;
	}
	vec3 col = acc / float(TAPS + 1);

	// آرت با قاعده‌ی «cover»: کلِ کادر را پر می‌کند، اضافه‌اش بریده می‌شود
	float s = max(rect_size.x / art_size.x, rect_size.y / art_size.y);
	vec2 vis = rect_size / (art_size * s);
	vec2 start = clamp(art_focus - vis * 0.5, vec2(0.0), vec2(1.0) - vis);
	vec3 art = textureLod(art_tex, start + UV * vis, art_lod).rgb;
	col = mix(col, art, art_alpha);

	col = mix(col, tint.rgb, tint.a);
	vec2 d = (UV - 0.5) * vec2(1.0, 1.25);
	col *= 1.0 - smoothstep(0.3, 0.85, length(d)) * vignette;
	float glow = 1.0 - smoothstep(0.0, 0.6, length((UV - vec2(0.5, 0.18)) * vec2(1.3, 1.9)));
	col += accent.rgb * accent.a * glow;

	COLOR = vec4(col, fade);
}
