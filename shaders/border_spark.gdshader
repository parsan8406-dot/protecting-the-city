shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec4 spark_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float spark_size : hint_range(0.01, 0.5) = 0.08; // عرض نور
uniform float time_offset = 0.0; // برای ناهماهنگ ساختن کارت‌ها

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// محاسبه زاویه چرخش (از -PI تا PI)
	float angle = atan(uv.y, uv.x);
	
	// نرمال‌سازی زاویه بین 0 تا 1
	float norm_angle = (angle + 3.14159265) / (2.0 * 3.14159265);
	
	// حرکت زاویه‌ای با زمان
	float current_pos = fract((TIME * speed * 0.2) + time_offset);
	
	// محاسبه فاصله زاویه‌ای تا مرکز نور
	float dist = abs(norm_angle - current_pos);
	dist = min(dist, 1.0 - dist); // برای چرخش بدون شکستگی در نقطه شروع
	
	// ایجاد هاله محو و نرم (Glow)
	float spark_intensity = smoothstep(spark_size, 0.0, dist);
	
	// ترکیب رنگ پایه بردر با نور سفید چرخشی
	vec4 final_color = mix(border_color, spark_color, spark_intensity * spark_color.a);
	
	// حفظ شفّافیت اصلی نود
	COLOR = texture(TEXTURE, UV) * final_color;
}