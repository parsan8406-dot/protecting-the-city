extends Area2D

var speed: float = 1200.0
var direction: Vector2 = Vector2.ZERO

# متغیری که اسم صاحب تیر توش ذخیره میشه (تا به خودش نخوره)
var shooter_name: String = ""

func _ready():
	# پاک شدن خودکار تیر بعد از ۲ ثانیه (برای جلوگیری از لگ شدن بازی)
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _physics_process(delta):
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func _on_body_entered(body):
	# ۱. اگر تیر به خود کسی که شلیک کرده خورد، کلاً نادیده‌اش بگیر
	if body.name == shooter_name:
		return
		
	# ۲. تیر به هر چیز دیگه‌ای (دشمن، دیوار و...) خورد، فقط گرافیکش حذف میشه
	# هیچ دیتایی به شبکه نمی‌فرستیم چون RayCast تو پلیر قبلاً این کارو کرده!
	queue_free()