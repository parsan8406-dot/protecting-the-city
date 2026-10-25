extends Node2D
## مشعلِ دیواری — شعله‌ی شیدری + نورِ نارنجی که دیوارهای اطراف را روشن می‌کند.
##
## شعله کاملاً در shaders/wall_torch.gdshader ساخته می‌شود. متریالِ شعله بینِ
## همه‌ی مشعل‌ها مشترک است (دیگر local_to_scene نیست) تا همه با هم batch
## شوند؛ فازِ هر شعله را خودِ شیدر از جای مشعل در دنیا درمی‌آورد.
##
## این اسکریپت دیگر _process ندارد: Arena با یک حلقه برای همه‌ی مشعل‌های
## روشن flicker() را صدا می‌زند، و بر اساسِ کیفیتِ گرافیک تعیین می‌کند کدام
## مشعل نورِ واقعی (PointLight2D) داشته باشد (set_lit) و کجا به‌جای Glow
## هاله‌ی افزودنیِ ارزان نشان داده شود (set_halo).
##
## هاله‌ی نرمِ دورِ شعله در کیفیتِ زیاد از Glowِ WorldEnvironment می‌آید
## (صحنه‌ی World)؛ در کیفیتِ کم و متوسط Glow خاموش است و اسپرایتِ Halo
## جایش را می‌گیرد.

## فازِ نوسانِ نور. Arena برای هر مشعل عددِ تصادفی می‌دهد.
@export var time_offset := 0.0

@export_range(0.0, 4.0) var light_energy_min := 0.8
@export_range(0.0, 4.0) var light_energy_max := 1.2

@onready var _flame: Sprite2D = $Flame
@onready var _light: PointLight2D = $Light
@onready var _halo: Sprite2D = $Halo


## نورِ واقعیِ مشعل روشن باشد یا فقط شعله دیده شود
func set_lit(on: bool) -> void:
	_light.enabled = on
	_light.visible = on


func is_lit() -> bool:
	return _light.enabled


## هاله‌ی افزودنی — جانشینِ Glow وقتی Glow خاموش است
func set_halo(on: bool) -> void:
	_halo.visible = on


## متریالِ مشترکِ شعله (برای پرچم‌های کیفیت در Arena)
func flame_material() -> ShaderMaterial:
	return _flame.material as ShaderMaterial


## نبضِ نور در لحظه‌ی now (ثانیه). Arena هر فریم برای مشعل‌های روشن صدا می‌زند.
func flicker(now: float) -> void:
	var t := now + time_offset
	# دو موجِ ناهم‌فرکانس: نبضِ نامنظمِ آتش، نه سینوسِ تمیز. خروجی ۰..۱
	var f := 0.5 + 0.32 * sin(t * 3.3) + 0.18 * sin(t * 8.9 + 1.7)
	_light.energy = lerpf(light_energy_min, light_energy_max, clampf(f, 0.0, 1.0))
