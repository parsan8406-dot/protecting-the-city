extends RefCounted
## E1 ارتباط / E10 «با هم بازی کنیم» — دعوت یک‌لمسی دوستِ آنلاین.
##
## سرور سیستم پارتی ندارد، ولی صف مچ‌میکینگ آدم‌های واقعی را با هم جور
## می‌کند؛ پس دعوت یک پیام خصوصی چت است (POST /chat/send) که دوست همان لحظه
## نوتیفش را می‌گیرد. چیزی جعل نمی‌شود و هر دعوت را خودِ بازیکن می‌زند.

const INVITE_TEXT := "بیا با هم بازی کنیم! من الان آنلاینم — بزن بریم مسابقه"
## جلوی دعوتِ پشت‌سرهم به یک نفر (اسپم) — فقط داخل همین اجرا
const COOLDOWN_SEC := 90

static var _last_sent: Dictionary = {}

## ثانیه تا دعوت دوباره‌ی همین دوست (۰ = آزاد)
static func seconds_left(peer_id: String) -> int:
	var at := int(_last_sent.get(peer_id, 0))
	return maxi(at + COOLDOWN_SEC - int(Time.get_unix_time_from_system()), 0)

## on_done(ok: bool, message: String)
static func send(host: Node, peer_id: String, peer_name: String, on_done: Callable) -> void:
	if peer_id.is_empty():
		return
	var left := seconds_left(peer_id)
	if left > 0:
		on_done.call(false, "دعوتت چند لحظه پیش برای %s رفت — کمی صبر کن" % peer_name)
		return
	var http := HTTPRequest.new()
	http.timeout = 10.0
	host.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			_last_sent[peer_id] = int(Time.get_unix_time_from_system())
			on_done.call(true, "دعوت برای %s رفت — بزن بریم مسابقه!" % peer_name)
		else:
			on_done.call(false, MenuUI.server_error(body, code if result == HTTPRequest.RESULT_SUCCESS else 0, "دعوت فرستاده نشد")))
	var payload := {"username": Global.my_username, "channel": "private", "peer_id": peer_id, "text": INVITE_TEXT}
	if http.request(Global.SERVER_BASE + "/chat/send", Global.json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		http.queue_free()
		on_done.call(false, "اتصال به سرور برقرار نشد")
