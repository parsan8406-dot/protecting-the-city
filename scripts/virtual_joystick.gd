extends Control

@onready var base = $Base
@onready var knob = $Knob

# حداکثر فاصله‌ای که غلطک می‌تونه از مرکز دایره بزرگ دور بشه (بر حسب پیکسل)
var max_length = 100.0 
var touch_index = -1

# این متغیر جهت نهایی رو ذخیره می‌کنه و پلیر ازش استفاده خواهد کرد
var joystick_vector := Vector2.ZERO 

func _ready():
	hide() # در شروع بازی جوی‌استیک مخفی باشه

func _input(event):
	# ۱. وقتی صفحه لمس میشه
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			# انتقال کل جوی‌استیک به نقطه‌ای که انگشت لمس کرده
			global_position = event.position 
			# ریست کردن موقعیت دایره‌ها به مرکز
			base.position = Vector2.ZERO
			knob.position = Vector2.ZERO
			show() # نمایش جوی‌استیک
		elif not event.pressed and event.index == touch_index:
			# وقتی انگشت برداشته میشه، همه چیز ریست و مخفی میشه
			touch_index = -1
			joystick_vector = Vector2.ZERO
			hide()

	# ۲. وقتی انگشت روی صفحه کشیده میشه (درگ)
	if event is InputEventScreenDrag and event.index == touch_index:
		# محاسبه فاصله انگشت تا مرکز جوی‌استیک
		var drag_vector = event.position - global_position
		
		# محدود کردن حرکت غلطک (غلطک نباید از دایره بزرگ بیرون بزنه)
		if drag_vector.length() > max_length:
			drag_vector = drag_vector.normalized() * max_length
			
		# جابجایی غلطک
		knob.position = drag_vector
		
		# تبدیل فاصله به یک جهت استاندارد بین 0 و 1 برای حرکت بازیکن
		joystick_vector = drag_vector / max_length
