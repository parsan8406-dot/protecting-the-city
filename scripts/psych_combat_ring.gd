extends Node2D
## حلقه‌ی باریکِ زیرِ پای کاراکترهای دیگر — V6 خوانایی سیلوئت / V1 رنگ = تیم.
##
## کاراکترها از چند Polygon2D با اسکلت ساخته شده‌اند، پس Outlineِ شیدری
## روی‌شان گران و شکننده است. یک دایره‌ی ثابت زیرِ پا همان کار را با یک
## draw call می‌کند: حریف از پس‌زمینه‌ی تیره جدا می‌شود و رنگش (قرمز حریف،
## آبی هم‌تیمی) پیش‌توجهی خوانده می‌شود — حتی وقتی سیلوئتِ خودش در تاریکی
## گم است. فرزندِ خودِ کاراکتر است، پس تیرگیِ Arena (actor_tint) رویش هم
## می‌نشیند و از آن سرِ نقشه مثل چراغ دیده نمی‌شود؛ داخلِ نور روشن می‌شود.
## فقط یک بار کشیده می‌شود (_draw)، _process ندارد. دایره است، پس چرخشِ
## کاراکتر رویش اثری ندارد.

const COL_FOE := Color(1.0, 0.24, 0.22, 0.85)
const COL_ALLY := Color(0.36, 0.72, 1.0, 0.7)

## شعاع در مختصاتِ خودِ کاراکتر (player_s.tscn مقیاسِ ۰٫۵ دارد → ~۳۴ واحدِ دنیا)
var radius := 68.0
var width := 5.0
var ally := false


func _ready() -> void:
	# z منفی زیرِ کفِ زمین می‌رفت؛ به‌جایش اولین فرزندِ کاراکتر است تا قبل از
	# بدن کشیده شود (صدازننده با move_child(ring, 0) جایش را می‌گذارد)
	z_index = 0


func set_ally(on: bool) -> void:
	if ally == on and is_inside_tree():
		return
	ally = on
	queue_redraw()


func _draw() -> void:
	var c := COL_ALLY if ally else COL_FOE
	# سایه‌ی نرمِ زیر حلقه تا روی کفِ روشن هم جدا دیده شود
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0, 0, 0, 0.35), width + 5.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, c, width, true)
	# چهار دندانه‌ی کوچک — شکل هم معنا را می‌رساند، نه فقط رنگ (V2 کوررنگی)
	if not ally:
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI * 0.25
			var p := Vector2.from_angle(a)
			draw_line(p * (radius - 9.0), p * (radius + 7.0), c, width, true)
