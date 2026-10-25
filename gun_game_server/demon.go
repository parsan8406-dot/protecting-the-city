package main

import (
	"encoding/json"
	"math"
	"math/rand"
	"time"
)

// «عملیات حذف شیطان» (banish) — حالتِ سوم.
//
// وسطِ نقشه یک شیطان ایستاده. برنده همیشه تیمی است که بیشتر به او آسیب
// زده — نه تیمی که ضربه‌ی آخر را زد. راند با مرگِ شیطان یا تمام شدنِ وقت
// (هرکدام زودتر) تمام می‌شود و در هر دو حالت همین قانون اعمال می‌شود. اگر
// آسیبِ دو تیم برابر بود، هر دو برنده‌اند (endRound).
//
// چرا شیطان بازیکن نیست: اگر داخلِ h.players می‌نشست، هر جایی که روی
// بازیکن‌ها حلقه می‌زند (لیستِ پخش، بمب، بات، راند، ماچ‌میکینگ) باید
// استثنا می‌گرفت. به‌جایش یک شیء مستقل روی خودِ راند است و کلاینت با
// نامِ قراردادیِ DemonTarget به آن شلیک می‌کند — یعنی همان مسیرِ «hit» که
// از قبل اعتبارسنجی دارد، بدونِ پروتکلِ تازه.
//
// همه‌ی این حساب‌ها روی گوروتینِ Hub انجام می‌شود (مثل بات‌ها و راندها)،
// پس قفلی لازم نیست.

// DemonTarget نامی که کلاینت در پیامِ hit می‌فرستد وقتی به شیطان شلیک
// می‌کند. عمداً با «_» شروع می‌شود: نامِ کاربریِ واقعی هیچ‌وقت این شکلی
// نیست، پس با هیچ بازیکنی اشتباه نمی‌شود.
const DemonTarget = "__demon__"

const (
	// DemonMaxHealth جانِ شیطان.
	//
	// عدد از روی خروجیِ واقعیِ تیم حساب شده: سه نفر با خسارتِ متوسطِ ~۲۵ و
	// سرعتِ شلیکِ ~۰.۳ ثانیه یعنی حدود ۲۵۰ خسارت بر ثانیه برای هر تیم. با
	// ۱۲۰۰۰ جان، کشتنش برای یک تیمِ هماهنگ حدود ۲۵ ثانیه‌ی شلیکِ بی‌وقفه
	// است — که با حریفِ زنده در زمین عملاً چند دقیقه طول می‌کشد و راند
	// معمولاً با «آسیبِ بیشتر» تصمیم می‌گیرد، نه با ضربه‌ی آخر.
	DemonMaxHealth = 12000

	// DemonRadius شعاعِ بدنه‌ی شیطان. کلاینت هم همین را می‌گیرد و برخوردش
	// را با همین می‌سازد، پس چیزی که می‌بینی همان است که سرور قبول می‌کند.
	DemonRadius = 96.0

	// DemonBlastEvery / DemonBlastJitter فاصله‌ی بین دو نفرینِ شیطان.
	// جیتر برای این است که بازیکن نتواند روی ثانیه حساب کند.
	DemonBlastEvery  = 6 * time.Second
	DemonBlastJitter = 3 * time.Second

	// DemonBlastWarn چند ثانیه قبل از انفجار، محدوده روی زمین علامت می‌خورد.
	// خواسته‌ی خودِ حالت: «حدود دو ثانیه فرصتِ فرار».
	DemonBlastWarn = 2 * time.Second

	// DemonBlastRadius شعاعِ ناحیه‌ی نفرین
	DemonBlastRadius = 190.0

	// DemonBlastReach دورترین فاصله‌ای از شیطان که نفرین می‌تواند بیفتد.
	// یعنی نفرین فقط «اطرافِ شیطان» را می‌زند، نه کلِ نقشه — کسی که دور
	// است در امان است و کسی که می‌خواهد آسیب بزند باید ریسک کند.
	DemonBlastReach = 660.0

	// DemonBlastDamage خسارتِ نفرین. کشنده نیست ولی دو بار خوردنش هست —
	// ایستادن بی‌حرکت جلوی شیطان نباید جواب بدهد.
	DemonBlastDamage = 55
)

// DemonState وضعیتِ زنده‌ی شیطانِ یک راند
type DemonState struct {
	X, Y      float64
	Health    int
	MaxHealth int
	Radius    float64

	// Damage آسیبی که هر تیم تا حالا زده — همین برنده را در پایانِ وقت
	// تعیین می‌کند. کلیدها همان کلیدهای RoundState.Team اند ("0"/"1").
	Damage map[string]int

	// NextBlastAt لحظه‌ی انتخابِ ناحیه‌ی نفرینِ بعدی
	NextBlastAt time.Time
	// BlastAt لحظه‌ی ترکیدنِ ناحیه‌ی علامت‌خورده. صفر یعنی ناحیه‌ای در
	// انتظار نیست.
	BlastAt        time.Time
	BlastX, BlastY float64

	// KilledByTeam تیمی که ضربه‌ی آخر را زد. خالی یعنی هنوز زنده است.
	// فقط برای ثبت و افکت است — برنده را تعیین نمی‌کند (finishByDamage).
	KilledByTeam string
}

// Alive شیطان هنوز سرِ پاست؟
func (d *DemonState) Alive() bool {
	return d != nil && d.Health > 0
}

// leadingTeam تیمی که بیشترین آسیب را زده و اینکه اصلاً کسی جلو هست.
// دومین مقدار false یعنی برابرند — که در این حالت هر دو تیم برنده‌اند.
func (d *DemonState) leadingTeam() (string, bool) {
	best, bestDmg, tie := "", -1, false
	for team, dmg := range d.Damage {
		switch {
		case dmg > bestDmg:
			best, bestDmg, tie = team, dmg, false
		case dmg == bestDmg:
			tie = true
		}
	}
	if best == "" || bestDmg <= 0 || tie {
		return "", false
	}
	return best, true
}

// newDemon شیطان را وسطِ زمین می‌گذارد.
//
// اگر دقیقاً مرکزِ نقشه داخلِ دیوار افتاده باشد، نزدیک‌ترین جای آزاد
// انتخاب می‌شود — نقشه‌ی banish عمداً میدانِ باز وسط دارد، ولی این
// محافظ باعث می‌شود حالت روی هر نقشه‌ی دیگری هم بالا بیاید.
func newDemon(a *Arena) *DemonState {
	x, y := 1000.0, 560.0
	if a != nil {
		x, y = a.W*0.5, a.H*0.5
		if a.CircleBlocked(x, y, DemonRadius) {
			if fx, fy, ok := a.NearestFree(x, y, DemonRadius); ok {
				x, y = fx, fy
			}
		}
	}
	return &DemonState{
		X: x, Y: y,
		Health:      DemonMaxHealth,
		MaxHealth:   DemonMaxHealth,
		Radius:      DemonRadius,
		Damage:      map[string]int{},
		NextBlastAt: time.Now().Add(DemonHuntWarmup + DemonBlastEvery),
	}
}

// demonOf شیطانِ راندی که این بازیکن در آن است (nil اگر حالتش شیطان ندارد)
func (h *Hub) demonOf(username string) (*RoundState, *DemonState) {
	r := h.roundOf(username)
	if r == nil || r.Ended || r.Demon == nil {
		return nil, nil
	}
	return r, r.Demon
}

// handleDemonHit یک تیر که به شیطان خورده.
//
// دقیقاً همان صافی‌هایی که validateHit روی تیرِ بازیکن-به-بازیکن می‌گذارد
// این‌جا هم هست (حصانت، برد، خطِ دید، مخروطِ نشانه‌روی، تاسِ دقت)، چون
// کلاینت فقط «زدم» می‌فرستد و حرفِ آخر همیشه سرور است.
//
// خروجی true یعنی تیر واقعاً ثبت شد.
func (h *Hub) handleDemonHit(shooter *Player) bool {
	if shooter == nil || shooter.Health <= 0 {
		return false
	}
	r, d := h.demonOf(shooter.Username)
	if d == nil || !d.Alive() {
		return false
	}
	// آتش‌بسِ ابتدای راند شاملِ شیطان هم می‌شود
	if r.InWarmup() {
		return false
	}

	st := statsOf(shooter)
	dx, dy := d.X-shooter.X, d.Y-shooter.Y
	dist := math.Hypot(dx, dy)
	// فاصله تا بدنه‌ی شیطان، نه تا مرکزش — وگرنه با هدفی به این بزرگی
	// «چسبیده ولی خارج از برد» ممکن می‌شد
	if dist-d.Radius > st.MaxRange {
		return false
	}
	// خطِ دید تا لبه‌ی بدنه: دیوارِ وسط جلوی تیر را می‌گیرد
	if a := arenaOf(shooter); a != nil && dist > 0 {
		edgeX := d.X - dx/dist*d.Radius
		edgeY := d.Y - dy/dist*d.Radius
		if !a.HasLineOfSight(shooter.X, shooter.Y, edgeX, edgeY) {
			return false
		}
	}
	// باید واقعاً رو به او باشی
	toTarget := math.Atan2(dy, dx) + math.Pi/2
	if math.Abs(angleDiff(shooter.Rot, toTarget)) > degToRad(st.FireConeDeg) {
		return false
	}
	if rand.Float64() < st.MissChance {
		return false
	}

	h.damageDemon(r, shooter.Team, statsOf(shooter).Damage)
	return true
}

// damageDemon خسارت را روی شیطان و روی کارنامه‌ی تیم می‌نشاند.
//
// team خالی (تمرینِ بی‌تیم) خسارت می‌زند ولی امتیازی ثبت نمی‌کند — وگرنه
// کلیدِ خالی در جدولِ آسیب می‌نشست و leadingTeam برنده‌ی بی‌نام می‌داد.
func (h *Hub) damageDemon(r *RoundState, team string, dmg int) {
	d := r.Demon
	if d == nil || !d.Alive() || dmg <= 0 {
		return
	}
	if dmg > d.Health {
		dmg = d.Health
	}
	d.Health -= dmg
	if team != "" {
		d.Damage[team] += dmg
	}

	if d.Health > 0 {
		h.broadcastDemonState(r)
		return
	}

	// --- شیطان افتاد: راند تمام است، ولی برنده را آسیبِ کل تعیین می‌کند ---
	//
	// عمداً «ضربه‌ی آخر» برنده نیست. با آن قانون، تیمی که کلِ راند شیطان را
	// زده بود می‌توانست در ثانیه‌ی آخر به یک تیرِ حریف ببازد — یعنی بهترین
	// بازی دزدیِ ضربه‌ی آخر بود، نه آسیب زدن. حالا مردنِ شیطان فقط ساعت را
	// زودتر تمام می‌کند و قانون همان قانونِ پایانِ وقت است.
	d.Health = 0
	d.KilledByTeam = team
	d.BlastAt = time.Time{} // نفرینِ در انتظار با مرگش می‌میرد
	h.broadcastDemonState(r)
	h.broadcastDemonSlain(r, team)
	h.finishByDamage(r)
}

// finishByDamage راند را با قانونِ «بیشترین آسیب» می‌بندد — هم وقتی شیطان
// می‌میرد و هم وقتی وقت تمام می‌شود. آسیبِ برابر = مساوی = هر دو برنده.
func (h *Hub) finishByDamage(r *RoundState) {
	if winner, ok := r.Demon.leadingTeam(); ok {
		h.endRound(r, winner, false)
		return
	}
	h.endRound(r, "", true)
}

// tickDemon چرخه‌ی نفرینِ شیطان. از tickRounds صدا زده می‌شود.
//
// دو مرحله دارد و عمداً همین‌طور: اول ناحیه علامت می‌خورد و به کلاینت
// خبر می‌رود (تا بازیکن دو ثانیه فرصتِ فرار داشته باشد)، بعد سرِ وقت
// می‌ترکد. تصمیمِ «چه کسی داخلش بود» لحظه‌ی ترکیدن گرفته می‌شود، نه
// لحظه‌ی علامت خوردن — وگرنه فرار کردن بی‌فایده بود.
func (h *Hub) tickDemon(r *RoundState, now time.Time) {
	d := r.Demon
	if d == nil || !d.Alive() || r.InWarmup() {
		return
	}

	// ناحیه‌ی علامت‌خورده سرِ وقتش می‌ترکد
	if !d.BlastAt.IsZero() && now.After(d.BlastAt) {
		x, y := d.BlastX, d.BlastY
		d.BlastAt = time.Time{}
		h.detonateDemonBlast(r, x, y)
		return
	}

	// نفرینِ بعدی
	if d.BlastAt.IsZero() && now.After(d.NextBlastAt) {
		x, y, ok := h.pickBlastSpot(r, d)
		if !ok {
			// جای مناسبی پیدا نشد (نقشه‌ی تنگ) — کمی بعد دوباره
			d.NextBlastAt = now.Add(time.Second)
			return
		}
		d.BlastX, d.BlastY = x, y
		d.BlastAt = now.Add(DemonBlastWarn)
		d.NextBlastAt = d.BlastAt.Add(DemonBlastEvery +
			time.Duration(rand.Int63n(int64(DemonBlastJitter))))
		h.broadcastDemonBlastWarn(r, x, y)
	}
}

// pickBlastSpot ناحیه‌ی نفرینِ بعدی را انتخاب می‌کند.
//
// ترجیح با جایی است که کسی رویش ایستاده: نفرینی که همیشه روی زمینِ خالی
// بیفتد فقط یک چراغانیِ بی‌خطر است. ولی حتی وقتی کسی آن‌جا نیست هم یک
// نقطه‌ی تصادفیِ اطرافِ شیطان انتخاب می‌شود تا ریتمِ حالت حفظ شود.
func (h *Hub) pickBlastSpot(r *RoundState, d *DemonState) (float64, float64, bool) {
	a := ArenaForMode(r.ModeID)

	// ۱) کسی نزدیکِ شیطان هست؟ روی سرش
	var near []*Player
	for _, p := range h.players {
		if p.MatchID != r.MatchID || p.Health <= 0 {
			continue
		}
		if distance(p.X, p.Y, d.X, d.Y) <= DemonBlastReach {
			near = append(near, p)
		}
	}
	if len(near) > 0 {
		p := near[rand.Intn(len(near))]
		// دقیقاً روی خودش نه — کمی کنارتر، تا راه رفتن از مرکز جواب بدهد
		ang := rand.Float64() * 2 * math.Pi
		off := DemonBlastRadius * 0.45
		x := p.X + math.Cos(ang)*off
		y := p.Y + math.Sin(ang)*off
		if a == nil || !a.CircleBlocked(x, y, 24) {
			return x, y, true
		}
		return p.X, p.Y, true
	}

	// ۲) وگرنه یک حلقه‌ی تصادفی دورِ شیطان
	for i := 0; i < 24; i++ {
		ang := rand.Float64() * 2 * math.Pi
		rad := d.Radius + 60 + rand.Float64()*(DemonBlastReach-d.Radius-60)
		x := d.X + math.Cos(ang)*rad
		y := d.Y + math.Sin(ang)*rad
		if a != nil && a.CircleBlocked(x, y, 24) {
			continue
		}
		return x, y, true
	}
	return 0, 0, false
}

// detonateDemonBlast نفرین می‌ترکد: هر که داخلِ شعاع و در دیدِ مرکزِ
// انفجار باشد خسارت می‌خورد.
//
// مهاجم عمداً nil است: مرگ با نفرینِ شیطان به حسابِ هیچ تیمی نوشته
// نمی‌شود (creditKill هم با مهاجمِ خالی چیزی ثبت نمی‌کند).
func (h *Hub) detonateDemonBlast(r *RoundState, x, y float64) {
	h.broadcastDemonBlast(r, x, y)

	now := time.Now()
	for _, p := range h.players {
		if p.MatchID != r.MatchID || p.Health <= 0 {
			continue
		}
		// محافظِ تولد و سپرِ دستی جلوی نفرین را هم می‌گیرند
		if !canBeHurt(p, now) {
			continue
		}
		if distance(x, y, p.X, p.Y) > DemonBlastRadius {
			continue
		}
		// موجِ نفرین هم مثل بمب از دیوار رد نمی‌شود
		if a := arenaOf(p); a != nil && !a.HasLineOfSight(x, y, p.X, p.Y) {
			continue
		}
		h.applyDamage(nil, p, DemonBlastDamage, false)
	}
}

// ----------------------------------------------------------------- بات‌ها

// botHuntDemon بات وقتی حریفی نمی‌بیند سراغِ شیطان می‌رود.
//
// بدونِ این، بات‌ها کلِ راند را گشت می‌زدند و هیچ آسیبی به شیطان
// نمی‌رساندند — یعنی تیمی که آدم داشت بی‌رقیب برنده می‌شد و تیمِ بات‌ها
// عملاً در این حالت بازی نمی‌کرد.
//
// خروجی true یعنی «حواسم به شیطان است»، پس stepBot دیگر گشت نمی‌زند.
func (h *Hub) botHuntDemon(b *BotRuntime, p *Player, dt float64) bool {
	r, d := h.demonOf(p.Username)
	if d == nil || !d.Alive() || r.InWarmup() {
		return false
	}

	st := statsOf(p)
	dx, dy := d.X-p.X, d.Y-p.Y
	dist := math.Hypot(dx, dy)
	if dist < 1 {
		return false
	}
	edgeX, edgeY := d.X-dx/dist*d.Radius, d.Y-dy/dist*d.Radius

	los := true
	if a := arenaOf(p); a != nil {
		los = a.HasLineOfSight(p.X, p.Y, edgeX, edgeY)
	}
	// کمی محافظه‌کارتر از بردِ واقعی، تا بات ته‌ی برد نایستد و تیرش هدر نرود
	inRange := dist-d.Radius <= st.MaxRange*0.85

	if !los || !inRange {
		h.advanceAlongPath(b, p, d.X, d.Y, dt)
		return true
	}

	// چسبیدن به شیطان یعنی خوردنِ هر نفرین. فاصله‌ی راحت را نگه دار.
	if stand := d.Radius + 190; dist < stand {
		h.moveBot(b, p, -dx/dist, -dy/dist, dt)
		return true
	}

	want := math.Atan2(dy, dx) + math.Pi/2
	p.Rot = clampRotation(p.Rot, want, turnStep(p, dt)*b.prof.AimTurnMul)
	h.broadcastMove(p.Username, p.X, p.Y, p.Rot)
	b.path = nil

	if b.shotCD > 0 || math.Abs(angleDiff(p.Rot, want)) > degToRad(st.FireConeDeg) {
		return true
	}
	b.shotCD = st.FireCooldown
	// همان مسیرِ botShoot: اول افکتِ شلیک (پس کلاینت بات را از آدم تشخیص
	// نمی‌دهد)، بعد تاس‌های سرور
	h.broadcastShoot(p.Username, p.X, p.Y, p.Rot)
	h.dropSpawnShield(p)
	if rand.Float64() < st.MissChance+b.prof.ExtraMiss {
		return true
	}
	dmg := int(float64(st.Damage) * b.prof.DamageMul)
	if dmg < 1 {
		dmg = 1
	}
	h.damageDemon(r, p.Team, dmg)
	return true
}

// ----------------------------------------------------------------- پخش

// broadcastDemonState جان و جای شیطان + کارنامه‌ی آسیبِ دو تیم.
//
// کلاینت نوارِ جانِ بالای صفحه، نشانِ مینی‌مپ و فلشِ راهنما را از همین
// می‌سازد؛ هیچ عددی را خودش حساب نمی‌کند.
func (h *Hub) broadcastDemonState(r *RoundState) {
	d := r.Demon
	if d == nil {
		return
	}
	data, _ := json.Marshal(map[string]interface{}{
		"type":       "demon_state",
		"match_id":   r.MatchID,
		"x":          d.X,
		"y":          d.Y,
		"health":     d.Health,
		"max_health": d.MaxHealth,
		"radius":     d.Radius,
		"damage":     d.Damage,
		"alive":      d.Alive(),
	})
	h.queueBroadcastTo(r.MatchID, data)
}

// broadcastDemonBlastWarn ناحیه‌ی نفرین علامت خورد — دو ثانیه فرصتِ فرار
func (h *Hub) broadcastDemonBlastWarn(r *RoundState, x, y float64) {
	data, _ := json.Marshal(map[string]interface{}{
		"type":   "demon_blast_warn",
		"x":      x,
		"y":      y,
		"radius": DemonBlastRadius,
		"delay":  DemonBlastWarn.Seconds(),
	})
	h.queueBroadcastTo(r.MatchID, data)
}

// broadcastDemonBlast ناحیه ترکید
func (h *Hub) broadcastDemonBlast(r *RoundState, x, y float64) {
	data, _ := json.Marshal(map[string]interface{}{
		"type":   "demon_blast",
		"x":      x,
		"y":      y,
		"radius": DemonBlastRadius,
	})
	h.queueBroadcastTo(r.MatchID, data)
}

// broadcastDemonSlain شیطان افتاد. کلاینت همین را برای افکتِ مرگش
// استفاده می‌کند؛ نتیجه‌ی راند (بر اساسِ آسیبِ کل) جدا با match_over می‌آید.
func (h *Hub) broadcastDemonSlain(r *RoundState, team string) {
	data, _ := json.Marshal(map[string]interface{}{
		"type": "demon_slain",
		"team": team,
		"x":    r.Demon.X,
		"y":    r.Demon.Y,
	})
	h.queueBroadcastTo(r.MatchID, data)
}
