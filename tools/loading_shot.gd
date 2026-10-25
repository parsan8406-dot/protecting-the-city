extends Node
## عکس از صفحه‌ی بارگذاری روی یک رزولوشن، با نوارِ نیمه‌پر.
##
##   godot --path . res://tools/loading_shot.tscn --resolution 2400x1080 -- --out=C:/tmp/loading.png

var _out := "user://loading_shot.png"
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr("--out=".length())
	# صفحه‌ی شروعِ بازی اولِ فریم خودش را (چون این صحنه‌ی اصلی نیست) می‌بندد
	await get_tree().process_frame
	LoadingScreen.begin({"a": 1.0, "b": 1.0}, "در حال آماده‌سازی میدان نبرد")
	LoadingScreen.complete("a", "دریافت اطلاعات بازیکن‌ها...")


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 90:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("LOADING SHOT: ", _out, " ", img.get_size())
		get_tree().quit()
