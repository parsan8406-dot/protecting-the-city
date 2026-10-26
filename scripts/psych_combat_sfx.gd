extends RefCounted
## صداهای کوتاهِ نبرد که بازی فایلشان را نداشت (برخورد، کیل، مولتی‌کیل،
## آسیب، ضربانِ قلب، تیک‌تاکِ آخرِ راند، برگشت به زمین).
##
## E11 یکپارچگیِ چندحسی: هر رویدادِ مهم تصویر + صدا + لرزش دارد و صدای هر
## رویداد امضای خودش را دارد — کیل «دینگِ» طلایی دوصدایی است، مولتی‌کیل
## آرپژِ بالارونده که با هر کیلِ بیشتر یک نت بلندتر می‌شود، آسیب یک ضربه‌ی
## بمِ کوتاه. همه همین‌جا با چند خط ریاضی ساخته می‌شوند (PCMِ ۱۶ بیتی
## ۲۲ کیلوهرتز، هر کدام چند کیلوبایت) — نه فایلی به APK اضافه می‌شود، نه
## موقعِ بازی چیزی ساخته می‌شود: یک بار و بارِ اول کش می‌شوند.

const RATE := 22050

static var _cache: Dictionary = {}


## صدای آماده با این نام (hit، kill، multi2..multi5، hurt، heart، tick،
## respawn، death)
static func get_stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var st := _build(name)
	_cache[name] = st
	return st


static func _build(name: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	match name:
		"hit":
			# تیکِ برخورد: کوتاه، زیر و تمیز — رگبار هم گوش را خسته نکند
			buf = _tone(0.05, 1900.0, 1900.0, 0.0015, 0.012, 0.34, 0.5)
			_mix(buf, _noise(0.006, 0.0005, 0.002, 0.18, 7), 0.0)
		"kill":
			# دینگِ طلایی: دو نت (پنجم) که روی هم می‌نشینند
			buf = _tone(0.34, 988.0, 988.0, 0.003, 0.11, 0.30, 0.35)
			_mix(buf, _tone(0.30, 1480.0, 1480.0, 0.003, 0.12, 0.30, 0.35), 0.07)
		"multi2", "multi3", "multi4", "multi5":
			var n := int(name.substr(5))
			var notes := [784.0, 988.0, 1175.0, 1568.0, 1976.0, 2349.0]
			var total := 0.06 * float(n) + 0.42
			buf.resize(int(total * RATE))
			for i in n + 1:
				var last := i == n
				var nt: PackedFloat32Array = _tone(0.42 if last else 0.16,
					notes[i], notes[i], 0.003, 0.14 if last else 0.06, 0.27, 0.4)
				_mix(buf, nt, 0.06 * float(i))
		"hurt":
			# ضربه‌ی بم: افتِ زیروبمی + کمی نویزِ نرم
			buf = _tone(0.16, 190.0, 70.0, 0.002, 0.05, 0.55, 0.15)
			_mix(buf, _noise(0.06, 0.001, 0.02, 0.16, 3), 0.0)
		"heart":
			# «لاب-داب»: دو تپشِ بم، دومی کمی آرام‌تر
			buf = _tone(0.34, 62.0, 44.0, 0.004, 0.04, 0.75, 0.0)
			_mix(buf, _tone(0.14, 58.0, 42.0, 0.004, 0.035, 0.55, 0.0), 0.17)
		"tick":
			buf = _tone(0.035, 1250.0, 1250.0, 0.001, 0.009, 0.28, 0.3)
		"respawn":
			buf = _tone(0.32, 420.0, 900.0, 0.03, 0.14, 0.22, 0.25)
			_mix(buf, _tone(0.24, 1320.0, 1760.0, 0.04, 0.08, 0.08, 0.0), 0.08)
		"death":
			buf = _tone(0.55, 520.0, 150.0, 0.01, 0.2, 0.3, 0.2)
		"wave":
			# C6 شروعِ موج: شیپورِ بمِ دونتیِ بالارونده — «آماده باش»
			buf = _tone(0.22, 196.0, 196.0, 0.02, 0.12, 0.42, 0.6)
			_mix(buf, _tone(0.42, 294.0, 294.0, 0.02, 0.2, 0.42, 0.6), 0.2)
		"clear":
			# پاک شدنِ موج: سه نتِ طلاییِ بالارونده و یک نتِ بلندِ آخر
			var notes2 := [659.0, 784.0, 988.0, 1319.0]
			buf.resize(int((0.09 * 3.0 + 0.5) * RATE))
			for i in notes2.size():
				var last2 := i == notes2.size() - 1
				_mix(buf, _tone(0.5 if last2 else 0.14, notes2[i], notes2[i], 0.003,
					0.2 if last2 else 0.06, 0.26, 0.4), 0.09 * float(i))
		"supply":
			# E2 صندوق: جرینگِ زیر و براق (دو نتِ تند + درخشش)
			buf = _tone(0.12, 1568.0, 1568.0, 0.002, 0.05, 0.26, 0.3)
			_mix(buf, _tone(0.3, 2093.0, 2093.0, 0.002, 0.1, 0.24, 0.3), 0.07)
			_mix(buf, _noise(0.18, 0.01, 0.06, 0.05, 11), 0.05)
		_:
			buf = _tone(0.02, 1000.0, 1000.0, 0.001, 0.005, 0.1, 0.0)
	return _to_wav(buf)


## یک نت: زیروبمی از f0 به f1، حمله‌ی attack و افتِ نماییِ tau.
## harm مقدارِ هارمونیکِ دوم — رنگِ «فلزی/طلایی»ِ صدا.
static func _tone(length: float, f0: float, f1: float, attack: float, tau: float,
		amp: float, harm: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / float(maxi(n - 1, 1))
		var f := lerpf(f0, f1, u)
		phase += TAU * f / RATE
		var env := minf(t / maxf(attack, 0.0001), 1.0) * exp(-t / tau)
		# چند میلی‌ثانیه‌ی آخر صفر شود تا تقه نزند
		env *= clampf((length - t) / 0.004, 0.0, 1.0)
		out[i] = amp * env * (sin(phase) + harm * sin(phase * 2.0))
	return out


static func _noise(length: float, attack: float, tau: float, amp: float, rng_seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / maxf(attack, 0.0001), 1.0) * exp(-t / tau)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
		out[i] = amp * env * lp
	return out


## src را از ثانیه‌ی at روی dst جمع می‌کند (dst اگر لازم شد بلند می‌شود)
static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float) -> void:
	var off := int(at * RATE)
	if dst.size() < off + src.size():
		dst.resize(off + src.size())
	for i in src.size():
		dst[off + i] += src[i]


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st
