shader_type canvas_item;
// جامِ «بعد از شکست»: همان جامِ طلایی که نقره‌ای-تیره می‌شود.
// amount از ۰ (طلایی) تا ۱ (نقره‌ای) همراهِ پایین آمدنِ عدد انیمیت می‌شود.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 silver : source_color = vec4(0.72, 0.78, 0.9, 1.0);

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(l) * silver.rgb * 1.05;
	c.rgb = mix(c.rgb, grey, amount);
	COLOR = c;
}
