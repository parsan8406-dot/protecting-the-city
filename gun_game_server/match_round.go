package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"time"
)

// قانونِ راند به حالتِ بازی بستگی دارد. سه خانواده داریم:
//
//	حذفی (پیش‌فرض)      هر که کشته شد از راند بیرون می‌رود و برنمی‌گردد. به
//	                    محضِ اینکه یک تیم کاملاً از پا درآمد، تیمِ مقابل برنده
//	                    است. وقت که تمام شود و هر دو تیم کسی داشته باشند،
//	                    مساوی است.
//
//	کشتار (عملیات انتقام) دو دقیقه وقت. مرگ موقتی است: چند ثانیه بعد دوباره
//	                    زنده می‌شوی، با محافظِ چند ثانیه‌ایِ تولد. آخرِ وقت،
//	                    تیمی که بیشتر زده برنده است.
//
//	شکار (حذف شیطان)    وسطِ نقشه یک شیطان است (demon.go). تیمی که بیشتر به
//	                    او آسیب زده برنده است — چه شیطان بمیرد و چه وقت
//	                    تمام شود. ضربه‌ی آخر امتیازی ندارد. مرگ موقتی است.
//
// در هر سه، «مساوی» یعنی هر دو تیم برنده‌اند — نه اینکه هیچ‌کس نبرد.
//
// همه‌ی این حساب‌ها روی گوروتینِ Hub اتفاق می‌افتد (مثل بات‌ها)، پس نه قفلی
// لازم است و نه امکانِ مسابقه‌ی داده‌ای هست. کلاینت هیچ‌کدام از این اعداد را
// نمی‌سازد؛ فقط چیزی را نشان می‌دهد که از round_state می‌آید.

// RoundDuration مدتِ راندِ حذفی. بعد از این اگر هر دو تیم زنده باشند مساوی است.
const RoundDuration = 3 * time.Minute

// RoundWarmup چند ثانیه‌ی اولِ راند کسی شلیک نمی‌کند.
//
// بدونِ این، بات‌ها از همان لحظه‌ی شروع به هم می‌ریختند و راند در چند ثانیه
// تمام می‌شد — بازیکن هنوز صفحه‌ی بارگذاری را رد نکرده بود که «باختی» را
// می‌دید. کلاینت هم یک ثانیه تایمر دارد و ۳ ثانیه حصانتِ ورود، پس این عدد
// باید دستِ‌کم به‌اندازه‌ی آن‌ها باشد.
const RoundWarmup = 6 * time.Second

// --- عملیات انتقام ---

// RevengeDuration دو دقیقه — خواسته‌ی خودِ حالت
const RevengeDuration = 2 * time.Minute

// RevengeRespawnDelay چند ثانیه روی زمین می‌مانی تا دوباره زنده شوی.
// کوتاه است چون کلِ راند دو دقیقه بیشتر نیست.
const RevengeRespawnDelay = 3 * time.Second

// SpawnShieldDuration محافظِ بلوریِ بعد از هر تولد.
//
// تا این چند ثانیه هیچ تیری و هیچ ترکشی رد نمی‌شود (validateHit و
// applyBombDamageInternal هر دو InvulnerableUntil را چک می‌کنند). کلاینت
// همین عدد را می‌گیرد و دقیقاً همین‌قدر گنبد را نشان می‌دهد — نه بیشتر، تا
// چیزی که بازیکن می‌بیند با چیزی که سرور اعمال می‌کند یکی باشد.
const SpawnShieldDuration = 5 * time.Second

// RevengeWarmup آتش‌بسِ ابتدای راندِ انتقام. کوتاه‌تر از حالتِ حذفی است:
// راند خودش دو دقیقه است و محافظِ تولد هم پنج ثانیه پوشش می‌دهد.
const RevengeWarmup = 3 * time.Second

// --- عملیات حذف شیطان ---

// DemonHuntDuration وقتِ راندِ شکارِ شیطان.
//
// از حالتِ حذفی بلندتر است چون هدفِ اصلی یک کیسه‌ی جانِ بزرگ است و نه
// حریف: با سه دقیقه، راند تقریباً همیشه با تایمر تمام می‌شود و «کشتنِ
// شیطان» عملاً دست‌نیافتنی می‌ماند.
const DemonHuntDuration = 4 * time.Minute

// DemonHuntWarmup آتش‌بسِ ابتدای راند. شاملِ شیطان هم هست: نه به او
// می‌شود شلیک کرد و نه او نفرین می‌فرستد.
const DemonHuntWarmup = 5 * time.Second

// DemonRespawnDelay چند ثانیه بعد از مرگ دوباره وارد زمین می‌شوی.
//
// این حالت ریسپاون دارد چون هدفش شیطان است نه حریف: اگر مرگ حذفِ دائمی
// بود، تیمی که یک نفر از دست می‌داد دیگر نمی‌توانست به شیطان آسیب بزند
// و راند عملاً همان‌جا تمام می‌شد.
const DemonRespawnDelay = 5 * time.Second

// RoundRules قانونِ یک حالتِ بازی
type RoundRules struct {
	Duration time.Duration
	Warmup   time.Duration
	// Respawn یعنی مرگ موقتی است و راند با حذفِ یک تیم تمام نمی‌شود
	Respawn      bool
	RespawnDelay time.Duration
	// ScoreByKills یعنی برنده را تعدادِ کشته تعیین می‌کند، نه زنده ماندن
	ScoreByKills bool
	// Demon یعنی وسطِ نقشه شیطانی هست که برنده را او تعیین می‌کند (demon.go)
	Demon bool
	// SpawnShield مدتِ حصانتِ بعد از هر تولد (اولِ راند و هر ریسپاون)
	SpawnShield time.Duration
}

// rulesForMode قانونِ هر حالت. حالتِ ناشناخته حذفی حساب می‌شود.
func rulesForMode(modeID string) RoundRules {
	switch modeID {
	case "revenge":
		return RoundRules{
			Duration:     RevengeDuration,
			Warmup:       RevengeWarmup,
			Respawn:      true,
			RespawnDelay: RevengeRespawnDelay,
			ScoreByKills: true,
			SpawnShield:  SpawnShieldDuration,
		}
	case "banish":
		return RoundRules{
			Duration:     DemonHuntDuration,
			Warmup:       DemonHuntWarmup,
			Respawn:      true,
			RespawnDelay: DemonRespawnDelay,
			Demon:        true,
			SpawnShield:  SpawnShieldDuration,
		}
	}
	return RoundRules{
		Duration:    RoundDuration,
		Warmup:      RoundWarmup,
		SpawnShield: gracePeriod,
	}
}

// spawnShieldFor مدتِ محافظِ تولد در یک مسابقه — لحظه‌ی ورودِ بازیکن و بات
// لازم است، یعنی قبل از اینکه راند حتماً ساخته شده باشد.
func spawnShieldFor(matchID string) time.Duration {
	return rulesForMode(ModeOfMatch(matchID)).SpawnShield
}

// RoundState وضعیتِ یک راندِ در جریان
type RoundState struct {
	MatchID string
	ModeID  string
	Rules   RoundRules
	// اعضای هر تیم: username -> team
	Team map[string]string
	// چه کسانی همین حالا زنده‌اند
	Alive map[string]bool
	// آدم‌ها (نه بات‌ها) — پاداش فقط برای این‌ها ثبت می‌شود
	Humans map[string]bool
	// Kills کشته‌های هر بازیکن در همین راند (فقط سرور می‌نویسدش)
	Kills map[string]int
	// RespawnAt چه کسی چه لحظه‌ای دوباره زنده می‌شود (فقط حالت‌های ریسپاون‌دار)
	RespawnAt map[string]time.Time
	// GrenadeKills / HealsGiven آمارِ ماموریت‌ها در همین راند
	// (match_objectives.go). ممکن است nil باشند؛ فقط از راهِ متدها نوشته شوند.
	GrenadeKills map[string]int
	HealsGiven   map[string]int
	// Damagers چه کسی آخرین بار کِی به هر قربانی آسیب زده (victim -> attacker
	// -> زمان) و Assists کمک‌های هر بازیکن. بدونِ این، ماموریتِ «۵ بار کمک»
	// هیچ‌وقت پر نمی‌شد و صندوقِ ۶/۶ آن روز قفل می‌ماند.
	Damagers map[string]map[string]time.Time
	Assists  map[string]int
	// Objectives هدف‌های زنده‌ی هر آدم — ماموریت‌های باز که سمتِ چپِ صفحه
	// نشان داده می‌شوند
	Objectives map[string][]*LiveObjective
	// Demon شیطانِ وسطِ زمین — فقط در حالتِ شکار (demon.go). nil یعنی این
	// راند شیطان ندارد.
	Demon     *DemonState
	StartedAt time.Time
	Deadline  time.Time
	Ended     bool
	// WinnerTeam / Draw نتیجه‌ای که endRound اعلام کرد — همان چیزی که با
	// match_over رفته. نگه داشته می‌شود تا قانونِ برد قابلِ آزمون باشد.
	WinnerTeam string
	Draw       bool
}

// InWarmup آیا هنوز در چند ثانیه‌ی ابتداییِ آتش‌بس هستیم؟
func (r *RoundState) InWarmup() bool {
	return time.Since(r.StartedAt) < r.Rules.Warmup
}

// TeamScore کشته‌های هر تیم — همان چیزی که برنده را تعیین می‌کند
func (r *RoundState) TeamScore() map[string]int {
	score := map[string]int{}
	for name, team := range r.Team {
		score[team] += r.Kills[name]
	}
	return score
}

// WonRound آیا این بازیکن بردِ این راند را گرفته؟
//
// 🌟 تنها جایی که این سؤال جواب داده می‌شود — پاداشِ سرور (endRound)،
// ماموریت‌ها (finishObjectives) و آمارِ پروفایل همه از همین می‌خوانند، پس
// نمی‌شود یکی‌شان قانونِ دیگری داشته باشد.
//
// مساوی دیگر برد نیست: وقتی مساوی برد حساب می‌شد، بازیکنِ آخرِ تیمِ بازنده
// فقط قایم می‌شد تا وقت تمام شود و هر دو تیم پاداشِ کاملِ برد می‌گرفتند (دو
// دوست در ۱ در ۱ هم می‌توانستند با ۰-۰ کاپ جمع کنند). مساوی پاداشِ خودش را
// دارد (ApplyMatchOutcome → OutcomeDraw).
func (r *RoundState) WonRound(username, winnerTeam string, draw bool) bool {
	if draw {
		return false
	}
	return winnerTeam != "" && r.Team[username] == winnerTeam
}

// survivorLeader وقتی وقتِ راندِ حذفی تمام می‌شود: تیمی که زنده‌ی بیشتری
// دارد می‌برد؛ برابر بود، تیمی که مجموعِ درصدِ جانِ زنده‌هایش بیشتر است.
// false یعنی واقعاً مساوی.
func (h *Hub) survivorLeader(r *RoundState) (string, bool) {
	alive := map[string]int{}
	hp := map[string]float64{}
	for name, team := range r.Team {
		if !r.Alive[name] {
			continue
		}
		alive[team]++
		if p, ok := h.players[name]; ok && p.Health > 0 {
			max := float64(statsOf(p).Health)
			if max <= 0 {
				max = 1
			}
			hp[team] += float64(p.Health) / max
		}
	}
	best, tie := "", false
	for team := range alive {
		switch {
		case best == "":
			best = team
		case alive[team] > alive[best],
			alive[team] == alive[best] && hp[team] > hp[best]+1e-9:
			best, tie = team, false
		case alive[team] == alive[best] && math.Abs(hp[team]-hp[best]) <= 1e-9:
			tie = true
		}
	}
	if best == "" || tie {
		return "", false
	}
	return best, true
}

// leadingTeam تیمِ جلو و اینکه آیا اصلاً کسی جلو هست.
// دومین مقدار false یعنی مساوی.
func (r *RoundState) leadingTeam() (string, bool) {
	best, bestScore, tie := "", -1, false
	for team, n := range r.TeamScore() {
		switch {
		case n > bestScore:
			best, bestScore, tie = team, n, false
		case n == bestScore:
			tie = true
		}
	}
	if best == "" || tie {
		return "", false
	}
	return best, true
}

// clearRoundState بات‌ها، ردِ راند و قفل‌های توانایی‌های این راند را پاک
// می‌کند — فقط آن‌هایی که هنوز واقعاً مالِ همین مسابقه‌اند.
//
// قبلاً همه‌چیز با اسم پاک می‌شد: باتی که بعد از ترکِ این مسابقه در مسابقه‌ی
// تازه‌ای نشسته بود وسطِ آن بازی ناپدید می‌شد، و ردِ راندِ تازه‌ی خودِ
// بازیکن هم پاک می‌شد (دیگر ریسپاون نمی‌شد).
func (h *Hub) clearRoundState(r *RoundState) {
	for name := range r.Team {
		if _, isBot := h.bots[name]; isBot {
			if p, ok := h.players[name]; !ok || p.MatchID == r.MatchID {
				delete(h.bots, name)
				delete(h.players, name)
			}
		}
		if h.playerRound[name] == r.MatchID {
			delete(h.playerRound, name)
		}
		// موجودیِ بمب مالِ همین مسابقه بود
		delete(h.bombsUsed, r.MatchID+":"+name)
	}
	// قفلِ توانایی‌ها به مسابقه‌ی بعد نمی‌رود: دکمه‌ها در مسابقه‌ی تازه آماده
	// نشان داده می‌شوند و سرور هم باید همین را قبول کند
	for name := range r.Humans {
		if h.playerRound[name] != "" && h.playerRound[name] != r.MatchID {
			continue // همین حالا در مسابقه‌ی دیگری است؛ قفل‌های آن‌جا مالِ خودش‌اند
		}
		delete(h.bombCooldowns, name)
		for _, kind := range []string{"sprint", "guard", "laser", "team_heal"} {
			delete(h.abilityCooldowns, abilityKey(name, kind))
		}
	}
	delete(h.rounds, r.MatchID)
}

// abandonRound مسابقه‌ای که آخرین آدمش رفته همین حالا بسته می‌شود: کسی که
// رفته باخت می‌گیرد (همان که آخرِ وقت می‌گرفت، ولی حالا بلافاصله) و راند
// دیگر تا ته تایمر زنده نمی‌ماند تا بعداً بات‌ها و ردِ مسابقه‌ی بعدیِ همان
// بازیکن را پاک کند.
func (h *Hub) abandonRound(matchID string) {
	r := h.rounds[matchID]
	if r == nil || r.Ended {
		return
	}
	r.Ended = true
	fmt.Printf("🏳️ Round %s abandoned — no humans left\n", r.MatchID)
	for name := range r.Humans {
		h.grantResultAsync(name, r.ModeID, OutcomeLoss, r.Kills[name])
	}
	h.clearRoundState(r)
	ReleaseMatch(r.MatchID)
}

// grantResultAsync پاداشِ یک نفر را در دیتابیس ثبت و به خودش خبر می‌دهد.
func (h *Hub) grantResultAsync(username, modeID string, outcome MatchOutcome, kills int) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		res, err := ApplyMatchOutcome(ctx, username, modeID, outcome, kills)
		if err != nil {
			fmt.Printf("⚠️ match result for %s: %v\n", username, err)
			return
		}
		// نتیجه‌ی نهایی را به خودش خبر بده تا صفحه‌ی پایان عددها را
		// از سرور بگیرد، نه از حدسِ کلاینت
		payload := map[string]interface{}{"type": "match_reward"}
		for k, v := range res {
			payload[k] = v
		}
		data, _ := json.Marshal(payload)
		queueNotify(userMessage{username: username, data: data})
	}()
}

// startRound راند را برای یک مسابقه می‌سازد (اگر از قبل نباشد).
// از caseِ "join" صدا زده می‌شود، یعنی وقتی اولین آدم واقعاً وارد زمین شد.
func (h *Hub) startRound(username string) *RoundState {
	m := MatchOf(username)
	if m == nil {
		return nil // مسابقه‌ی بی‌تیم (تمرین) — راندی در کار نیست
	}
	if r, ok := h.rounds[m.MatchID]; ok {
		h.playerRound[username] = m.MatchID
		// بازیکنی که بعد از ساخته شدنِ راند به مسابقه اضافه شده (بک‌فیل،
		// یا ورودِ دیرهنگام) باید همین‌جا ثبت شود. بدونِ این، اسمش در
		// playerRound بود ولی در Alive نبود — و onPlayerEliminated روی
		// همان Alive تصمیم می‌گیرد، پس مرگش اصلاً ثبت نمی‌شد و هیچ‌وقت
		// ریسپاون نمی‌شد.
		for _, qp := range m.Players {
			if qp.Username == username {
				h.joinRound(r, username, fmt.Sprintf("%d", qp.Team), !qp.isBot)
			}
		}
		// بازیکنی که دیر رسیده هم باید همان لحظه بداند شیطان کجاست و چقدر
		// جان دارد — وگرنه تا اولین تیر هیچ نشانی رویش نمی‌بیند
		if r.Demon != nil {
			h.broadcastDemonState(r)
		}
		return r
	}

	rules := rulesForMode(m.ModeID)
	r := &RoundState{
		MatchID:   m.MatchID,
		ModeID:    m.ModeID,
		Rules:     rules,
		Team:      map[string]string{},
		Alive:     map[string]bool{},
		Humans:    map[string]bool{},
		Kills:     map[string]int{},
		RespawnAt: map[string]time.Time{},
		StartedAt: time.Now(),
		Deadline:  time.Now().Add(rules.Duration + rules.Warmup),
	}
	if rules.Demon {
		r.Demon = newDemon(ArenaForMode(m.ModeID))
	}
	botNames := map[string]bool{}
	for _, b := range botsInMatchOf(username) {
		botNames[b.Username] = true
	}
	for _, p := range m.Players {
		team := fmt.Sprintf("%d", p.Team)
		r.Team[p.Username] = team
		r.Alive[p.Username] = true
		if !botNames[p.Username] {
			r.Humans[p.Username] = true
		}
		h.playerRound[p.Username] = m.MatchID
	}
	h.rounds[m.MatchID] = r
	fmt.Printf("🏁 Round %s started (%s), %d players, %v, respawn=%v, demon=%v\n",
		r.MatchID, r.ModeID, len(r.Team), rules.Duration, rules.Respawn, rules.Demon)
	h.broadcastRoundState(r)
	if r.Demon != nil {
		fmt.Printf("👹 Demon at (%.0f, %.0f) with %d HP\n", r.Demon.X, r.Demon.Y, r.Demon.Health)
		h.broadcastDemonState(r)
	}
	return r
}

// joinRound بازیکن را داخلِ راند ثبت می‌کند (اگر از قبل نباشد).
//
// عمداً idempotent است: امتیاز و وضعیتِ زنده‌ی کسی که از قبل در راند بوده
// را دست نمی‌زند، وگرنه یک joinِ دوباره (رفرشِ صحنه) کشته‌هایش را صفر
// می‌کرد یا مرده را زنده نشان می‌داد.
func (h *Hub) joinRound(r *RoundState, username, team string, human bool) {
	if r == nil || username == "" {
		return
	}
	if _, known := r.Team[username]; known {
		return
	}
	r.Team[username] = team
	r.Alive[username] = true
	if human {
		r.Humans[username] = true
	}
	h.playerRound[username] = r.MatchID
}

// roundOf راندی که این بازیکن در آن است
func (h *Hub) roundOf(username string) *RoundState {
	id, ok := h.playerRound[username]
	if !ok {
		return nil
	}
	return h.rounds[id]
}

// creditKill کشته را به حسابِ زننده می‌گذارد.
//
// امتیازِ راند فقط از همین‌جا بالا می‌رود و کلاینت هیچ‌وقت عددی نمی‌فرستد:
// هر سه مسیرِ مرگ (تیرِ آدم، تیرِ بات، ترکشِ بمب) از این تابع رد می‌شوند.
// خودکشی و آتشِ خودی امتیاز ندارد. خروجیِ true یعنی کشته واقعاً ثبت شد
// (مثلاً برای شمردنِ «کشته با نارنجک» در ماموریت‌ها).
func (h *Hub) creditKill(killer, victim string) bool {
	if killer == "" || killer == victim {
		return false
	}
	r := h.roundOf(victim)
	if r == nil || r.Ended {
		return false
	}
	if _, inRound := r.Team[killer]; !inRound {
		return false
	}
	if r.Team[killer] == r.Team[victim] {
		return false
	}
	r.Kills[killer]++
	// هدف‌های «کیل بگیر» همین لحظه جلو می‌روند، نه آخرِ مسابقه
	h.pushObjectiveProgress(r, killer)
	h.creditAssists(r, killer, victim)
	return true
}

// onPlayerEliminated بعد از هر مرگ صدا زده می‌شود.
//
// در حالتِ ریسپاون‌دار فقط زمانِ برگشت را ثبت می‌کند؛ در حالتِ حذفی این تنها
// جایی است که برنده تعیین می‌شود.
func (h *Hub) onPlayerEliminated(username string) {
	r := h.roundOf(username)
	if r == nil || r.Ended {
		return
	}
	// اگر به هر دلیلی در راند ثبت نشده بود، همین‌جا ثبتش کن — وگرنه
	// مرگش نادیده گرفته می‌شد و دیگر هیچ‌وقت برنمی‌گشت
	if _, known := r.Team[username]; !known {
		if p, ok := h.players[username]; ok {
			_, isBot := h.bots[username]
			h.joinRound(r, username, p.Team, !isBot)
		}
	}
	if !r.Alive[username] {
		return // قبلاً افتاده
	}
	r.Alive[username] = false

	// --- حالتِ کشتار: مرگ موقتی است ---
	if r.Rules.Respawn {
		r.RespawnAt[username] = time.Now().Add(r.Rules.RespawnDelay)
		h.broadcastRoundState(r)
		return
	}

	// --- حالتِ حذفی: تیمی که کسی برایش نمانده باخته ---
	living := map[string]int{}
	for name, team := range r.Team {
		if r.Alive[name] {
			living[team]++
		}
	}
	h.broadcastRoundState(r)

	var survivors []string
	for team, n := range living {
		if n > 0 {
			survivors = append(survivors, team)
		}
	}
	switch len(survivors) {
	case 0:
		// آخرین نفرهای دو تیم هم‌زمان افتادند
		h.endRound(r, "", true)
	case 1:
		h.endRound(r, survivors[0], false)
	}
}

// tickRounds تایمرِ راندها و صفِ ریسپاون. از همان تیکِ بات‌ها استفاده می‌کند.
func (h *Hub) tickRounds() {
	now := time.Now()
	for _, r := range h.rounds {
		if r.Ended {
			continue
		}
		if now.After(r.Deadline) {
			h.finishOnTime(r)
			continue
		}
		// شیطان: چرخه‌ی نفرین (علامت زدنِ ناحیه و بعد ترکاندنش)
		if r.Demon != nil {
			h.tickDemon(r, now)
			if r.Ended {
				continue // شیطان همین‌جا افتاد و راند بسته شد
			}
		}
		// هر که وقتِ برگشتش رسیده، برمی‌گردد
		for name, at := range r.RespawnAt {
			if now.After(at) {
				h.respawnInRound(r, name)
			}
		}
	}
}

// finishOnTime پایانِ راند با تمام شدنِ وقت.
//
// حذفی: تیمی که زنده‌ی بیشتری دارد (برابر بود، جانِ بیشتری) برنده است.
// کشتار: تیمی که بیشتر زده برنده است؛ برابر یعنی مساوی.
// شکار: تیمی که بیشتر به شیطان آسیب زده؛ برابر یعنی مساوی.
func (h *Hub) finishOnTime(r *RoundState) {
	if r.Demon != nil {
		h.finishByDamage(r)
		return
	}
	if !r.Rules.ScoreByKills {
		if winner, ok := h.survivorLeader(r); ok {
			h.endRound(r, winner, false)
			return
		}
		h.endRound(r, "", true)
		return
	}
	if winner, ok := r.leadingTeam(); ok {
		h.endRound(r, winner, false)
		return
	}
	h.endRound(r, "", true)
}

// respawnInRound بازیکن (یا بات) را دوباره وارد زمین می‌کند.
//
// نقطه‌ی تولد دورترین نقطه‌ی شروع از حریف‌های زنده است تا کسی پشتِ محلِ
// تولد کمین نکند، و پنج ثانیه محافظِ تولد رویش می‌نشیند.
func (h *Hub) respawnInRound(r *RoundState, username string) {
	delete(r.RespawnAt, username)

	p, exists := h.players[username]
	if !exists {
		return // وسطِ راند قطع کرده — دیگر برنمی‌گردد
	}

	if a := arenaOf(p); a != nil {
		// فقط حریف‌های زنده مهم‌اند: تولد کنارِ هم‌تیمی اشکالی ندارد،
		// تولد جلوی حریف یعنی مرگِ بی‌دلیل
		foes := make([][2]float64, 0, len(h.players))
		for _, o := range h.players {
			if o.MatchID != p.MatchID || o.Username == username || o.Health <= 0 {
				continue
			}
			if p.Team != "" && o.Team == p.Team {
				continue
			}
			foes = append(foes, [2]float64{o.X, o.Y})
		}
		p.X, p.Y = a.RespawnSpawn(foes)
	}

	p.Health = statsOf(p).Health
	p.InvulnerableUntil = time.Now().Add(r.Rules.SpawnShield)
	p.LastMoveTime = time.Now()
	r.Alive[username] = true
	h.freshKit(p)

	// مغزِ بات باید ریست شود، وگرنه با ردِ قدیمی و مسیرِ نامعتبر برمی‌گردد
	if b, isBot := h.bots[username]; isBot {
		b.path = nil
		b.pathIdx = 0
		b.deadFor = 0
		b.seenFor = 0
		b.memory = 0
		b.hasRoam = false
	}

	// respawn خودش جا و جان را دارد؛ move جداگانه فقط یک پیامِ اضافه بود
	h.broadcastRespawn(p, r.Rules.SpawnShield)
	h.broadcastHealth(username, p.Health)
	h.broadcastRoundState(r)
	h.broadcastPlayerUpdate()
}

// endRound راند را می‌بندد، نتیجه را پخش می‌کند و پاداش را ثبت می‌کند.
func (h *Hub) endRound(r *RoundState, winnerTeam string, draw bool) {
	if r.Ended {
		return
	}
	r.Ended = true
	r.WinnerTeam, r.Draw = winnerTeam, draw

	if draw {
		fmt.Printf("🏁 Round %s ended in a draw %v\n", r.MatchID, r.TeamScore())
	} else {
		fmt.Printf("🏁 Round %s won by team %s %v\n", r.MatchID, winnerTeam, r.TeamScore())
	}

	// نتیجه‌ی هر آدم را در دیتابیس ثبت کن.
	//
	// برد، باخت یا مساوی — هر سه ثبت می‌شوند و هر کدام پاداشِ خودش را دارد
	// (مساوی: بدونِ کاپ، نصفِ سکه‌ی برد؛ باخت: کمی سکه و تجربه). کشته‌ها هم
	// سکه‌ی کوچکی دارند تا جنگیدن همیشه بیرزد.
	for name := range r.Humans {
		outcome := OutcomeLoss
		switch {
		case draw:
			outcome = OutcomeDraw
		case r.WonRound(name, winnerTeam, draw):
			outcome = OutcomeWin
		}
		h.grantResultAsync(name, r.ModeID, outcome, r.Kills[name])
	}

	h.broadcastMatchOver(r, winnerTeam, draw)

	// ماموریت‌ها: هدف‌های آخرِ مسابقه (برد، بازی، بدون مرگ) تیک می‌خورند و
	// پیشرفتِ کلِ این راند در دیتابیس ثبت می‌شود — حتی در مساوی
	h.finishObjectives(r, winnerTeam, draw)

	h.clearRoundState(r)
	// و مهم‌تر: مسابقه را از mmMatches آزاد کن تا بات‌هایش دوباره قابل
	// استفاده باشند. بدونِ این استخرِ بات با هر مسابقه آب می‌رفت.
	ReleaseMatch(r.MatchID)
	delete(h.rounds, r.MatchID)
	h.broadcastPlayerUpdate()
}

// broadcastRoundState وضعیتِ راند برای نوارِ بالای صفحه.
//
// هم زنده‌های هر تیم می‌رود هم امتیازِ هر تیم، به‌علاوه‌ی خودِ قانون (mode و
// respawn) تا کلاینت بداند کدام عدد را نشان بدهد — نه اینکه خودش حدس بزند.
func (h *Hub) broadcastRoundState(r *RoundState) {
	alive := map[string]int{}
	for name, team := range r.Team {
		if r.Alive[name] {
			alive[team]++
		}
	}
	remain := int(time.Until(r.Deadline).Seconds())
	if remain < 0 {
		remain = 0
	}
	data, _ := json.Marshal(map[string]interface{}{
		"type":         "round_state",
		"match_id":     r.MatchID,
		"mode":         r.ModeID,
		"respawn":      r.Rules.Respawn,
		"score_kills":  r.Rules.ScoreByKills,
		"demon":        r.Rules.Demon,
		"alive":        alive,
		"score":        r.TeamScore(),
		"seconds_left": remain,
	})
	h.queueBroadcastTo(r.MatchID, data)
}

func (h *Hub) broadcastMatchOver(r *RoundState, winnerTeam string, draw bool) {
	payload := map[string]interface{}{
		"type":        "match_over",
		"match_id":    r.MatchID,
		"winner_team": winnerTeam,
		"draw":        draw,
		"score":       r.TeamScore(),
	}
	// در حالتِ شکار، عددی که روی صفحه‌ی پایان معنی دارد آسیبِ زده‌شده به
	// شیطان است، نه تعدادِ کشته
	if r.Demon != nil {
		payload["demon_damage"] = r.Demon.Damage
		payload["demon_slain"] = !r.Demon.Alive()
	}
	data, _ := json.Marshal(payload)
	h.queueBroadcastTo(r.MatchID, data)
}

// broadcastRespawn تولدِ دوباره: کلاینت بازیکن را همان‌جا برمی‌گرداند و
// دقیقاً به‌اندازه‌ی shield_seconds گنبدِ محافظ را نشان می‌دهد.
func (h *Hub) broadcastRespawn(p *Player, shield time.Duration) {
	data, _ := json.Marshal(map[string]interface{}{
		"type":           "respawn",
		"username":       p.Username,
		"x":              p.X,
		"y":              p.Y,
		"health":         p.Health,
		"shield_seconds": shield.Seconds(),
	})
	h.queueBroadcastTo(p.MatchID, data)
}
