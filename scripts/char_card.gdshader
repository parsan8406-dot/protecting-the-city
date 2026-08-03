shader_type canvas_item;

uniform float speed = 1.5;
// فاصله حاشیه نورانی از لبه‌های بیرونی کارت (برای فرار از کلیپینگ ماسک)
uniform float border_margin = 0.06; 
// ضخامت خود حاشیه رنگی
uniform float border_width = 0.05;  

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV - center;

    // محاسبه زاویه چرخش رنگ‌ها
    float angle = atan(uv.y, uv.x) / (2.0 * 3.14159);
    float hue = fract(angle + TIME * speed);
    vec3 rgb = hsv2rgb(vec3(hue, 1.0, 1.0));

    // مرز بیرونی (جایی که قاب نوری شروع می‌شود)
    vec2 outer_rect = step(vec2(border_margin), UV) - step(vec2(1.0 - border_margin), UV);
    float is_inside_outer = outer_rect.x * outer_rect.y;

    // مرز درونی (جایی که قاب تمام شده و وسط کارت خالی می‌شود)
    float inner_margin = border_margin + border_width;
    vec2 inner_rect = step(vec2(inner_margin), UV) - step(vec2(1.0 - inner_margin), UV);
    float is_inside_inner = inner_rect.x * inner_rect.y;

    // اعمال آلفا: فقط فضای بین مرز بیرونی و درونی رنگ بگیرد
    float alpha = is_inside_outer * (1.0 - is_inside_inner);

    COLOR = vec4(rgb, alpha);
}