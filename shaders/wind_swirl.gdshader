shader_type canvas_item;
render_mode unshaded;
// خطِ پیچانِ باد را «می‌کشد» و بعد از ته جمع می‌کند.
//
// بافت (assets/wind_swirl_*.png) در کانالِ قرمز نگه می‌دارد که هر پیکسل
// کجای خط است — ۰ تهِ خط، ۱ نوکِ مارپیچ — و در آلفا خودِ شکل را.
// scripts/wind.gd فقط head را جلو می‌برد؛ هرچه بینِ head و head-tail دیده
// می‌شود همان تکه‌ای از خط است که همین حالا وجود دارد. پس وزش از ته شروع
// می‌شود، توی مارپیچ می‌پیچد و بعد از همان ته محو می‌شود.
//
// رنگ از modulate می‌آید، پس یک بافت برای همه‌ی تم‌ها بس است.

// سرِ خط: از ۰ تا ۱+tail می‌رود
uniform float head : hint_range(-1.0, 2.5) = 0.0;
// چقدر از خط پشتِ سر زنده می‌ماند
uniform float tail : hint_range(0.05, 2.0) = 0.55;
// نرمیِ دو سرِ برش — ۰ یعنی لبه‌ی قیچی‌شده
uniform float edge : hint_range(0.005, 0.4) = 0.07;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float p = t.r;                       // کجای خط
	float grow = smoothstep(head - edge, head, p);        // هنوز نرسیده؟
	float gone = smoothstep(head - tail, head - tail + edge, p);  // ته رفته؟
	COLOR = vec4(COLOR.rgb, t.a * COLOR.a * (1.0 - grow) * gone);
}
