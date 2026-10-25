extends Node
class_name PsychHudFocus
## کم‌رنگ کردنِ خودکارِ بخش‌های غیرضروریِ HUD وسطِ درگیری.  # C1 cognitive load
##
## هر پنل (کارتِ پروفایل، «اهداف»، پینگ) این‌جا ثبت می‌شود. تا وقتی چیزی در
## آن عوض نشده، بعد از چند ثانیه آرام کم‌رنگ می‌شود؛ با هر تغییر (wake) فوری
## روشن می‌شود و اگر «بحرانی» باشد (جانِ کم، خشابِ خالی، پینگِ بد) تا وقتی
## بحرانی است روشن می‌ماند. چشم فقط سراغِ چیزی می‌رود که همین الان مهم است.
##
## _process فقط چند عدد را کم می‌کند؛ تویین فقط وقتِ عوض شدنِ حالت ساخته می‌شود.

const WAKE_TIME := 0.08     # روشن شدن باید فوری حس شود  # C12
const DIM_TIME := 0.6       # کم‌رنگ شدن آرام، تا چشم را نکشد  # V4

## CanvasItem → {idle: float, hold: float, left: float, critical: bool, dim: bool, tw: Tween}
var _items: Dictionary = {}


func track(item: CanvasItem, idle_alpha: float, hold: float) -> void:
	if item == null:
		return
	_items[item] = {"idle": idle_alpha, "hold": hold, "left": hold,
		"critical": false, "dim": false, "tw": null}


## شفافیتِ حالتِ آرام را عوض می‌کند (مثلاً جانِ پر کم‌رنگ‌تر از جانِ نصفه)
func set_idle_alpha(item: CanvasItem, idle_alpha: float) -> void:
	var e: Dictionary = _items.get(item, {})
	if e.is_empty() or is_equal_approx(float(e.idle), idle_alpha):
		return
	e.idle = idle_alpha
	if e.dim:
		_fade(item, e, idle_alpha, DIM_TIME)


## چیزی عوض شد: روشن، و شمارشِ «آرام» از نو
func wake(item: CanvasItem, critical := false) -> void:
	var e: Dictionary = _items.get(item, {})
	if e.is_empty():
		return
	e.left = float(e.hold)
	e.critical = critical
	if e.dim or item.modulate.a < 0.999:
		e.dim = false
		_fade(item, e, 1.0, WAKE_TIME)


## فقط حالتِ بحرانی (بدونِ شمردنِ آن به‌عنوانِ «تغییر»)
func set_critical(item: CanvasItem, critical: bool) -> void:
	var e: Dictionary = _items.get(item, {})
	if e.is_empty() or bool(e.critical) == critical:
		return
	if critical:
		wake(item, true)
	else:
		e.critical = false
		e.left = float(e.hold)


func _process(delta: float) -> void:
	for item in _items.keys():
		if not is_instance_valid(item):
			_items.erase(item)
			continue
		var e: Dictionary = _items[item]
		if e.critical or e.dim:
			continue
		e.left = float(e.left) - delta
		if e.left <= 0.0:
			e.dim = true
			_fade(item, e, float(e.idle), DIM_TIME)


func _fade(item: CanvasItem, e: Dictionary, alpha: float, t: float) -> void:
	var tw: Tween = e.tw
	if tw != null and tw.is_valid():
		tw.kill()
	tw = item.create_tween()
	tw.tween_property(item, "modulate:a", alpha, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	e.tw = tw
