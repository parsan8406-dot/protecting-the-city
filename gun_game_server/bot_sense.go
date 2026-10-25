package main

import (
	"math"
	"math/rand"
)

// ادراکِ بات: چه چیزی را می‌بیند و چه چیزی را می‌شنود.
//
// چرا این فایل هست: قبلاً pickTarget نزدیک‌ترین حریفِ زنده‌ی کلِ نقشه را
// برمی‌گرداند — بدونِ خطِ دید، بدونِ برد، بدونِ اینکه بات اصلاً رو به آن
// طرف باشد. یعنی هر باتی از لحظه‌ی اول می‌دانست حریف کجاست و مستقیم به
// همان نقطه راه می‌افتاد. نتیجه این بود که هشت نفر به یک نقطه سرازیر
// می‌شدند و بقیه‌ی نقشه خالی می‌ماند.
//
// حالا بات فقط چیزی را می‌داند که دیده یا شنیده. تا وقتی ردی پیدا نکرده
// گشت می‌زند؛ ردی که پیدا کرد چند ثانیه در خاطرش می‌ماند و می‌رود سراغش.

const (
	// botVision تا این فاصله، اگر دیوار جلویش نباشد و رو به آن طرف باشد،
	// حریف را می‌بیند.
	botVision = 620.0
	// botFOV نیم‌زاویه‌ی میدانِ دید (رادیان). ~۵۵ درجه به هر طرف.
	botFOV = 0.96
	// botCloseVision تا این فاصله جهتِ نگاه مهم نیست — کسی که بغلِ دستت
	// ایستاده را حس می‌کنی، حتی اگر پشتت باشد.
	botCloseVision = 190.0
	// botHearing صدای شلیک تا این فاصله شنیده می‌شود.
	//
	// عدد را روی اندازه‌ی نقشه اندازه گرفتیم: زمین ۲۰۰۰×۱۱۲۰ است، پس با
	// ۹۰۰ تقریباً هر شلیکی به گوشِ نصفِ نقشه می‌رسید و هر هشت نفر با اولین
	// تیر روی یک نقطه سرازیر می‌شدند — دقیقاً همان چیزی که قرار بود درست
	// شود. اندازه‌گیری شد: پراکندگیِ بات‌ها ۸۱۵ ← ۱۱۴ در ۱۲ ثانیه.
	botHearing = 480.0
	// botMemory چند ثانیه بعد از گم کردنِ رد، هنوز دنبالش می‌گردد.
	botMemory = 5.0
	// botNoiseError خطای مکانِ صدا. شلیک را می‌شنوی، ولی نقطه‌ی دقیقش را
	// نمی‌دانی — همین باعث می‌شود بات محدوده را بگردد نه اینکه مثل قطب‌نما
	// روی سرِ تیرانداز فرود بیاید.
	botNoiseError = 230.0
)

// senseTarget حریفی که بات همین حالا می‌بیند (نزدیک‌ترین).
// nil یعنی هیچ‌کس در دیدرس نیست — آن‌وقت باید بگردد.
func (h *Hub) senseTarget(p *Player) *Player {
	var best *Player
	bestD := math.Inf(1)
	for _, other := range h.players {
		if other.Username == p.Username || other.Health <= 0 {
			continue
		}
		if other.MatchID != p.MatchID {
			continue
		}
		// تیمِ خالی یعنی مسابقه‌ی بی‌تیم (تمرین) — آن‌جا همه حریف‌اند
		if p.Team != "" && other.Team == p.Team {
			continue
		}
		d := distance(p.X, p.Y, other.X, other.Y)
		if d > botVision || d >= bestD {
			continue
		}
		// دیوار وسط باشد، نمی‌بیندش
		if a := arenaOf(p); a != nil && !a.HasLineOfSight(p.X, p.Y, other.X, other.Y) {
			continue
		}
		// دور از خودش فقط داخلِ میدانِ دید؛ نزدیک، از هر طرف
		if d > botCloseVision {
			want := math.Atan2(other.Y-p.Y, other.X-p.X) + math.Pi/2
			if math.Abs(angleDiff(p.Rot, want)) > botFOV {
				continue
			}
		}
		best, bestD = other, d
	}
	return best
}

// noteSighting رد را ثبت می‌کند: کجا دیدمش و چند ثانیه یادم می‌ماند.
func (b *BotRuntime) noteSighting(x, y float64) {
	b.lastSeenX, b.lastSeenY = x, y
	b.memory = botMemory
	b.hasRoam = false // گشت‌زنی لغو؛ رد مهم‌تر است
}

// alertBotsToShot صدای شلیک را به بات‌های اطراف می‌رساند.
//
// از broadcastShoot صدا زده می‌شود، پس هم شلیکِ آدم و هم شلیکِ بات صدا
// دارد. فقط بات‌های تیمِ مقابل واکنش نشان می‌دهند — بات نباید به صدای
// تفنگِ هم‌تیمی‌اش برود.
func (h *Hub) alertBotsToShot(shooterName string) {
	shooter, ok := h.players[shooterName]
	if !ok {
		return
	}
	for name, b := range h.bots {
		p, ok := h.players[name]
		if !ok || p.Health <= 0 || p.MatchID != shooter.MatchID {
			continue
		}
		if p.Username == shooterName {
			continue
		}
		if p.Team != "" && p.Team == shooter.Team {
			continue // صدای خودی
		}
		if distance(p.X, p.Y, shooter.X, shooter.Y) > botHearing {
			continue
		}
		// بات که همین حالا ردی دارد، با هر تیرِ تازه به این‌ور و آن‌ور
		// کشیده نمی‌شود. بدونِ این شرط، در یک درگیریِ چندنفره هر شلیک
		// همه را دوباره به یک نقطه می‌خواند و گشت‌زنی عملاً از بین می‌رود.
		if b.memory > 1.2 {
			continue
		}
		ex := shooter.X + (rand.Float64()*2-1)*botNoiseError
		ey := shooter.Y + (rand.Float64()*2-1)*botNoiseError
		if a := arenaOf(p); a != nil {
			if nx, ny, ok := a.NearestFree(ex, ey, playerRadius); ok {
				ex, ey = nx, ny
			}
		}
		b.noteSighting(ex, ey)
	}
}

// patrolRevisit چند ثانیه یک اتاق «تازه رفته» حساب می‌شود و انتخابش
// جریمه می‌خورد.
const patrolRevisit = 26.0

// patrolPoint مقصدِ بعدیِ گشت: اتاقِ نزدیکی که تازه سر نزده.
//
// دو تصمیم مهم اینجاست:
//
//	۱. اتاق، نه نقطه‌ی اسپان. نقطه‌های اسپان دورِ هم جمع‌اند، پس گشت با
//	   آن‌ها فقط رفت‌وبرگشت بین دو گوشه می‌شد.
//
//	۲. اتاقِ نزدیک، نه اتاقِ تصادفیِ کلِ نقشه. با انتخابِ یکنواخت، هر بات
//	   به‌طور میانگین به سمتِ وسطِ نقشه راه می‌افتد — هر دو تیم همان اول
//	   وسط به هم می‌رسیدند و باز همان صحنه‌ی «همه یک‌جا» درمی‌آمد.
//	   اندازه‌گیری شد: پراکندگی ۸۱۵ ← ۱۵۷ در ۱۲ ثانیه. این‌طوری بات اول
//	   محله‌ی خودش را می‌گردد و بعد پخش می‌شود.
func patrolPoint(b *BotRuntime, a *Arena, fromX, fromY float64) (float64, float64, bool) {
	if a == nil || len(a.Rooms) == 0 {
		return 0, 0, false
	}
	if b.visited == nil {
		b.visited = map[int]float64{}
	}

	bestIdx, bestCost := -1, math.Inf(1)
	for i, r := range a.Rooms {
		cx, cy := r.Center()
		d := distance(fromX, fromY, cx, cy)
		if d < 240 {
			continue // همین‌جاییم
		}
		cost := d
		// اتاقی که تازه رفته‌ای، انگار خیلی دورتر است
		if age := b.clock - b.visited[i]; b.visited[i] > 0 && age < patrolRevisit {
			cost += 1400 * (1 - age/patrolRevisit)
		}
		// کمی تصادف تا هشت بات با یک نقشه هشت مسیرِ یکسان نروند
		cost *= 0.75 + rand.Float64()*0.5
		if cost < bestCost {
			bestIdx, bestCost = i, cost
		}
	}
	if bestIdx < 0 {
		return 0, 0, false
	}

	r := a.Rooms[bestIdx]
	b.visited[bestIdx] = b.clock
	cx, cy := r.Center()
	jx := (rand.Float64()*2 - 1) * math.Min(r.W*0.30, 140)
	jy := (rand.Float64()*2 - 1) * math.Min(r.H*0.30, 140)
	x, y := cx+jx, cy+jy
	if a.CircleBlocked(x, y, playerRadius) {
		x, y = cx, cy
	}
	if a.CircleBlocked(x, y, playerRadius) {
		return 0, 0, false
	}
	return x, y, true
}
