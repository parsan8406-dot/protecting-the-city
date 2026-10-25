package main

import (
	"fmt"
	"math"
	"math/rand"
	"time"
)

// هوشِ بات‌ها، سمتِ سرور.
//
// چرا سرور و نه کلاینت: سرور همین حالا مرجعِ حرکت، خطِ دید و خسارت است.
// اگر بات را روی کلاینت اجرا می‌کردیم، در مسابقه‌ای با دو آدم هر کلاینت
// نسخه‌ی خودش را از بات می‌ساخت و دو نفر دو چیزِ متفاوت می‌دیدند. این‌طوری
// بات دقیقاً از همان مسیری می‌آید که یک آدم می‌آید (broadcastMove/Shoot)،
// پس کلاینت اصلاً نمی‌تواند تشخیصش بدهد — که خواسته‌ی اصلی بود.
//
// همه‌ی تغییرِ وضعیت روی گوروتینِ Hub انجام می‌شود (کانالِ botTick)، پس
// h.players هیچ‌وقت هم‌زمان از دو گوروتین دست نمی‌خورد.

// botTickRate هر ثانیه چند بار بات‌ها فکر و حرکت کنند.
// ۱۵ برای حرکتِ نرم کافی است و بارِ سرور را پایین نگه می‌دارد.
const botTickRate = 15

// botRespawnDelay بعد از مرگ چقدر صبر کند
const botRespawnDelay = 3.5 * float64(time.Second) / float64(time.Second)

// botSkillProfile تفاوتِ سه سطحِ مهارت.
//
// عمداً هیچ‌کدام روی خسارت یا جانِ بات اثر ندارند — آن‌ها از تجهیزاتِ خودِ
// اکانتِ بات می‌آیند، مثل هر آدمِ دیگری. چیزی که فرق می‌کند «آدم بودن» است:
// سرعتِ واکنش، دقتِ نشانه‌گیری و اینکه چقدر خوب پوشش می‌گیرد.
type botSkillProfile struct {
	Reaction  float64 // ثانیه: از دیدنِ هدف تا اولین شلیک
	AimJitter float64 // رادیان: خطای ثابتِ نشانه‌گیری
	// AimTurnMul چقدر سریع‌تر/کندتر از سرعتِ چرخشِ خودِ کاراکتر نشانه
	// می‌گیرد. سرعتِ چرخشِ پایه از کاراکتر می‌آید (مثل آدم)؛ این فقط
	// تفاوتِ مهارت است: بازیکنِ ضعیف دیرتر روی هدف قفل می‌کند.
	AimTurnMul float64
	ExtraMiss  float64 // احتمالِ خطای اضافه روی MissChanceِ خودِ کاراکتر
	// DamageMul ضریبِ خسارتِ بات نسبت به همان تجهیزات در دستِ یک آدم.
	//
	// چرا لازم است: بات‌ها اکانتِ واقعی‌اند و تجهیزاتِ واقعی دارند، پس
	// خسارتشان با آدم برابر بود. نتیجه این می‌شد که هشت نفر در چند ثانیه
	// همدیگر را تمام می‌کردند و راند قبل از اینکه بازیکن کاری کند تمام
	// می‌شد. این ضریب فقط روی بات اثر دارد و به ترازِ آدم‌ها دست نمی‌زند.
	DamageMul  float64
	EngageMul  float64 // ضریبِ بردِ درگیری
	StrafeFreq float64 // هر چند ثانیه جهتِ کنارکشی عوض شود
}

func profileFor(skill string) botSkillProfile {
	switch skill {
	// اعدادِ خطا عمداً بالا هستند. با دقتِ نزدیک‌به‌کامل، هشت باتِ ۴v۴ در
	// چند ثانیه همدیگر را تمام می‌کردند و راند قبل از اینکه بازیکن اصلاً
	// وارد شود تمام می‌شد. بات باید حریفِ قابلِ‌شکست باشد، نه ماشینِ کشتار.
	case BotSkillHard:
		return botSkillProfile{Reaction: 0.30, AimJitter: 0.04, AimTurnMul: 1.00,
			ExtraMiss: 0.18, EngageMul: 1.10, StrafeFreq: 1.8, DamageMul: 0.80}
	case BotSkillEasy:
		return botSkillProfile{Reaction: 0.95, AimJitter: 0.16, AimTurnMul: 0.55,
			ExtraMiss: 0.48, EngageMul: 0.80, StrafeFreq: 3.4, DamageMul: 0.45}
	default: // medium
		return botSkillProfile{Reaction: 0.55, AimJitter: 0.09, AimTurnMul: 0.78,
			ExtraMiss: 0.32, EngageMul: 1.00, StrafeFreq: 2.6, DamageMul: 0.62}
	}
}

// BotRuntime وضعیتِ زنده‌ی یک بات داخلِ مسابقه
type BotRuntime struct {
	Username string
	Skill    string
	prof     botSkillProfile

	// --- مسیر ---
	path     []PathPoint
	pathIdx  int
	repathIn float64
	// goal مقصدی که مسیرِ فعلی برایش حساب شده — اگر هدف زیاد جابه‌جا شود
	// دوباره مسیریابی می‌کنیم
	goalX, goalY float64

	// --- درگیری ---
	targetName string
	seenFor    float64 // چند ثانیه است هدف را می‌بیند (برای تاخیرِ واکنش)
	shotCD     float64
	// ammo / reloadLeft خشابِ بات، با همان قانونِ بازیکنِ آدم (MagSize و
	// ReloadSeconds). بدونِ این بات‌ها بی‌وقفه شلیک می‌کردند و هیچ لحظه‌ای
	// برای هجوم بردن به آن‌ها پیش نمی‌آمد.
	ammo       int
	reloadLeft float64
	healCD     float64
	strafeDir  float64
	strafeIn   float64
	deadFor    float64

	// roamX/roamY وقتی هیچ هدفی نیست، بات بی‌حرکت نمی‌ایستد — گشت می‌زند
	roamX, roamY float64
	hasRoam      bool

	// --- ادراک (bot_sense.go) ---
	// lastSeenX/Y آخرین جایی که ردی از حریف پیدا کرد: یا با چشم دید، یا
	// صدای شلیکش را شنید. memory شمارشِ معکوسِ فراموش کردنِ همان رد است.
	lastSeenX, lastSeenY float64
	memory               float64
	// lookFor/lookDir ایستِ کوتاهِ سرِ هر مقصدِ گشت: بات می‌ایستد و دور و
	// برش را نگاه می‌کند. بدونِ این، گشت‌زنی فقط دویدنِ بی‌وقفه بین اتاق‌ها
	// می‌شود و اصلاً شبیه «گشتن» نیست.
	lookFor float64
	lookDir float64
	// visited آخرین باری که سرِ هر اتاق رفته (بر حسبِ clock). گشت‌زنی از
	// همین می‌فهمد کجا را تازه دیده و کجا را نه.
	visited map[int]float64
	clock   float64
}

// AddBot یک بات را وارد بازی می‌کند. دقیقاً همان کاری را می‌کند که caseِ
// "join" برای یک آدم می‌کند: تجهیزات از دیتابیس، نقطه‌ی شروع از سرور.
func (h *Hub) AddBot(username, skill, team, matchID string, seat, teamSize int, a *Arena) {
	if _, exists := h.players[username]; exists {
		return
	}
	charID, weaponID, charLevel, charSkin, weaponSkin := equippedFor(username, "skin_default", "ak47")
	charID, weaponID, charLevel, charSkin, weaponSkin = gentleBotLoadout(skill,
		charID, weaponID, charLevel, charSkin, weaponSkin)
	maxHealth := CharacterStatsAtLevel(charID, charLevel).Health

	if a == nil {
		a = arena
	}
	spawnX, spawnY := 0.0, 0.0
	if a != nil {
		occupied := make([][2]float64, 0, len(h.players))
		for _, p := range h.players {
			if p.MatchID == matchID {
				occupied = append(occupied, [2]float64{p.X, p.Y})
			}
		}
		if matchID != "" {
			teamNo := 0
			if team == "1" {
				teamNo = 1
			}
			spawnX, spawnY = a.TeamSpawn(matchID, teamNo, seat, teamSize, occupied)
		} else {
			spawnX, spawnY = a.RandomSpawn(occupied)
		}
	}

	p := &Player{
		Username:          username,
		Health:            maxHealth,
		Arena:             a,
		X:                 spawnX,
		Y:                 spawnY,
		JoinedAt:          time.Now(),
		InvulnerableUntil: time.Now().Add(spawnShieldFor(matchID)),
		LastMoveTime:      time.Now(),
	}
	applyLoadout(p, charID, weaponID, charLevel)
	p.CharacterSkin, p.WeaponSkin = charSkin, weaponSkin
	p.Team = team
	// بات هم عضوِ همان مسابقه است: بدون MatchID نه کسی او را می‌بیند و نه
	// او در فیلترِ پخش‌ها می‌گنجد
	p.MatchID = matchID
	h.players[username] = p

	if skill == "" {
		skill = BotSkillMedium
	}
	h.bots[username] = &BotRuntime{
		Username:  username,
		Skill:     skill,
		prof:      profileFor(skill),
		strafeDir: 1,
	}
	h.broadcastPlayerUpdate()
}

// RemoveBot بات را از بازی بیرون می‌برد
func (h *Hub) RemoveBot(username string) {
	if _, ok := h.bots[username]; !ok {
		return
	}
	delete(h.bots, username)
	delete(h.players, username)
	h.broadcastPlayerUpdate()
}

// humansOnline آیا اصلاً آدمی در بازی هست؟
func (h *Hub) humansOnline() int {
	n := 0
	for name := range h.players {
		if _, isBot := h.bots[name]; !isBot {
			n++
		}
	}
	return n
}

// stepBots یک تیکِ کاملِ همه‌ی بات‌ها. فقط از گوروتینِ Hub صدا زده می‌شود.
func (h *Hub) stepBots(dt float64) {
	if len(h.bots) == 0 {
		return
	}
	// وقتی در یک مسابقه هیچ آدمی نمانده، بات‌های همان مسابقه بروند — وگرنه
	// سرور بی‌خود یک زمینِ خالیِ بات‌به‌بات را برای همیشه شبیه‌سازی می‌کند.
	// عمداً per-match است: قبلاً یک شمارشِ سراسری بود، پس خالی شدنِ یک
	// مسابقه بات‌های همه‌ی مسابقه‌های دیگر را هم پاک می‌کرد.
	humansPerMatch := map[string]int{}
	for name, p := range h.players {
		if _, isBot := h.bots[name]; !isBot {
			humansPerMatch[p.MatchID]++
		}
	}
	swept := false
	emptied := map[string]bool{}
	for name := range h.bots {
		p, ok := h.players[name]
		if !ok || humansPerMatch[p.MatchID] == 0 {
			if ok && p.MatchID != "" {
				emptied[p.MatchID] = true
			}
			delete(h.bots, name)
			delete(h.players, name)
			swept = true
		}
	}
	if swept {
		// مسابقه‌ای که آدمی در آن نمانده باید از mmMatches هم برود، وگرنه
		// بات‌هایش تا ابد «مشغول» می‌مانند و استخر آب می‌رود
		for id := range emptied {
			// راندِ بی‌آدم هم همین‌جا بسته می‌شود (abandonRound) — نه آخرِ تایمر
			if !otherHumansPending(id, "") {
				h.abandonRound(id)
			}
			go ReleaseMatch(id)
		}
		h.broadcastPlayerUpdate()
	}

	for name, b := range h.bots {
		p, ok := h.players[name]
		if !ok {
			delete(h.bots, name)
			continue
		}
		h.stepBot(b, p, dt)
	}
}

func (h *Hub) stepBot(b *BotRuntime, p *Player, dt float64) {
	// --- مرگ و بازگشت ---
	if p.Health <= 0 {
		// داخلِ راند، برگرداندنِ بات کارِ خودِ راند است (match_round.go):
		// در حالتِ حذفی اصلاً برنمی‌گردد، و در حالتِ کشتار سرِ وقتِ خودش
		// و با محافظِ تولد برمی‌گردد — نه با تایمرِ جداگانه‌ی این‌جا.
		if r := h.roundOf(p.Username); r != nil && !r.Ended {
			return
		}
		b.deadFor += dt
		if b.deadFor >= 3.5 {
			b.deadFor = 0
			h.respawnBot(b, p)
		}
		return
	}

	b.clock += dt
	b.shotCD -= dt
	if b.reloadLeft > 0 {
		b.reloadLeft -= dt
	}
	b.healCD -= dt
	b.repathIn -= dt
	b.strafeIn -= dt

	// آتش‌بسِ ابتدای راند: بات سرِ جای خودش در اتاقِ تیمش می‌ماند.
	//
	// عمداً حرکت هم متوقف می‌شود و نه فقط شلیک: اگر در آتش‌بس به‌سمتِ حریف
	// راه بیفتند، لحظه‌ای که آتش‌بس تمام شود هر هشت نفر روبه‌روی هم‌اند و
	// راند در چند ثانیه تمام می‌شود. این‌طوری بعد از آتش‌بس هنوز باید کلِ
	// نقشه را طی کنند، پس درگیری‌ها پخش می‌شوند.
	if r := h.roundOf(p.Username); r != nil && r.InWarmup() {
		b.path = nil
		b.seenFor = 0
		b.memory = 0
		return
	}

	// حافظه‌ی ردِ قبلی آب می‌رود، چه هدفی ببیند چه نبیند
	if b.memory > 0 {
		b.memory -= dt
	}

	// چه کسی را همین حالا می‌بینم؟ (نه «نزدیک‌ترین حریفِ نقشه» — فقط چیزی
	// که واقعاً در دیدرس است)
	target := h.senseTarget(p)
	if target == nil {
		b.targetName = ""
		b.seenFor = 0
		// دور از چشمِ حریف، جانِ کم را ترمیم کن. عمداً فقط همین‌جا: وقتی
		// کسی را می‌بیند نباید وسطِ درگیری بایستد و خودش را درمان کند.
		st := statsOf(p)
		if p.Health < st.Health/3 && b.healCD <= 0 {
			b.healCD = st.HealCooldown
			p.Health += st.HealAmount
			if p.Health > st.Health {
				p.Health = st.Health
			}
			h.broadcastHealSuccess(p.Username, p.Health)
			return
		}
		if b.memory > 0 {
			// ردی هست ولی خودش را نمی‌بینم: برو همان‌جا را بگرد
			h.advanceAlongPath(b, p, b.lastSeenX, b.lastSeenY, dt)
			if distance(p.X, p.Y, b.lastSeenX, b.lastSeenY) < 90 {
				b.memory = 0 // رسیدم و کسی نبود؛ رد سوخت
			}
			return
		}
		// «عملیات حذف شیطان»: هدفِ راند حریف نیست، شیطانِ وسطِ زمین است.
		// پس بی‌کار گشت نزن — برو سراغِ او (demon.go).
		if h.botHuntDemon(b, p, dt) {
			return
		}
		h.patrol(b, p, dt)
		return
	}
	// هدفِ تازه یعنی واکنش از صفر — بات نباید تاخیرِ نشانه‌گیریِ هدفِ قبلی
	// را روی هدفِ جدید خرج‌شده حساب کند
	if b.targetName != target.Username {
		b.seenFor = 0
	}
	b.targetName = target.Username
	b.noteSighting(target.X, target.Y)

	dist := distance(p.X, p.Y, target.X, target.Y)
	// senseTarget خودش خطِ دید را شرط کرده، پس اینجا قطعاً می‌بیندش
	los := true
	b.seenFor += dt

	st := statsOf(p)
	engage := st.BombRange * 0.55 * b.prof.EngageMul
	if engage < 180 {
		engage = 180
	}

	// زاویه‌ای که برای شلیک لازم است. عمداً بات را با آن نمی‌چرخانیم مگر
	// وقتی ایستاده — وگرنه همان صحنه‌ی پهلو-راه-رفتنِ صورت-به-حریف برمی‌گردد.
	want := math.Atan2(target.Y-p.Y, target.X-p.X) + math.Pi/2
	want += b.prof.AimJitter * math.Sin(float64(time.Now().UnixNano())*1e-9*1.7)

	// خشابِ خالی بعد از پایانِ تعویض پر می‌شود (اولین بار هم همین‌جا)
	if b.ammo <= 0 && b.reloadLeft <= 0 {
		b.ammo = st.MagSize
		if b.ammo <= 0 {
			b.ammo = 1
		}
	}

	// آماده‌ی شلیک است؟ (حریف را دیده، تاخیرِ واکنش گذشته، خشاب پر)
	//
	// «تقریباً آماده» هم کافی است (۰.۱۵ ثانیه مانده): قبلاً بات بینِ دو
	// شلیک به سمتِ حرکتِ پهلو می‌چرخید و دوباره برمی‌گشت، و سلاحِ تندشلیک
	// عملاً با نصفِ سرعتش می‌زد. سلاحِ کند هنوز بینِ شلیک‌ها جابه‌جا می‌شود.
	aiming := los && dist <= engage &&
		b.seenFor >= b.prof.Reaction && b.reloadLeft <= 0 && b.shotCD <= 0.15

	// --- حرکت و چرخش ---
	//
	// قانون همان قانونِ بازیکنِ آدم است (player.gd): وقتی راه می‌روی رویت
	// به سمتِ حرکت است، و وقتی می‌ایستی رویت را به حریف می‌کنی. پس بات هم
	// برای شلیک می‌ایستد و می‌چرخد — نه اینکه هم‌زمان عقب‌عقب برود و
	// نشانه بگیرد.
	switch {
	case aiming:
		p.Rot = clampRotation(p.Rot, want, turnStep(p, dt)*b.prof.AimTurnMul)
		h.broadcastMove(p.Username, p.X, p.Y, p.Rot)
		b.path = nil
	case los && dist < engage:
		h.combatMove(b, p, target, dist, engage, dt)
	default:
		h.advanceAlongPath(b, p, target.X, target.Y, dt)
	}

	// --- شلیک ---
	if aiming && b.shotCD <= 0 && math.Abs(angleDiff(p.Rot, want)) <= degToRad(st.FireConeDeg) {
		// باقی‌مانده‌ی تیک (تیکِ ۱۵ هرتزی) دور ریخته نمی‌شود، وگرنه سلاحِ
		// تند به مضربِ ۶۶ میلی‌ثانیه گرد و کندتر از عددش می‌شد
		// فقط باقی‌مانده‌ی همین تیک منتقل می‌شود؛ shotCD در بیکاری بی‌انتها
		// منفی می‌شد و اولِ هر درگیری دو تیرِ پشتِ‌سرِهم می‌زد
		b.shotCD = math.Max(b.shotCD, -dt) + st.FireCooldown
		b.ammo--
		if b.ammo <= 0 {
			b.reloadLeft = st.ReloadSeconds
		}
		h.botShoot(b, p, target)
	}
}

// pickTarget نزدیک‌ترین حریفِ زنده. هم‌تیمی هدف گرفته نمی‌شود.
func (h *Hub) pickTarget(me *Player) *Player {
	var best *Player
	bestD := math.Inf(1)
	for _, other := range h.players {
		if other.Username == me.Username || other.Health <= 0 {
			continue
		}
		// فقط داخلِ همان مسابقه — بات نباید به بازیکنِ زمینِ دیگر شلیک کند
		if other.MatchID != me.MatchID {
			continue
		}
		// تیمِ خالی یعنی مسابقه‌ی بی‌تیم (تمرین) — آن‌جا همه حریف‌اند
		if me.Team != "" && other.Team == me.Team {
			continue
		}
		d := distance(me.X, me.Y, other.X, other.Y)
		if d < bestD {
			best, bestD = other, d
		}
	}
	return best
}

// combatMove در بردِ درگیری: فاصله را نگه می‌دارد و کنار می‌کشد،
// به‌جای اینکه مثل یک مجسمه بایستد.
func (h *Hub) combatMove(b *BotRuntime, p *Player, target *Player, dist, engage, dt float64) {
	if b.strafeIn <= 0 {
		b.strafeIn = b.prof.StrafeFreq
		if rand.Float64() < 0.5 {
			b.strafeDir = -b.strafeDir
		}
	}
	toX := (target.X - p.X) / math.Max(dist, 0.001)
	toY := (target.Y - p.Y) / math.Max(dist, 0.001)

	var dx, dy float64
	switch {
	case dist > engage*0.75:
		dx, dy = toX, toY // نزدیک شو
	case dist < engage*0.40:
		dx, dy = -toX, -toY // زیادی نزدیک است، عقب بکش
	}
	// کنارکشی همیشه هست — عمود بر خطِ دشمن
	dx += -toY * b.strafeDir * 0.9
	dy += toX * b.strafeDir * 0.9

	h.moveBot(b, p, dx, dy, dt)
	// مسیرِ قبلی دیگر معنی ندارد؛ با خروج از درگیری از نو حساب می‌شود
	b.path = nil
}

// advanceAlongPath دنبال کردنِ مسیرِ A*. مسیر هر چند وقت یک بار یا وقتی
// هدف جابه‌جا شده از نو حساب می‌شود.
func (h *Hub) advanceAlongPath(b *BotRuntime, p *Player, tx, ty, dt float64) {
	needPath := b.path == nil || b.pathIdx >= len(b.path) || b.repathIn <= 0 ||
		distance(b.goalX, b.goalY, tx, ty) > 120
	if needPath {
		b.repathIn = 0.6
		b.goalX, b.goalY = tx, ty
		b.path = nil
		if a := arenaOf(p); a != nil {
			b.path = a.FindPath(p.X, p.Y, tx, ty)
		}
		b.pathIdx = 0
	}
	if len(b.path) == 0 {
		// راهی نیست — دستِ‌کم به سمت هدف فشار بده تا خشک نایستد
		d := distance(p.X, p.Y, tx, ty)
		h.moveBot(b, p, (tx-p.X)/math.Max(d, 0.001), (ty-p.Y)/math.Max(d, 0.001), dt)
		return
	}

	wp := b.path[b.pathIdx]
	d := distance(p.X, p.Y, wp.X, wp.Y)
	if d < 26 {
		b.pathIdx++
		if b.pathIdx >= len(b.path) {
			b.path = nil
			return
		}
		wp = b.path[b.pathIdx]
		d = distance(p.X, p.Y, wp.X, wp.Y)
	}
	h.moveBot(b, p, (wp.X-p.X)/math.Max(d, 0.001), (wp.Y-p.Y)/math.Max(d, 0.001), dt)
}

// patrol وقتی هیچ ردی از حریف نیست: اتاق‌ها را یکی‌یکی بگرد.
//
// سرِ هر مقصد یک ایستِ کوتاه دارد و دور خودش می‌چرخد — هم شبیهِ گشتنِ یک
// آدم است و هم عملاً کار می‌کند: چون میدانِ دید محدود است، چرخیدن تنها
// راهِ پیدا کردنِ حریفی است که پشتِ سرت رد می‌شود.
func (h *Hub) patrol(b *BotRuntime, p *Player, dt float64) {
	// --- ایستِ نگاه ---
	if b.lookFor > 0 {
		b.lookFor -= dt
		p.Rot += b.lookDir * 1.5 * dt
		h.broadcastMove(p.Username, p.X, p.Y, p.Rot)
		return
	}

	if !b.hasRoam || distance(p.X, p.Y, b.roamX, b.roamY) < 70 {
		if b.hasRoam {
			// تازه رسیدیم: بایست و دور و برت را نگاه کن
			b.lookFor = 0.7 + rand.Float64()*1.3
			b.lookDir = 1
			if rand.Float64() < 0.5 {
				b.lookDir = -1
			}
		}
		if x, y, ok := patrolPoint(b, arenaOf(p), p.X, p.Y); ok {
			b.roamX, b.roamY = x, y
			b.hasRoam = true
			b.path = nil
			b.repathIn = 0
		} else if a := arenaOf(p); a != nil && len(a.Spawns) > 0 {
			// نقشه‌ی بی‌اتاق (تست) — همان رفتارِ قدیمی
			s := a.Spawns[rand.Intn(len(a.Spawns))]
			b.roamX, b.roamY = s[0], s[1]
			b.hasRoam = true
			b.path = nil
			b.repathIn = 0
		}
		if b.lookFor > 0 {
			return
		}
	}
	if b.hasRoam {
		h.advanceAlongPath(b, p, b.roamX, b.roamY, dt)
	}
}

// turnStep چقدر می‌تواند در این فریم بچرخد — دقیقاً همان عددی که بازیکنِ
// آدم با آن می‌چرخد.
//
// TurnRate از خودِ کاراکتر می‌آید (hand_speed، ۲۶۰ تا ۵۶۰ درجه بر ثانیه) و
// player.gd هم از همین استفاده می‌کند. قبلاً بات عددِ ثابتِ ۳.۸ رادیان بر
// ثانیه (≈۲۱۸ درجه) داشت — کندتر از هر بازیکنِ واقعی. نتیجه این بود که سرِ
// هر تغییرِ جهت، چند فریم پهلو راه می‌رفت تا صورتش برسد.
func turnStep(p *Player, dt float64) float64 {
	deg := statsOf(p).TurnRate
	if deg <= 0 {
		deg = 400 // همان پیش‌فرضِ player.gd
	}
	return degToRad(deg) * dt
}

// moveBot حرکتِ واقعی. از همان ResolveMove استفاده می‌کند که حرکتِ آدم‌ها
// را اعتبارسنجی می‌کند، پس بات هم دقیقاً همان قوانینِ برخورد را دارد و
// نمی‌تواند از دیوار رد شود.
//
// چرخش هم همین‌جا انجام می‌شود و دقیقاً از قانونِ بازیکنِ آدم پیروی می‌کند
// (player.gd): تا وقتی حرکت می‌کنی، رویت به همان سمتی است که می‌روی.
//
// باگی که این جلویش را می‌گیرد: قبلاً چرخش جدا و همیشه به سمتِ حریف بود،
// پس بات پهلو و عقب راه می‌رفت در حالی که صورتش جای دیگری بود — از بیرون
// مثل عروسکِ کشیده‌شده دیده می‌شد، نه مثل یک بازیکن.
func (h *Hub) moveBot(b *BotRuntime, p *Player, dx, dy, dt float64) {
	l := math.Hypot(dx, dy)
	if l < 0.001 {
		return
	}
	// جهتی که *می‌خواهد* برود. همان قراردادِ زاویه‌ی بازی: جلوی کاراکتر رو
	// به بالا است، پس +π/۲
	want := math.Atan2(dy, dx) + math.Pi/2
	step := turnStep(p, dt)
	turned := clampRotation(p.Rot, want, step)

	// اول بچرخ، بعد برو.
	//
	// این همان چیزی است که بات را شبیهِ آدم می‌کند. جهتِ کنارکشی هر یکی-دو
	// ثانیه برعکس می‌شود؛ بدونِ این دروازه، بات در همان فریم با تمام سرعت
	// به سمتِ مخالف شلیک می‌شد در حالی که صورتش هنوز جای قبلی بود — دقیقاً
	// همان «یهو عقب‌عقب رفتن». حالا هرچه بیشتر از جهتِ حرکت منحرف باشد
	// کندتر می‌رود، و در ۹۰ درجه یا بیشتر عملاً سرِ جایش می‌چرخد.
	align := math.Cos(angleDiff(turned, want))
	if align <= 0 {
		// هنوز پشتش به مقصد است: فقط بچرخ
		p.Rot = turned
		h.broadcastMove(p.Username, p.X, p.Y, p.Rot)
		return
	}
	gate := align * align // نرم‌تر از خطی؛ حرکتِ نیم‌رخ هم کند می‌شود

	speed := statsOf(p).Speed * gate
	nx := p.X + dx/l*speed*dt
	ny := p.Y + dy/l*speed*dt
	if a := arenaOf(p); a != nil {
		nx, ny = a.ResolveMove(p.X, p.Y, nx, ny, playerRadius, dt)
	}

	// نگاه در نهایت به جابه‌جاییِ *واقعی* دوخته می‌شود، نه به خواسته: کنارِ
	// دیوار ResolveMove او را می‌لغزاند و مسیرِ واقعی تا ۹۰ درجه فرق می‌کند.
	p.Rot = turned
	if math.Hypot(nx-p.X, ny-p.Y) > 0.5 {
		p.Rot = clampRotation(p.Rot, math.Atan2(ny-p.Y, nx-p.X)+math.Pi/2, step)
	}

	p.X, p.Y = nx, ny
	p.LastMoveTime = time.Now()
	// حتی وقتی دیوار جلوی حرکت را گرفته، چرخش عوض شده و باید پخش شود
	h.broadcastMove(p.Username, p.X, p.Y, p.Rot)
}

// botShoot شلیکِ بات — همان مسیرِ آدم: اول پخشِ افکتِ شلیک، بعد خسارت با
// همان تاس‌های سرور (MissChance) تا بات از یک بازیکنِ خوب قوی‌تر نشود.
func (h *Hub) botShoot(b *BotRuntime, shooter *Player, target *Player) {
	h.broadcastShoot(shooter.Username, shooter.X, shooter.Y, shooter.Rot)

	// بات هم مثل آدم: تا وقتی گنبدِ تولد دارد نمی‌تواند بزند، و به‌محضِ
	// اینکه بزند گنبدش می‌رود
	h.dropSpawnShield(shooter)
	if !h.validateHit(shooter, target.Username) {
		return
	}
	st := statsOf(shooter)
	if rand.Float64() < st.MissChance+b.prof.ExtraMiss {
		return
	}
	dmg := int(float64(st.Damage) * b.prof.DamageMul)
	if dmg < 1 {
		dmg = 1
	}
	target.Health -= dmg
	if target.Health <= 0 {
		target.Health = 0
		shooter.Kills++
		target.Deaths++
		h.broadcastHealth(target.Username, 0)
		h.broadcastDeath(target.Username, shooter.Username, "gun")
		h.creditKill(shooter.Username, target.Username)
		h.onPlayerEliminated(target.Username)
	} else {
		h.broadcastHealth(target.Username, target.Health)
	}
}

// respawnBot بات را سرِ جای تازه برمی‌گرداند، مثل بازیکنی که دوباره وارد شده
func (h *Hub) respawnBot(b *BotRuntime, p *Player) {
	if a := arenaOf(p); a != nil {
		occupied := make([][2]float64, 0, len(h.players))
		for _, o := range h.players {
			if o.MatchID == p.MatchID && o.Username != p.Username && o.Health > 0 {
				occupied = append(occupied, [2]float64{o.X, o.Y})
			}
		}
		p.X, p.Y = a.RandomSpawn(occupied)
	}
	p.Health = statsOf(p).Health
	p.InvulnerableUntil = time.Now().Add(gracePeriod)
	b.path = nil
	b.seenFor = 0
	b.memory = 0
	b.hasRoam = false
	h.broadcastHealth(p.Username, p.Health)
	h.broadcastMove(p.Username, p.X, p.Y, p.Rot)
	h.broadcastPlayerUpdate()
}

// StartBotLoop تیکِ بات‌ها را روشن می‌کند. فقط یک بار از main صدا زده شود.
func (h *Hub) StartBotLoop() {
	go func() {
		ticker := time.NewTicker(time.Second / botTickRate)
		defer ticker.Stop()
		for range ticker.C {
			select {
			case h.botTick <- struct{}{}:
			default:
				// گوروتینِ Hub مشغول است؛ این تیک را رد کن تا صف جمع نشود
			}
		}
	}()
	fmt.Printf("🤖 Bot AI loop started (%d Hz)\n", botTickRate)
}
