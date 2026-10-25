shader_type canvas_item;
// شیشه‌ی مات پشتِ پنلِ بارگذاری: پس‌زمینه را کمی محو می‌کند و گوشه‌ها را
// گرد می‌بُرد. فقط روی صفحه‌ی لودینگ است و عمرش کوتاه، پس ۱۳ نمونه ارزان است.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 rect_size = vec2(600.0, 160.0);
uniform float radius = 22.0;
uniform float blur = 7.0;
uniform vec4 tint : source_color = vec4(0.05, 0.05, 0.06, 0.42);

float rounded_mask(vec2 uv) {
	vec2 p = (uv - 0.5) * rect_size;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	return clamp(0.5 - d, 0.0, 1.0);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb * 0.2;
	col += texture(screen_tex, SCREEN_UV + vec2( px.x, 0.0)).rgb * 0.1;
	col += texture(screen_tex, SCREEN_UV + vec2(-px.x, 0.0)).rgb * 0.1;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0,  px.y)).rgb * 0.1;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0, -px.y)).rgb * 0.1;
	col += texture(screen_tex, SCREEN_UV + px).rgb * 0.075;
	col += texture(screen_tex, SCREEN_UV - px).rgb * 0.075;
	col += texture(screen_tex, SCREEN_UV + vec2(px.x, -px.y)).rgb * 0.075;
	col += texture(screen_tex, SCREEN_UV + vec2(-px.x, px.y)).rgb * 0.075;
	col += texture(screen_tex, SCREEN_UV + vec2( px.x * 2.0, 0.0)).rgb * 0.025;
	col += texture(screen_tex, SCREEN_UV + vec2(-px.x * 2.0, 0.0)).rgb * 0.025;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0,  px.y * 2.0)).rgb * 0.025;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0, -px.y * 2.0)).rgb * 0.025;
	col = mix(col, tint.rgb, tint.a);
	// نورِ ملایمِ بالای شیشه
	col += vec3(1.0) * 0.07 * (1.0 - smoothstep(0.0, 0.55, UV.y));
	COLOR = vec4(col, rounded_mask(UV));
}
