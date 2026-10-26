package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// صفِ پیدا کردنِ حریف.
//
// در حافظه نگه داشته می‌شود و نه در دیتابیس: صف چیزی است که هر ثانیه عوض
// می‌شود و بعد از ری‌استارت هم بی‌معنی است. چیزی که ماندگار است (کاپ، نتیجه)
// همچنان در مونگو می‌نشیند.

// QueuedPlayer یک بازیکنِ داخل صف، با همان اطلاعاتی که صفحه‌ی انتظار
// نشان می‌دهد. یک بار موقع ورود به صف از دیتابیس خوانده می‌شود تا هر بار
// پرسیدنِ وضعیت به مونگو نخورد.
type QueuedPlayer struct {
	Username string `json:"username"`
	PlayerID string `json:"player_id"`
	AvatarID string `json:"avatar_id"`
	// کاراکترِ تجهیزشده — تا وقتی آرتِ آواتار نداریم، صفحه‌ی انتظار همین را
	// به‌عنوان عکسِ پروفایل نشان می‌دهد (assets/items/<id>.png)
	Character string `json:"character"`
	Trophies  int    `json:"trophies"`
	Level     int    `json:"level"`
	RankID    string `json:"rank_id"`
	RankName  string `json:"rank_name"`
	Team      int    `json:"team"` // ۰ یا ۱ — بعد از جور شدنِ مسابقه پر می‌شود
	joinedAt  time.Time

	// این دو عمداً unexported اند: encoding/json فیلدِ unexported را اصلاً
	// نمی‌بیند، پس هیچ راهی نیست که «این حریف بات است» به کلاینت درز کند.
	isBot bool
	skill string
}

// PendingMatch مسابقه‌ای که جور شده و منتظر است بازیکن‌ها تحویلش بگیرند
type PendingMatch struct {
	MatchID string         `json:"match_id"`
	ModeID  string         `json:"mode_id"`
	Players []QueuedPlayer `json:"players"`
	// تمِ ظاهریِ زمین — از روی بالاترین رنکِ شرکت‌کننده‌ها (themes.go)
	Theme  string    `json:"theme"`
	MadeAt time.Time `json:"-"`
}

// قوانینِ جستجو:
//
//	۰ تا HumanSearchFor ثانیه: فقط آدم‌هایی که کاپشان حداکثر TrophyWindow
//	                            بالاتر یا پایین‌تر است.
//	از HumanSearchFor به بعد:   بازه برای کسی که این‌قدر منتظر مانده باز
//	                            می‌شود و هر آدمی که در صفِ همین حالت است
//	                            کنارش می‌نشیند — آدمِ واقعی از بات بهتر است.
//	از BackfillAfter به بعد:    صندلی‌های خالی با نزدیک‌ترین بات‌ها از نظرِ
//	                            کاپ پر می‌شوند (mm_backfill.go).
//
// قبلاً بازه هیچ‌وقت باز نمی‌شد: دو بازیکنِ دور از هم یکدیگر را در لیستِ
// صفحه‌ی جستجو می‌دیدند ولی سرِ ۲۰ ثانیه هر کدام جدا با بات می‌افتاد. تیم‌بندیِ
// ماری (formMatchLocked) اختلافِ کاپ را بینِ دو تیم پخش می‌کند.
const (
	TrophyWindow   = 200
	HumanSearchFor = 15 * time.Second
)

var (
	mmMu      sync.Mutex
	mmQueues  = map[string][]*QueuedPlayer{} // mode_id -> صف
	mmMatches = map[string]*PendingMatch{}   // username -> مسابقه‌ی جورشده
	mmCounter int
)

// trophyTier یک پله از رنک‌ها با بازه‌ی کاپش. Max صفر یعنی سقف ندارد.
type trophyTier struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Min  int    `json:"min"`
	Max  int    `json:"max"`
}

// trophyTiers آستانه‌های رنک بر اساس کاپ — تنها منبع این اعداد.
// کلاینت همین جدول را از /profile می‌گیرد (rank_tiers).
var trophyTiers = []trophyTier{
	{ID: "bronze", Name: "برنز", Min: 0, Max: 1000},
	{ID: "silver", Name: "نقره", Min: 1001, Max: 1600},
	{ID: "gold", Name: "طلا", Min: 1601, Max: 2200},
	{ID: "platinum", Name: "پلاتین", Min: 2201, Max: 2800},
	{ID: "diamond", Name: "الماس", Min: 2801, Max: 3400},
	{ID: "legend", Name: "لجندری", Min: 3401, Max: 0},
}

// tierIndexOf جایگاه یک رنک در trophyTiers؛ ناشناخته = ۰ (برنز)
func tierIndexOf(id string) int {
	for i, t := range trophyTiers {
		if t.ID == id {
			return i
		}
	}
	return 0
}

// rankFromTrophies رتبه را از روی کاپ حساب می‌کند. آستانه‌ها در trophyTiers
// هستند چون هم صفحه‌ی انتظار و هم هر جای دیگری باید یک عدد را یک‌جور بخوانند.
func rankFromTrophies(trophies int) (string, string) {
	for i := len(trophyTiers) - 1; i >= 0; i-- {
		if trophies >= trophyTiers[i].Min {
			return trophyTiers[i].ID, trophyTiers[i].Name
		}
	}
	return trophyTiers[0].ID, trophyTiers[0].Name
}

// rankViewOf رنک ذخیره‌شده‌ی بازیکن با tier همگام با کاپِ فعلی.
// points = کاپ، points_max = سقف بازه‌ی رنک فعلی (برای لجندری همان کاپ).
func rankViewOf(p *PlayerModel) PlayerRank {
	r := p.Rank
	r.TierID, r.TierName = rankFromTrophies(p.Trophies)
	tier := trophyTiers[tierIndexOf(r.TierID)]
	r.Points = int64(p.Trophies)
	r.PointsMax = int64(tier.Max)
	if tier.Max == 0 {
		r.PointsMax = int64(p.Trophies)
	}
	if tierIndexOf(r.BestTierID) < tierIndexOf(r.TierID) || r.BestTierID == "" {
		r.BestTierID = r.TierID
	}
	return r
}

// removeFromQueueLocked بازیکن را از هر صفی که باشد بیرون می‌کشد.
// باید با mmMu گرفته‌شده صدا زده شود.
func removeFromQueueLocked(username string) {
	for mode, q := range mmQueues {
		out := q[:0]
		for _, p := range q {
			if p.Username != username {
				out = append(out, p)
			}
		}
		mmQueues[mode] = out
	}
}

// withinWindow آیا دو کاپ آن‌قدر به هم نزدیک‌اند که حریف شوند؟
func withinWindow(a, b int) bool {
	d := a - b
	if d < 0 {
		d = -d
	}
	return d <= TrophyWindow
}

// peersOfLocked همه‌ی کسانی در صف که می‌توانند هم‌بازیِ anchor شوند، نزدیک‌ترین
// کاپ اول (و در کاپِ برابر، کسی که زودتر آمده). خودِ anchor در خروجی نیست.
// تا HumanSearchFor فقط هم‌سطح‌ها؛ بعد از آن هر آدمی در صف.
func peersOfLocked(q []*QueuedPlayer, anchor *QueuedPlayer) []*QueuedPlayer {
	wide := time.Since(anchor.joinedAt) >= HumanSearchFor
	var out []*QueuedPlayer
	for _, p := range q {
		if p != anchor && (wide || withinWindow(p.Trophies, anchor.Trophies)) {
			out = append(out, p)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		return trophyGap(out[i], anchor) < trophyGap(out[j], anchor)
	})
	return out
}

func trophyGap(p, anchor *QueuedPlayer) int {
	d := p.Trophies - anchor.Trophies
	if d < 0 {
		return -d
	}
	return d
}

// tryFormMatchLocked اگر به‌اندازه‌ی کافی آدمِ هم‌سطح در صفِ این حالت باشد،
// مسابقه می‌سازد.
//
// هر بازیکن، به ترتیبِ ورود، یک بار «لنگر» می‌شود: همه باید در بازه‌ی
// TrophyWindowِ کاپِ او باشند. پس کسی که از همه زودتر آمده اول نوبت دارد،
// ولی اگر برایش هم‌سطحی نیست، صف پشتِ او گیر نمی‌کند و دو نفرِ هم‌سطحِ
// دیگر می‌توانند با هم جور شوند.
func tryFormMatchLocked(modeID string, teamSize int) *PendingMatch {
	need := teamSize * 2
	q := mmQueues[modeID]
	if len(q) < need {
		return nil
	}
	for _, anchor := range q {
		peers := peersOfLocked(q, anchor)
		if len(peers)+1 < need {
			continue
		}
		group := append([]*QueuedPlayer{anchor}, peers[:need-1]...)
		return formMatchLocked(modeID, group)
	}
	return nil
}

// formMatchLocked از یک گروهِ کامل مسابقه می‌سازد: آدم‌ها از صف بیرون می‌آیند،
// تیم‌ها چیده می‌شوند و تمِ زمین انتخاب می‌شود. با mmMu گرفته‌شده.
//
// تیم‌بندی «مار»ی است روی کاپ‌ها (۰،۱،۱،۰،۰،۱...): قوی‌ترین با ضعیف‌ترین
// هم‌تیم می‌شود و جمعِ کاپِ دو تیم نزدیک می‌ماند. یک‌درمیانِ ساده همیشه
// نفرِ قوی‌ترِ هر جفت را به تیمِ صفر می‌داد.
func formMatchLocked(modeID string, group []*QueuedPlayer) *PendingMatch {
	taken := map[*QueuedPlayer]bool{}
	for _, p := range group {
		taken[p] = true
	}
	rest := mmQueues[modeID][:0]
	for _, p := range mmQueues[modeID] {
		if !taken[p] {
			rest = append(rest, p)
		}
	}
	mmQueues[modeID] = rest

	ordered := append([]*QueuedPlayer(nil), group...)
	sort.SliceStable(ordered, func(i, j int) bool { return ordered[i].Trophies > ordered[j].Trophies })

	mmCounter++
	m := &PendingMatch{
		MatchID: fmt.Sprintf("m%d-%d", time.Now().Unix(), mmCounter),
		ModeID:  modeID,
		MadeAt:  time.Now(),
	}
	for i, p := range ordered {
		p.Team = (i + i/2) % 2 // ۰،۱،۱،۰،۰،۱،۱،۰
		m.Players = append(m.Players, *p)
	}
	m.Theme = themeForPlayers(m.Players)
	for _, p := range m.Players {
		mmMatches[p.Username] = m
	}
	return m
}

// joinMatchmakingHandler بازیکن را وارد صف می‌کند
func joinMatchmakingHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "متد اشتباه است", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Username string `json:"username"`
		ModeID   string `json:"mode_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" || req.ModeID == "" {
		httpError(w, "درخواست ناقص است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	mode, err := gameModeByID(ctx, req.ModeID)
	if err != nil {
		httpError(w, "این حالت بازی وجود ندارد", http.StatusNotFound)
		return
	}
	if mode.ComingSoon {
		httpError(w, "این حالت به زودی می‌آید", http.StatusForbidden)
		return
	}

	var p PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": req.Username}).Decode(&p); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if p.Trophies < mode.MinTrophies {
		httpError(w, "برای این حالت هنوز کاپ کافی نداری", http.StatusForbidden)
		return
	}

	rankID, rankName := rankFromTrophies(p.Trophies)
	entry := &QueuedPlayer{
		Username:  p.Username,
		PlayerID:  p.PlayerID,
		AvatarID:  p.AvatarID,
		Character: p.EquippedCharacter,
		Trophies:  p.Trophies,
		Level:     p.Level,
		RankID:    rankID,
		RankName:  rankName,
		Team:      -1,
		joinedAt:  time.Now(),
	}

	mmMu.Lock()
	// ورودِ دوباره نباید بازیکن را دو بار در صف بگذارد
	removeFromQueueLocked(req.Username)
	delete(mmMatches, req.Username)
	mmQueues[req.ModeID] = append(mmQueues[req.ModeID], entry)
	match := tryFormMatchLocked(req.ModeID, mode.TeamSize)
	waiting := len(mmQueues[req.ModeID])
	mmMu.Unlock()

	resp := map[string]interface{}{
		"success":    true,
		"mode_id":    mode.ModeID,
		"team_size":  mode.TeamSize,
		"need":       mode.TeamSize * 2,
		"in_queue":   waiting,
		"you":        entry,
		"match_made": match != nil,
	}
	if match != nil {
		resp["match"] = match
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// matchmakingStatusHandler وضعیتِ جستجو را می‌گوید: هنوز در صف است یا
// مسابقه‌اش جور شده. کلاینت همین را دوره‌ای می‌پرسد.
func matchmakingStatusHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "نام کاربری لازم است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	mmMu.Lock()
	match := mmMatches[username]
	var myMode string
	var waiting int
	var inQueue bool
	for mode, q := range mmQueues {
		for _, p := range q {
			if p.Username == username {
				myMode, waiting, inQueue = mode, len(q), true
			}
		}
	}
	// شاید بین دو بار پرسیدن، نفرِ آخر آمده باشد
	var backfillMode string
	var backfillTeam int
	if match == nil && inQueue {
		if mode, err := gameModeByID(ctx, myMode); err == nil {
			if made := tryFormMatchLocked(myMode, mode.TeamSize); made != nil {
				for _, p := range made.Players {
					if p.Username == username {
						match = made
					}
				}
			} else {
				// آدمِ کافی نیست — شاید وقتِ آوردنِ بات باشد. خودِ کار بیرونِ
				// این قفل انجام می‌شود چون به دیتابیس می‌خورد.
				backfillMode, backfillTeam = myMode, mode.TeamSize
			}
		}
	}
	mmMu.Unlock()

	if match == nil && backfillMode != "" {
		if made := maybeBackfill(ctx, username, backfillMode, backfillTeam); made != nil {
			for _, p := range made.Players {
				if p.Username == username {
					match = made
				}
			}
		}
	}

	resp := map[string]interface{}{}
	if match != nil {
		resp["state"] = "ready"
		resp["match"] = match
		resp["mode_id"] = match.ModeID
	} else if inQueue {
		mmMu.Lock()
		// فقط خودت و کسانی که واقعاً می‌توانند هم‌بازی‌ات شوند. قبلاً کلِ صفِ
		// حالت فرستاده می‌شد و بازیکن آدمی را «پیدا شده» می‌دید که بعد با
		// او نمی‌افتاد.
		roster := []QueuedPlayer{}
		var waited time.Duration
		if me := queuedLocked(myMode, username); me != nil {
			waited = time.Since(me.joinedAt)
			roster = append(roster, *me)
			for _, p := range peersOfLocked(mmQueues[myMode], me) {
				roster = append(roster, *p)
			}
		}
		mmMu.Unlock()
		// «human» = هنوز دنبالِ آدمِ هم‌سطح؛ «bots» = هم‌سطحی پیدا نشد و
		// بات‌ها سرِ BackfillAfter می‌آیند. کلاینت فقط متنش را عوض می‌کند.
		phase := "human"
		if waited >= HumanSearchFor {
			phase = "bots"
		}
		resp["phase"] = phase
		resp["waited"] = int(waited.Seconds())
		resp["bots_at"] = int(BackfillAfter.Seconds())
		var need int
		if mode, err := gameModeByID(ctx, myMode); err == nil {
			need = mode.TeamSize * 2
		}
		resp["state"] = "searching"
		resp["mode_id"] = myMode
		resp["in_queue"] = waiting
		resp["need"] = need
		resp["players"] = roster
	} else {
		resp["state"] = "idle"
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// leaveMatchmakingHandler بازیکن را از صف بیرون می‌آورد (دکمه‌ی لغو)
func leaveMatchmakingHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	var req struct {
		Username string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		httpError(w, "درخواست ناقص است", http.StatusBadRequest)
		return
	}

	mmMu.Lock()
	removeFromQueueLocked(req.Username)
	delete(mmMatches, req.Username)
	mmMu.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"success": true})
}
