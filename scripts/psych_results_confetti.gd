extends CPUParticles2D
## کنفتیِ طلاییِ کوتاه برای لحظه‌ی ارتقا (E17 هیجانِ مثبت).
##
## یک انفجارِ یک‌باره (~۱.۸ ثانیه)، بدون تکسچرِ فایل و بدون شیدر — روی
## گوشیِ ضعیف هم سبک است. خودش بعد از تمام شدن آزاد می‌شود.
##
## استفاده:
##   var c := preload("res://scripts/psych_results_confetti.gd").new()
##   parent.add_child(c)
##   c.burst(Vector2(640, 120), 560.0)   # محلِ پاشیدن و پهنای آن

static var _tex: Texture2D = null


func _init() -> void:
	emitting = false
	one_shot = true
	explosiveness = 0.85
	amount = 46
	lifetime = 1.8
	local_coords = true
	texture = _piece()
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	direction = Vector2(0, -1)
	spread = 70.0
	gravity = Vector2(0, 520)
	initial_velocity_min = 180.0
	initial_velocity_max = 380.0
	angular_velocity_min = -540.0
	angular_velocity_max = 540.0
	angle_min = 0.0
	angle_max = 360.0
	scale_amount_min = 0.7
	scale_amount_max = 1.3
	damping_min = 40.0
	damping_max = 80.0
	# طلایی/کرم با کمی قرمز — همان سه رنگِ تمِ بازی
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.38))
	ramp.set_color(1, Color(0.93, 0.25, 0.22))
	ramp.add_point(0.55, Color(1.0, 0.96, 0.78))
	ramp.add_point(0.8, Color(0.86, 0.6, 0.18))
	color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.75, Color.WHITE)
	color_ramp = fade
	finished.connect(queue_free)


func burst(at: Vector2, width: float) -> void:
	position = at
	emission_rect_extents = Vector2(width * 0.5, 10.0)
	restart()
	emitting = true


## تکه‌ی کاغذِ ۶×۱۰، یک بار برای همه
static func _piece() -> Texture2D:
	if _tex == null:
		var img := Image.create(6, 10, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_tex = ImageTexture.create_from_image(img)
	return _tex
