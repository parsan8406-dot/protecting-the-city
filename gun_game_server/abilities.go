package main

import (
	"encoding/json"
	"math"
	"time"
)

// توانایی‌های دکمه‌ایِ زمینِ بازی: دویدن، سپر، لیزر، درمانِ تیمی و موجودیِ بمب.
//
// همه‌ی عددها همین‌جاست و کلاینت فقط نمایششان می‌دهد. هر توانایی دو زمان
// دارد: «فعال» (مثلاً چهار ثانیه سپر) و «قفل» که بعد از تمام شدنِ فعال
// می‌شمارد (مثلاً ۲۲ ثانیه). سرور هر دو را در پیامِ ability می‌فرستد و
// کلاینت شمارش‌معکوسِ دکمه را از روی همان می‌سازد — پس دکمه هیچ‌وقت زودتر
// از چیزی که سرور قبول می‌کند باز نمی‌شود.
//
// کول‌داون‌ها مثل bombCooldowns بر اساس نام کاربری نگه داشته می‌شوند، نه روی
// Player: وگرنه قطع و وصلِ دوباره Player تازه می‌ساخت و همه‌چیز آزاد می‌شد.
const (
	// BombStock کلِ بمب‌های هر بازیکن در یک مسابقه
	BombStock = 3

	SprintDuration  = 5 * time.Second
	SprintCooldown  = 20 * time.Second
	SprintSpeedMult = 1.2
	// sprintGrace بعد از تمام شدنِ دویدن، چند صد میلی‌ثانیه هنوز حرکتِ تند
	// قبول می‌شود — پیام‌های حرکتی که در راه‌اند نباید اصلاحِ موقعیت بخورند.
	sprintGrace = 400 * time.Millisecond

	// سپر کوتاه است و با اولین حمله‌ی خودِ صاحبش می‌شکند (dropSpawnShield)
	GuardDuration = 2500 * time.Millisecond
	GuardCooldown = 22 * time.Second

	LaserDuration = 3 * time.Second
	LaserCooldown = 25 * time.Second
	// LaserRange طولِ پرتو وقتی دیواری جلویش نیست
	LaserRange = 900.0
	// LaserHalfWidth نصفِ پهنای پرتو؛ با شعاعِ بازیکن جمع می‌شود
	LaserHalfWidth = 14.0
	// LaserDamageFrac کسی که تمامِ سه ثانیه داخلِ پرتو بماند این کسر از
	// سقفِ جانش را از دست می‌دهد — کمتر ماندن یعنی خسارتِ کمتر
	LaserDamageFrac = 0.60
	LaserTickEvery  = 250 * time.Millisecond

	// TeamHealRadius هم‌تیمی‌های داخلِ این شعاع (و خودِ درمان‌کننده) جان می‌گیرند
	TeamHealRadius   = 320.0
	TeamHealCooldown = 20 * time.Second
)

// laserTicks تعدادِ ضربه‌های یک پرتوِ کامل
const laserTicks = int(LaserDuration / LaserTickEvery)

// کلیدِ کول‌داونِ هر توانایی در hub.abilityCooldowns
func abilityKey(username, kind string) string { return kind + ":" + username }

// bombStockKey بمب‌ها به ازای هر مسابقه شمرده می‌شوند، نه برای همیشه
func bombStockKey(p *Player) string { return p.MatchID + ":" + p.Username }

// bombsLeftFor بمب‌های باقی‌مانده‌ی یک بازیکن در مسابقه‌ی فعلی‌اش
func (h *Hub) bombsLeftFor(p *Player) int {
	left := BombStock - h.bombsUsed[bombStockKey(p)]
	if left < 0 {
		return 0
	}
	return left
}

// prepareBombStock موجودیِ بمبِ بازیکنی که همین حالا join کرده.
//
// در مسابقه، شمارنده‌ی همان مسابقه ادامه پیدا می‌کند — join دوباره پرش
// نمی‌کند. زمینِ تمرین (بدونِ مسابقه) پایانِ راندی ندارد که شمارنده را پاک
// کند، پس هر ورود به آن یک بازیِ تازه است و موجودی از نو پر می‌شود؛ وگرنه
// بعد از سه بمب بازیکن تا ابد بی‌بمب می‌ماند.
func (h *Hub) prepareBombStock(p *Player, arenaJoin bool) {
	if arenaJoin && p.MatchID == "" {
		delete(h.bombsUsed, bombStockKey(p))
	}
	p.BombsLeft = h.bombsLeftFor(p)
}

// freshKit هر زندگیِ تازه با تجهیزاتِ کامل شروع می‌شود: سه بمب، همه‌ی
// توانایی‌ها و درمان آماده، و هیچ اثرِ فعالی (دویدن، سپر، لیزر) از زندگیِ
// قبلی نمی‌ماند. جان را خودِ respawnInRound پر می‌کند.
//
// قبلاً بمب‌ها برای کلِ مسابقه شمرده می‌شدند و قفل‌ها هم می‌ماندند؛ کسی که
// سه بمبش را خرج کرده بود و مُرد، تا آخرِ مسابقه بی‌بمب برمی‌گشت.
func (h *Hub) freshKit(p *Player) {
	delete(h.bombsUsed, bombStockKey(p))
	p.BombsLeft = BombStock
	delete(h.bombCooldowns, p.Username)
	for _, kind := range []string{"sprint", "guard", "laser", "team_heal"} {
		delete(h.abilityCooldowns, abilityKey(p.Username, kind))
	}
	p.LastHealTime = time.Time{}
	p.SprintUntil = time.Time{}
	p.GuardUntil = time.Time{}
	p.LaserUntil = time.Time{}
}

// abilityReady آیا قفلِ این توانایی باز شده؟
func (h *Hub) abilityReady(username, kind string, now time.Time) bool {
	until, ok := h.abilityCooldowns[abilityKey(username, kind)]
	return !ok || !now.Before(until)
}

// lockAbility توانایی را تا لحظه‌ی until قفل می‌کند
func (h *Hub) lockAbility(username, kind string, until time.Time) {
	h.abilityCooldowns[abilityKey(username, kind)] = until
	if len(h.abilityCooldowns) < 512 {
		return
	}
	now := time.Now()
	for k, t := range h.abilityCooldowns {
		if now.After(t) {
			delete(h.abilityCooldowns, k)
		}
	}
}

// livePlayerOf بازیکنِ زنده‌ی پشتِ این کلاینت، یا nil
func (h *Hub) livePlayerOf(client *Client) *Player {
	if client == nil || client.username == "" {
		return nil
	}
	p, ok := h.players[client.username]
	// غایب (اتصالش افتاده) هیچ توانایی‌ای نمی‌زند — reconnect.go
	if !ok || p.Health <= 0 || p.Away {
		return nil
	}
	return p
}

// handleAbility پیام‌های sprint / guard / laser / team_heal
func (h *Hub) handleAbility(client *Client, kind string) {
	p := h.livePlayerOf(client)
	if p == nil {
		return
	}
	now := time.Now()
	if !h.abilityReady(p.Username, kind, now) {
		return
	}

	switch kind {
	case "sprint":
		p.SprintUntil = now.Add(SprintDuration)
		h.lockAbility(p.Username, kind, now.Add(SprintDuration+SprintCooldown))
		h.broadcastAbility(p, kind, SprintDuration, SprintCooldown, nil)

	case "guard":
		p.GuardUntil = now.Add(GuardDuration)
		h.lockAbility(p.Username, kind, now.Add(GuardDuration+GuardCooldown))
		h.broadcastAbility(p, kind, GuardDuration, GuardCooldown, nil)

	case "laser":
		// لیزر هم حمله است: گنبدِ تولد با آن می‌رود (مثل تیر و بمب)
		h.dropSpawnShield(p)
		p.LaserUntil = now.Add(LaserDuration)
		p.LaserNextTick = now
		h.lockAbility(p.Username, kind, now.Add(LaserDuration+LaserCooldown))
		h.broadcastAbility(p, kind, LaserDuration, LaserCooldown, map[string]interface{}{
			"range": LaserRange, "half_width": LaserHalfWidth,
		})

	case "team_heal":
		healed, others := h.teamHeal(p)
		// اگر هیچ‌کس جان نگرفت (همه سالم‌اند) قفل نمی‌شود — دکمه هدر نرود
		if healed == 0 {
			return
		}
		h.lockAbility(p.Username, kind, now.Add(TeamHealCooldown))
		h.broadcastAbility(p, kind, 0, TeamHealCooldown, map[string]interface{}{
			"radius": TeamHealRadius,
		})
		if others > 0 {
			h.noteHealsGiven(p.Username, others)
		}
	}
}

// teamHeal درمان‌کننده و هم‌تیمی‌های زنده‌ی داخلِ شعاع را درمان می‌کند.
// خروجی: چند نفر جان گرفتند، و چند نفرشان غیر از خودش بودند.
//
// مقدارِ درمان همان health_regenِ کاراکترِ درمان‌کننده است (HealAmount) —
// همان عددی که دکمه‌ی درمانِ شخصی هم می‌دهد.
func (h *Hub) teamHeal(p *Player) (healed, others int) {
	amount := statsOf(p).HealAmount
	for name, o := range h.players {
		if o.MatchID != p.MatchID || o.Health <= 0 {
			continue
		}
		if o != p && (p.Team == "" || o.Team != p.Team) {
			continue
		}
		if distance(p.X, p.Y, o.X, o.Y) > TeamHealRadius {
			continue
		}
		maxHP := statsOf(o).Health
		if o.Health >= maxHP {
			continue
		}
		o.Health += amount
		if o.Health > maxHP {
			o.Health = maxHP
		}
		h.broadcastHealSuccess(name, o.Health)
		healed++
		if o != p {
			others++
		}
	}
	return healed, others
}

// isGuarded آیا این بازیکن همین حالا سپرِ دستی دارد؟
func isGuarded(p *Player, now time.Time) bool {
	return p != nil && now.Before(p.GuardUntil)
}

// canBeHurt هدف همین حالا آسیب‌پذیر است؟ (نه محافظِ تولد، نه سپرِ دستی،
// نه غایبی که اتصالش افتاده و جایش نگه داشته شده — reconnect.go)
func canBeHurt(p *Player, now time.Time) bool {
	return p != nil && p.Health > 0 && !p.Away && !now.Before(p.InvulnerableUntil) && !isGuarded(p, now)
}

// ----------------------------------------------------------------- لیزر

// tickAbilities ضربه‌های لیزرهای فعال. از تیکِ بات‌ها صدا زده می‌شود، پس
// روی همان گوروتینِ Hub است و قفلی لازم ندارد.
func (h *Hub) tickAbilities(now time.Time) {
	for _, p := range h.players {
		if p.LaserUntil.IsZero() {
			continue
		}
		// ضربه‌های عقب‌افتاده (اگر تیک دیر رسیده) هم زده می‌شوند، ولی هیچ‌وقت
		// بیشتر از laserTicks تا — LaserNextTick از LaserUntil جلوتر نمی‌رود
		for p.Health > 0 && !now.Before(p.LaserNextTick) && p.LaserNextTick.Before(p.LaserUntil) {
			p.LaserNextTick = p.LaserNextTick.Add(LaserTickEvery)
			h.laserTick(p, now)
		}
		if p.Health <= 0 || !now.Before(p.LaserUntil) {
			// مرده‌ها پرتو ندارند؛ تمام‌شده هم پاک می‌شود تا دیگر نچرخد
			p.LaserUntil = time.Time{}
		}
	}
}

// laserSegment پرتو از خودِ بازیکن، رو به جایی که نگاه می‌کند (Rotِ سرور،
// که خودش سقفِ چرخش دارد)، تا اولین دیوار یا تهِ برد.
func laserSegment(p *Player) (x1, y1, x2, y2 float64) {
	dx := math.Cos(p.Rot - math.Pi/2)
	dy := math.Sin(p.Rot - math.Pi/2)
	x1, y1 = p.X, p.Y
	x2, y2 = x1+dx*LaserRange, y1+dy*LaserRange
	if a := arenaOf(p); a != nil {
		x2, y2 = a.RayHitPoint(x1, y1, x2, y2)
	}
	return
}

// segmentHitsCircle آیا دایره‌ای به مرکز (cx,cy) و شعاع r پاره‌خطِ AB را قطع می‌کند؟
func segmentHitsCircle(ax, ay, bx, by, cx, cy, r float64) bool {
	abx, aby := bx-ax, by-ay
	l2 := abx*abx + aby*aby
	t := 0.0
	if l2 > 0 {
		t = ((cx-ax)*abx + (cy-ay)*aby) / l2
		t = math.Max(0, math.Min(1, t))
	}
	px, py := ax+abx*t, ay+aby*t
	return math.Hypot(cx-px, cy-py) <= r
}

// laserTickDamage خسارتِ یک ضربه — جمعِ همه‌ی ضربه‌ها LaserDamageFrac است
func laserTickDamage(maxHP int) int {
	d := int(math.Ceil(float64(maxHP) * LaserDamageFrac / float64(laserTicks)))
	if d < 1 {
		d = 1
	}
	return d
}

// laserTick یک ضربه‌ی پرتو. پرتو از بدن‌ها رد می‌شود (هرکه پشتِ هدفِ اول
// هم در مسیر باشد می‌خورد) ولی از دیوار نه — laserSegment تهِ پرتو را روی
// اولین دیوار گذاشته.
func (h *Hub) laserTick(p *Player, now time.Time) {
	x1, y1, x2, y2 := laserSegment(p)
	for _, o := range h.players {
		if o == p || o.MatchID != p.MatchID {
			continue
		}
		if p.Team != "" && o.Team == p.Team {
			continue
		}
		if !canBeHurt(o, now) {
			continue
		}
		if !segmentHitsCircle(x1, y1, x2, y2, o.X, o.Y, LaserHalfWidth+playerRadius) {
			continue
		}
		h.applyDamage(p, o, laserTickDamage(statsOf(o).Health), false)
	}
}

// applyDamage خسارت و مرگ — یک مسیرِ مشترک برای ترکش و لیزر، تا کشته،
// امتیازِ راند و پایانِ راند هر بار یک‌جور ثبت شوند.
func (h *Hub) applyDamage(attacker, target *Player, dmg int, grenade bool) {
	// مُرده دوباره نمی‌میرد — دو بات که در یک تیک یک هدف را بزنند نباید دو
	// «کشتن» ثبت کنند
	if target.Health <= 0 {
		return
	}
	if attacker != nil {
		h.noteDamage(attacker.Username, target.Username)
	}
	target.Health -= dmg
	if target.Health > 0 {
		h.broadcastHealth(target.Username, target.Health)
		return
	}
	target.Health = 0
	target.Deaths++
	if attacker != nil {
		attacker.Kills++
		if h.creditKill(attacker.Username, target.Username) && grenade {
			h.noteGrenadeKill(attacker.Username)
		}
	}
	h.broadcastHealth(target.Username, 0)
	killer, weapon := "", "laser"
	if grenade {
		weapon = "bomb"
	}
	if attacker != nil {
		killer = attacker.Username
	}
	h.broadcastDeath(target.Username, killer, weapon)
	// بدونِ این، مرگ در راند ثبت نمی‌شد و راند تا تهِ تایمر بی‌خود می‌ماند
	h.onPlayerEliminated(target.Username)
}

// ----------------------------------------------------------------- پخش

// broadcastAbility به همه‌ی مسابقه می‌گوید چه کسی چه توانایی‌ای زد.
// active و cooldown ثانیه‌اند؛ extra چیزهای مخصوصِ هر توانایی (شعاع، برد، ...).
func (h *Hub) broadcastAbility(p *Player, kind string, active, cooldown time.Duration, extra map[string]interface{}) {
	payload := map[string]interface{}{
		"type":     "ability",
		"username": p.Username,
		"kind":     kind,
		"active":   active.Seconds(),
		"cooldown": cooldown.Seconds(),
		"x":        p.X,
		"y":        p.Y,
	}
	for k, v := range extra {
		payload[k] = v
	}
	data, _ := json.Marshal(payload)
	h.queueBroadcastTo(p.MatchID, data)
}

// refreshAbilityTimers ثانیه‌های باقی‌مانده را برای لیستِ بازیکن‌ها پر می‌کند
func refreshAbilityTimers(p *Player, now time.Time) {
	p.GuardLeft, p.SprintLeft, p.LaserLeft = 0, 0, 0
	if left := p.GuardUntil.Sub(now).Seconds(); left > 0 {
		p.GuardLeft = left
	}
	if left := p.SprintUntil.Sub(now).Seconds(); left > 0 {
		p.SprintLeft = left
	}
	if left := p.LaserUntil.Sub(now).Seconds(); left > 0 {
		p.LaserLeft = left
	}
}
