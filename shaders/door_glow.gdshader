shader_type canvas_item;
// افزودنی و بی‌اثر از نورِ صحنه: آستانه خودش منبعِ نورِ فرضی است، پس نباید
// با CanvasModulate تیره شود. اینها اینجا ست می‌شوند و نه با
// CanvasItemMaterial، چون یک نود فقط یک material می‌گیرد.
render_mode blend_add, unshaded;

// آستانه‌ی درِ خروج: یک نوارِ نورانی که کفِ درگاه را روشن می‌کند.
//
// کارش فقط خوانا کردنِ نقشه است — بازیکن باید از دور بفهمد آن شکافِ بینِ دو
// دیوار یک راهِ خروج است، نه سایه. نوار عمداً از دو سرش محو می‌شود تا لبه‌ی
// تیزِ مستطیلی نداشته باشد و شبیه نورِ افتاده روی زمین بماند.

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.34, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.55;
// عرضِ در نسبت به بزرگ‌ترین درِ نقشه (۰..۱). درهای بزرگ‌تر پرنورترند، پس
// «خروجِ اصلی» از «راهِ فرعیِ تنگ» قابل تشخیص است.
//
// همه‌ی درها یک متریالِ مشترک دارند تا با هم batch شوند، پس دو مقدارِ
// مخصوصِ هر در دیگر uniform نیستند:
//   • وزنِ عرضِ در (mix(0.55, 1.0, scale_hint)) در آلفای self_modulateِ
//     خودِ اسپرایت می‌آید و اینجا از COLOR.a خوانده می‌شود (Arena.gd).
//   • فازِ نبض از هشِ جای در در دنیا می‌آید.
// scale_hint و pulse_offset برای سازگاری مانده‌اند و پیش‌فرضشان بی‌اثر است.
uniform float scale_hint : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.1;
uniform float pulse_offset = 0.0;
// کیفیتِ کم/متوسط (بدونِ HDR): جمعِ افزودنی دیگر در فضای خطی نیست و نوار
// کم‌رنگ‌تر دیده می‌شد. روی کفِ تاریک، a^(1/2.2) همان روشناییِ قبلی است.
uniform bool ldr_fix = false;

varying float v_phase;

void vertex() {
	vec2 p = MODEL_MATRIX[3].xy;
	v_phase = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
}

void fragment() {
	// وزنِ عرضِ همین در — self_modulate.a (بافت سفیدِ یک‌پیکسلی است)
	float width_w = COLOR.a;
	// UV.x = عرضِ درگاه، UV.y = عمقِ آستانه
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;      // ۱ در وسط، ۰ در دو سر
	float along = 1.0 - abs(UV.y - 0.5) * 2.0;
	float shape = smoothstep(0.0, 0.45, across) * smoothstep(0.0, 1.0, along);

	// نبضِ خیلی ملایم — نشان می‌دهد زنده است، ولی حواس را پرت نمی‌کند
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed + pulse_offset + v_phase);

	float a = shape * intensity * pulse * mix(0.55, 1.0, scale_hint) * width_w;
	if (ldr_fix) {
		a = pow(a, 1.0 / 2.2);
	}
	COLOR = vec4(glow_color.rgb, a);
}
