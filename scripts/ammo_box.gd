extends Area2D

func _ready():
	# تنظیمات تایمر از طریق کد (برای اطمینان ۱۰۰ درصدی)
	$RespawnTimer.wait_time = 20.0 # زمان غیب بودن (فعلا می‌تونی برای تست بکنی 5.0)
	$RespawnTimer.one_shot = true  # فقط یک‌بار تایمر رو بشمره
	
	# جلوگیری از ارور وصل شدنِ چندباره‌ی سیگنال‌ها
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	if not $RespawnTimer.timeout.is_connected(_on_respawn_timer_timeout):
		$RespawnTimer.timeout.connect(_on_respawn_timer_timeout)

func _on_body_entered(body):
	if body.has_method("reload_full_ammo"):
		var is_reloaded = body.reload_full_ammo()
		
		if is_reloaded:
			
			$Sprite2D.hide()
			$CollisionShape2D.set_deferred("disabled", true)
			$RespawnTimer.start() # استارت زدن تایمر

# این تابع وقتی که ۲۰ ثانیه تموم بشه، اتوماتیک اجرا میشه
func _on_respawn_timer_timeout():
	
	$Sprite2D.show()
	$CollisionShape2D.set_deferred("disabled", false)
