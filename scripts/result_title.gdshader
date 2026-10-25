shader_type canvas_item;
// عنوانِ درشتِ «پیروزی»/«شکست»: گرادیانِ عمودی روی بدنه‌ی حروف و یک نوارِ
// براقِ مورب که از رویشان رد می‌شود.
//
// لیبل با font_color سفید ساخته می‌شود؛ هر پیکسلی که سفید است بدنه‌ی حرف است
// و گرادیان می‌گیرد. دورخط و سایه رنگِ تیره‌ی خودشان را نگه می‌دارند.

uniform vec4 top_color : source_color = vec4(1.0, 0.96, 0.66, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.86, 0.52, 0.10, 1.0);
// اندازه‌ی لیبل (پیکسلِ محلی) — اسکریپت با هر چیدمان ست می‌کند
uniform vec2 rect_size = vec2(400.0, 120.0);
// حروف کلِ ارتفاعِ لیبل را پر نمی‌کنند؛ گرادیان فقط روی همین بازه
uniform float grad_top = 0.25;
uniform float grad_bottom = 0.85;
// جای نوارِ براق روی عرض (۰ تا ۱)؛ بیرون از بازه یعنی خاموش
uniform float shine = -1.0;
uniform float shine_width = 0.07;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	float body = step(0.9, min(c.r, min(c.g, c.b)));
	vec2 n = local_pos / rect_size;
	float t = clamp((n.y - grad_top) / (grad_bottom - grad_top), 0.0, 1.0);
	vec3 g = mix(top_color.rgb, bottom_color.rgb, t);
	float band = 1.0 - smoothstep(0.0, shine_width, abs(n.x + n.y * 0.3 - shine));
	g += vec3(0.6) * band;
	c.rgb = mix(c.rgb, g, body);
	COLOR = c;
}
