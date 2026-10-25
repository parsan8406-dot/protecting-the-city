shader_type canvas_item;
render_mode unshaded;

// موجِ گرمای انفجار — حلقه‌ای که تصویرِ پشتش را کج می‌کند.
//
// این همان چیزی است که یک انفجارِ ۲بعدی را از «چند اسپرایتِ نارنجی» به یک
// انفجارِ واقعی تبدیل می‌کند: دیوارها و کفِ پشتِ موج یک لحظه تکان می‌خورند،
// پس انفجار روی صحنه اثر می‌گذارد و فقط رویش کشیده نمی‌شود.
//
// روش: نمونه‌ی صفحه را با یک آفستِ شعاعی می‌خوانیم که فقط داخلِ نوارِ باریکِ
// دورِ شعاعِ فعلی غیرصفر است. شدت با فاصله از نوار محو می‌شود، پس بیرون و
// داخلِ موج دست‌نخورده می‌ماند.
//
// روی رندررِ gl_compatibility هم کار می‌کند (SCREEN_TEXTURE در کانواس ۲بعدی
// پشتیبانی می‌شود). اگر درایوری نتواند، بدترین حالت این است که چیزی کج
// نمی‌شود — هیچ‌چیز نمی‌شکند، چون بقیه‌ی لایه‌های انفجار مستقل‌اند.
//
// radius / thickness / strength را GDScript انیمیت می‌کند (CombatFX).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float radius : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.005, 0.5) = 0.10;
// بیشترین جابه‌جاییِ تصویر، بر حسبِ کسری از صفحه
uniform float strength : hint_range(0.0, 0.2) = 0.035;
// درخششِ خودِ موج، روی کجیِ تصویر
uniform vec4 col : source_color = vec4(1.0, 0.62, 0.28, 1.0);
uniform float glow : hint_range(0.0, 2.0) = 0.55;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;

	// نوارِ نرم دورِ شعاعِ فعلی
	float band = 1.0 - smoothstep(0.0, thickness, abs(d - radius));
	band *= band;
	// جلوی بیرون‌زدن از کوآد
	band *= 1.0 - smoothstep(0.95, 1.0, d);

	vec2 dir = d > 0.0001 ? p / d : vec2(0.0);
	// تصویر رو به بیرون کشیده می‌شود — مثل هوایی که موج جلویش می‌راند
	vec2 offset = dir * band * strength;

	vec4 back = texture(screen_tex, SCREEN_UV + offset);
	// لبه‌ی خودِ موج کمی می‌درخشد تا در تاریکی گم نشود
	back.rgb += col.rgb * band * glow;

	COLOR = vec4(back.rgb, 1.0);
}
