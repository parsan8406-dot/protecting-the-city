package main

import (
	"context"
	"fmt"
	"time"
)

// پر کردنِ مسابقه با بات وقتی آدمِ هم‌سطحِ کافی نیست.
//
// قانون: تا BackfillAfter ثانیه فقط دنبالِ آدمِ هم‌سطح (TrophyWindow) می‌گردیم.
// بعد از آن، برای همان بازیکنی که این‌قدر منتظر مانده، هر آدمِ هم‌سطحی که
// در صف هست کنارش می‌نشیند و بقیه‌ی صندلی‌ها با بات‌هایی پر می‌شوند که کاپشان
// به کاپِ او نزدیک‌تر است — بات هم باید هم‌سطح به‌نظر برسد.
//
// بات‌ها با همان ساختارِ QueuedPlayer وارد می‌شوند، پس صفحه‌ی لابی و
// خودِ مسابقه هیچ فرقی بینشان و آدم‌ها نمی‌بینند.

// BackfillAfter چقدر صبر کنیم تا آدم بیاید، قبل از آوردنِ بات.
// ۱۵ ثانیه‌ی اول جستجوی آدم است (HumanSearchFor) و ۵ ثانیه‌ی بعد کلاینت
// می‌گوید بات‌ها در راه‌اند.
const BackfillAfter = 20 * time.Second

// backfillCandidates اسمِ بات‌هایی که همین حالا در صف یا مسابقه‌اند.
// باید با mmMu گرفته‌شده صدا زده شود.
func busyNamesLocked() map[string]bool {
	busy := map[string]bool{}
	for _, q := range mmQueues {
		for _, p := range q {
			busy[p.Username] = true
		}
	}
	// فقط کلیدها. هر شرکت‌کننده موقعِ ساخته شدنِ مسابقه کلیدِ خودش را
	// می‌گیرد (formMatchLocked)، پس کلیدها دقیقاً همان مجموعه‌ی
	// شرکت‌کننده‌هاست.
	//
	// عمداً m.Players باز نمی‌شود: با باز کردنش، کسی که ReleasePlayer
	// شده بود از طریقِ لیستِ هم‌تیمی‌هایش دوباره «مشغول» حساب می‌شد و
	// هیچ‌وقت آزاد نمی‌شد.
	for name := range mmMatches {
		busy[name] = true
	}
	return busy
}

// queuedLocked ورودیِ یک بازیکن در صفِ یک حالت، یا nil
func queuedLocked(modeID, username string) *QueuedPlayer {
	for _, p := range mmQueues[modeID] {
		if p.Username == username {
			return p
		}
	}
	return nil
}

// maybeBackfill اگر بازیکن BackfillAfter منتظر مانده باشد، مسابقه‌اش را با
// آدم‌های هم‌سطحِ صف و نزدیک‌ترین بات‌ها می‌سازد.
//
// خواندنِ بات‌ها از مونگو عمداً بیرونِ قفل انجام می‌شود: یک رفت‌وبرگشتِ
// دیتابیس زیرِ mmMu یعنی قفل شدنِ کلِ صف برای همه‌ی بازیکن‌ها. برای همین
// بعد از برگشتن همه‌چیز دوباره زیرِ قفل چک می‌شود.
func maybeBackfill(ctx context.Context, username, modeID string, teamSize int) *PendingMatch {
	need := teamSize * 2

	// قبل از هر چیز مسابقه‌های مانده را آزاد کن — وگرنه شاید همین حالا
	// بات‌های کافی داریم ولی همه‌شان به‌اسمِ نشستی که تمام شده رزرو مانده‌اند
	mmMu.Lock()
	sweepStaleMatchesLocked()
	anchor := queuedLocked(modeID, username)
	if anchor == nil || time.Since(anchor.joinedAt) < BackfillAfter {
		mmMu.Unlock()
		return nil
	}
	target := anchor.Trophies
	waited := time.Since(anchor.joinedAt)
	busy := busyNamesLocked()
	mmMu.Unlock()

	// باتی که کاپش به حدِ نصابِ این حالت نمی‌رسد نباید در آن ظاهر شود —
	// وگرنه در «عملیات انتقام» (۱۵۰ کاپ) حریفی با ۲۰ کاپ سبز می‌شود که
	// خودش لو می‌دهد بات است.
	minTrophies := 0
	if mode, err := gameModeByID(ctx, modeID); err == nil {
		minTrophies = mode.MinTrophies
	}
	// need-1: بدترین حالت اینکه هیچ آدمِ هم‌سطحی نیست
	bots, err := loadBotsNear(ctx, busy, need-1, minTrophies, target)
	if err != nil {
		return nil
	}
	// سه مسابقه‌ی اولِ یک بازیکن: حریف‌های بات همه آسان، هم‌تیمی‌ها متوسط —
	// تا اولین تجربه‌اش برد باشد، نه شکستِ پشتِ‌سرِهم.
	newbie := false
	if p, err := getPlayerByUsername(ctx, username); err == nil {
		newbie = p.Stats.TotalMatches < newbieMatches
	}

	mmMu.Lock()
	defer mmMu.Unlock()

	// بین باز و بسته شدنِ قفل شاید مسابقه‌اش جور شده یا صف را ترک کرده
	if m := mmMatches[username]; m != nil {
		return m
	}
	anchor = queuedLocked(modeID, username)
	if anchor == nil {
		return nil
	}

	group := []*QueuedPlayer{anchor}
	for _, p := range peersOfLocked(mmQueues[modeID], anchor) {
		if len(group) == need {
			break
		}
		group = append(group, p)
	}

	// بات‌هایی که همین بین مسابقه‌ی دیگری برداشته، کنار می‌روند
	busy = busyNamesLocked()
	for _, b := range bots {
		if len(group) == need {
			break
		}
		if busy[b.Username] {
			continue
		}
		rankID, rankName := rankFromTrophies(b.Trophies)
		group = append(group, &QueuedPlayer{
			Username:  b.Username,
			PlayerID:  b.PlayerID,
			AvatarID:  b.AvatarID,
			Character: b.EquippedCharacter,
			Trophies:  b.Trophies,
			Level:     b.Level,
			RankID:    rankID,
			RankName:  rankName,
			Team:      -1,
			joinedAt:  time.Now(),
			isBot:     true,
			skill:     b.BotSkill,
		})
	}
	if len(group) < need {
		return nil // بات کم است — پرسشِ بعدی دوباره امتحان می‌کند
	}

	match := formMatchLocked(modeID, group)
	if newbie {
		gentleForNewbie(match, username)
	}
	fmt.Printf("🤖 Backfilled %s for %s (%d trophies) after %.0fs, theme=%s\n",
		modeID, username, target, waited.Seconds(), match.Theme)
	return match
}

// newbieMatches چند مسابقه‌ی اولِ هر بازیکن با بات‌های مهربان پر می‌شود
const newbieMatches = 3

// gentleForNewbie مهارتِ بات‌های یک مسابقه‌ی تازه‌جورشده را برای بازیکنِ
// تازه‌کار تنظیم می‌کند: حریف‌ها آسان، هم‌تیمی‌ها متوسط. زیرِ mmMu صدا
// زده می‌شود (همان‌جا که مسابقه ساخته شد).
func gentleForNewbie(m *PendingMatch, anchor string) {
	if m == nil {
		return
	}
	myTeam := -1
	for _, p := range m.Players {
		if p.Username == anchor {
			myTeam = p.Team
		}
	}
	for i := range m.Players {
		if !m.Players[i].isBot {
			continue
		}
		if m.Players[i].Team == myTeam {
			m.Players[i].skill = BotSkillMedium
		} else {
			m.Players[i].skill = BotSkillEasy
		}
	}
}

// BotSeat یک صندلیِ باتِ یک مسابقه
type BotSeat struct {
	Username string
	Skill    string
	Team     string
}

// botsInMatch بات‌های یک مسابقه، با تیم و مهارتشان.
// hub از این استفاده می‌کند تا وقتی آدم وارد آرنا شد بات‌ها را بسازد.
//
// قفل را خودش می‌گیرد و کپی برمی‌گرداند: صداکننده روی گوروتینِ Hub است و
// نباید به ساختارِ زنده‌ی صف اشاره نگه دارد.
func botsInMatchOf(username string) []BotSeat {
	mmMu.Lock()
	defer mmMu.Unlock()
	m := mmMatches[username]
	var out []BotSeat
	if m == nil {
		return out
	}
	for _, p := range m.Players {
		if !p.isBot {
			continue
		}
		out = append(out, BotSeat{p.Username, p.skill, fmt.Sprintf("%d", p.Team)})
	}
	return out
}

// ReleaseMatch مسابقه‌ی تمام‌شده را از mmMatches پاک می‌کند.
//
// بدونِ این، ورودی‌های مسابقه‌های قدیمی تا ابد می‌ماندند و busyNamesLocked
// بات‌هایشان را «مشغول» می‌دید. یعنی با هر مسابقه استخرِ بات کوچک‌تر می‌شد
// تا جایی که دیگر برای پر کردنِ یک مسابقه‌ی تازه بات کافی نبود و صف برای
// همیشه ناقص می‌ماند — بازی عملاً از کار می‌افتاد.
func ReleaseMatch(matchID string) {
	if matchID == "" {
		return
	}
	mmMu.Lock()
	defer mmMu.Unlock()
	for name, m := range mmMatches {
		if m != nil && m.MatchID == matchID {
			delete(mmMatches, name)
		}
	}
}

// matchTTL بعد از این مدت، یک مسابقه‌ی جورشده که هنوز آزاد نشده «مانده»
// حساب می‌شود و پاک می‌شود.
//
// چرا لازم است: mmMatches فقط با endRound آزاد می‌شد. هر مسیرِ دیگری —
// بازیکنی که وسطِ راه اپ را می‌بندد، راندی که اصلاً شروع نمی‌شود، سرور
// که وسطِ مسابقه ری‌استارت می‌شود — ورودی‌اش را برای همیشه جا می‌گذاشت و
// busyNamesLocked بات‌هایش را تا ابد «مشغول» می‌دید. استخرِ ۳۸تایی با هر
// نشستِ ناتمام آب می‌رفت و بعد از چند بار، جستجو دیگر بات کافی پیدا
// نمی‌کرد: گاهی همه اسپان می‌شدند، گاهی هیچ‌کس. همان «بعضی وقت‌ها هست و
// بعضی وقت‌ها نیست».
const matchTTL = 8 * time.Minute

// sweepStaleMatchesLocked مسابقه‌های مانده را پاک می‌کند. با mmMu گرفته
// شده صدا زده شود.
func sweepStaleMatchesLocked() int {
	now := time.Now()
	stale := map[string]bool{}
	for _, m := range mmMatches {
		if m != nil && now.Sub(m.MadeAt) > matchTTL {
			stale[m.MatchID] = true
		}
	}
	if len(stale) == 0 {
		return 0
	}
	n := 0
	for name, m := range mmMatches {
		if m != nil && stale[m.MatchID] {
			delete(mmMatches, name)
			n++
		}
	}
	fmt.Println("🧹 released stale matches:", len(stale), "— entries removed:", n)
	return n
}

// ReleaseMatchOf مسابقه‌ی یک بازیکن را کاملاً آزاد می‌کند — نه فقط سهمِ
// خودش. موقعِ قطعِ اتصال لازم است: اگر فقط اسمِ خودش پاک شود، بات‌های
// همان مسابقه در mmMatches می‌مانند و دیگر هیچ‌وقت آزاد نمی‌شوند.
func ReleaseMatchOf(username string) {
	mmMu.Lock()
	m := mmMatches[username]
	var id string
	if m != nil {
		id = m.MatchID
	}
	removeFromQueueLocked(username)
	delete(mmMatches, username)
	if id != "" {
		for name, other := range mmMatches {
			if other != nil && other.MatchID == id {
				delete(mmMatches, name)
			}
		}
	}
	mmMu.Unlock()
}

// otherHumansPending آدمِ دیگری (غیر از username) هنوز در مسابقه‌ی جورشده‌ی
// matchID است — مثلاً هنوز دارد زمین را بار می‌کند و در هاب نیست. وقتی
// بازیکنِ اول می‌رود، مسابقه نباید زیرِ پای او آزاد شود.
func otherHumansPending(matchID, username string) bool {
	if matchID == "" {
		return false
	}
	mmMu.Lock()
	defer mmMu.Unlock()
	for name, m := range mmMatches {
		if m == nil || m.MatchID != matchID || name == username {
			continue
		}
		for _, qp := range m.Players {
			if qp.Username == name && !qp.isBot {
				return true
			}
		}
	}
	return false
}

// ReleasePlayer یک بازیکن را از صف و از مسابقه‌ی جورشده بیرون می‌آورد.
// موقعِ قطعِ اتصال لازم است، وگرنه اسمش تا ابد «مشغول» می‌ماند.
func ReleasePlayer(username string) {
	mmMu.Lock()
	defer mmMu.Unlock()
	removeFromQueueLocked(username)
	delete(mmMatches, username)
}

// MatchOf مسابقه‌ی جورشده‌ی یک بازیکن.
//
// کپیِ سطحی برمی‌گرداند نه اشاره به ساختارِ زنده: صداکننده روی گوروتینِ Hub
// است و نباید بدونِ قفل به داده‌ی صف دست بزند.
func MatchOf(username string) *PendingMatch {
	mmMu.Lock()
	defer mmMu.Unlock()
	m := mmMatches[username]
	if m == nil {
		return nil
	}
	out := *m
	out.Players = append([]QueuedPlayer(nil), m.Players...)
	return &out
}

// ModeOfMatch حالتِ بازیِ یک مسابقه از روی شناسه‌اش. خالی یعنی پیدا نشد
// (مسابقه‌ی آزادشده یا تمرینِ بی‌مسابقه) — آن‌وقت قانونِ پیش‌فرض اعمال می‌شود.
func ModeOfMatch(matchID string) string {
	if matchID == "" {
		return ""
	}
	mmMu.Lock()
	defer mmMu.Unlock()
	for _, m := range mmMatches {
		if m != nil && m.MatchID == matchID {
			return m.ModeID
		}
	}
	return ""
}

// TeamOf تیمِ یک بازیکن در مسابقه‌ی جاری‌اش. خالی یعنی مسابقه‌ی بی‌تیم.
func TeamOf(username string) string {
	mmMu.Lock()
	defer mmMu.Unlock()
	m := mmMatches[username]
	if m == nil {
		return ""
	}
	for _, p := range m.Players {
		if p.Username == username {
			return fmt.Sprintf("%d", p.Team)
		}
	}
	return ""
}
