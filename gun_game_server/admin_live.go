package main

import (
	"context"
	"net/http"
	"os"
	"runtime"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// =============================================================================
// پنل مدیریت — وضعیت زنده، داشبورد و تاریخچه‌ی کارها
// =============================================================================

// runOnHub تابع را روی گوروتینِ Run هاب اجرا می‌کند و منتظر می‌ماند.
// اگر هاب در دو ثانیه جواب ندهد false برمی‌گرداند (مثلاً هنوز بالا نیامده).
func runOnHub(fn func(h *Hub)) bool {
	if globalHub == nil {
		return false
	}
	done := make(chan struct{})
	select {
	case globalHub.adminCalls <- func(h *Hub) { fn(h); close(done) }:
	case <-time.After(2 * time.Second):
		return false
	}
	select {
	case <-done:
		return true
	case <-time.After(2 * time.Second):
		return false
	}
}

type hubSnapshot struct {
	Connections int               `json:"connections"`
	Online      int               `json:"online"`
	InMatch     int               `json:"in_match"`
	Rounds      int               `json:"rounds"`
	Bots        int               `json:"bots"`
	Players     []hubOnlinePlayer `json:"players,omitempty"`
}

type hubOnlinePlayer struct {
	Username string `json:"username"`
	MatchID  string `json:"match_id,omitempty"`
	ModeID   string `json:"mode_id,omitempty"`
}

// takeHubSnapshot شمارش‌های زنده؛ withPlayers لیستِ اسم‌ها را هم می‌دهد
func takeHubSnapshot(withPlayers bool) (hubSnapshot, bool) {
	var snap hubSnapshot
	ok := runOnHub(func(h *Hub) {
		snap.Connections = len(h.clients)
		snap.Rounds = len(h.rounds)
		snap.Bots = len(h.bots)
		seen := map[string]bool{}
		for c := range h.clients {
			if c.username == "" || seen[c.username] {
				continue
			}
			seen[c.username] = true
			snap.Online++
			mid := h.playerRound[c.username]
			if mid != "" {
				snap.InMatch++
			}
			if withPlayers {
				p := hubOnlinePlayer{Username: c.username, MatchID: mid}
				if rs := h.rounds[mid]; rs != nil {
					p.ModeID = rs.ModeID
				}
				snap.Players = append(snap.Players, p)
			}
		}
	})
	return snap, ok
}

// kickFromHub اتصالِ وب‌سوکتِ بازیکن را می‌بندد؛ readPump خطا می‌گیرد و
// پاک‌سازیِ معمولِ قطع اتصال (حذف از راند و صف) انجام می‌شود.
func kickFromHub(username string) int {
	n := 0
	runOnHub(func(h *Hub) {
		for c := range h.clients {
			if c.username == username {
				// بیرون انداختن مهلتِ برگشت (reconnect.go) ندارد
				c.noGrace = true
				_ = c.conn.Close()
				n++
			}
		}
	})
	return n
}

// ------------------------------------------------------------ داشبورد

// iranOffset ایران از ۱۴۰۱ ساعت تابستانی ندارد؛ zoneinfo روی ویندوز هم
// همیشه در دسترس نیست، پس منطقه‌ی ثابت کافی و مطمئن‌تر است.
const iranOffset = "+03:30"

var iranZone = time.FixedZone("IRST", 3*3600+30*60)

func startOfIranDay(t time.Time) time.Time {
	t = t.In(iranZone)
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, iranZone)
}

// dailyCounts تعدادِ سندهای هر روز (به وقت ایران) در days روزِ اخیر
func dailyCounts(ctx context.Context, colName, field string, match bson.M, days int, sumField string) []map[string]interface{} {
	from := startOfIranDay(time.Now()).AddDate(0, 0, -(days - 1))
	m := bson.M{field: bson.M{"$gte": from}}
	for k, v := range match {
		m[k] = v
	}
	group := bson.M{
		"_id":   bson.M{"$dateToString": bson.M{"format": "%Y-%m-%d", "date": "$" + field, "timezone": iranOffset}},
		"count": bson.M{"$sum": 1},
	}
	if sumField != "" {
		group["sum"] = bson.M{"$sum": "$" + sumField}
	}
	cur, err := col(colName).Aggregate(ctx, []bson.M{{"$match": m}, {"$group": group}})
	byDay := map[string]bson.M{}
	if err == nil {
		var rows []bson.M
		_ = cur.All(ctx, &rows)
		for _, row := range rows {
			if k, ok := row["_id"].(string); ok {
				byDay[k] = row
			}
		}
	}
	out := make([]map[string]interface{}, 0, days)
	for i := 0; i < days; i++ {
		day := from.AddDate(0, 0, i).Format("2006-01-02")
		entry := map[string]interface{}{"day": day, "count": 0, "sum": 0}
		if row, ok := byDay[day]; ok {
			entry["count"] = row["count"]
			if s, ok := row["sum"]; ok {
				entry["sum"] = s
			}
		}
		out = append(out, entry)
	}
	return out
}

func countOf(ctx context.Context, colName string, filter bson.M) int64 {
	n, err := col(colName).CountDocuments(ctx, filter)
	if err != nil {
		return 0
	}
	return n
}

var humanPlayers = bson.M{"is_bot": bson.M{"$ne": true}}

func humans(extra bson.M) bson.M {
	f := bson.M{"is_bot": bson.M{"$ne": true}}
	for k, v := range extra {
		f[k] = v
	}
	return f
}

// GET /admin/api/dashboard
func adminDashboardHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	now := time.Now()
	today := startOfIranDay(now)
	day := now.Add(-24 * time.Hour)
	week := now.Add(-7 * 24 * time.Hour)

	snap, hubOK := takeHubSnapshot(false)

	// درآمد تخمینی: قیمتِ فعلیِ بسته‌ی همان محصول (تخفیفِ لحظه‌ی خرید ذخیره نشده)
	revenue := func(since time.Time) (count int64, gems int64, toman int64) {
		cur, err := col(ColIAPPurchases).Find(ctx, bson.M{"state": "credited", "created_at": bson.M{"$gte": since}})
		if err != nil {
			return
		}
		var rows []IAPPurchase
		_ = cur.All(ctx, &rows)
		for _, p := range rows {
			count++
			gems += int64(p.Gems)
			if pack, ok := findGemPackByProduct(p.ProductID); ok {
				toman += int64(pack.FinalPrice())
			}
		}
		return
	}
	r1c, r1g, r1t := revenue(day)
	r7c, r7g, r7t := revenue(week)

	jsonResponse(w, map[string]interface{}{
		"players": map[string]interface{}{
			"total":       countOf(ctx, ColPlayers, humanPlayers),
			"new_today":   countOf(ctx, ColPlayers, humans(bson.M{"created_at": bson.M{"$gte": today}})),
			"new_week":    countOf(ctx, ColPlayers, humans(bson.M{"created_at": bson.M{"$gte": week}})),
			"active_day":  countOf(ctx, ColPlayers, humans(bson.M{"last_seen_at": bson.M{"$gte": day}})),
			"active_week": countOf(ctx, ColPlayers, humans(bson.M{"last_seen_at": bson.M{"$gte": week}})),
			"google":      countOf(ctx, ColPlayers, humans(bson.M{"auth.google_id": bson.M{"$exists": true, "$ne": ""}})),
			"banned":      countOf(ctx, ColPlayers, humans(bson.M{"is_banned": true})),
			"online_db":   countOf(ctx, ColPlayers, humans(bson.M{"is_online": true})),
		},
		"live": map[string]interface{}{
			"ok": hubOK, "online": snap.Online, "in_match": snap.InMatch,
			"rounds": snap.Rounds, "connections": snap.Connections,
		},
		"support": map[string]interface{}{
			"new":  countOf(ctx, ColSupportMsgs, bson.M{"status": SupportStatusNew}),
			"open": countOf(ctx, ColSupportMsgs, bson.M{"status": bson.M{"$in": []string{SupportStatusNew, SupportStatusRead}}}),
			"week": countOf(ctx, ColSupportMsgs, bson.M{"created_at": bson.M{"$gte": week}}),
		},
		"economy": map[string]interface{}{
			"purchases_day": r1c, "gems_day": r1g, "toman_day": r1t,
			"purchases_week": r7c, "gems_week": r7g, "toman_week": r7t,
			"gift_redemptions_week": countOf(ctx, ColGiftRedemptions, bson.M{"created_at": bson.M{"$gte": week}}),
		},
		"clans":        countOf(ctx, ColClans, bson.M{}),
		"matches_week": countOf(ctx, ColMatches, bson.M{"started_at": bson.M{"$gte": week}}),
		"signups":      dailyCounts(ctx, ColPlayers, "created_at", humanPlayers, 14, ""),
		"active":       dailyCounts(ctx, ColPlayers, "last_seen_at", humanPlayers, 14, ""),
		"sales":        dailyCounts(ctx, ColIAPPurchases, "created_at", bson.M{"state": "credited"}, 14, "gems"),
		"tickets":      dailyCounts(ctx, ColSupportMsgs, "created_at", nil, 14, ""),
		"generated_at": now,
	})
}

// GET /admin/api/online — لیست بازیکن‌های وصل به هاب
func adminOnlineHandler(w http.ResponseWriter, r *http.Request) {
	snap, ok := takeHubSnapshot(true)
	if !ok {
		httpError(w, "هاب پاسخ نداد", http.StatusServiceUnavailable)
		return
	}
	sort.Slice(snap.Players, func(i, j int) bool { return snap.Players[i].Username < snap.Players[j].Username })
	if snap.Players == nil {
		snap.Players = []hubOnlinePlayer{}
	}
	// آیدیِ عمومی برای باز کردنِ صفحه‌ی بازیکن
	names := make([]string, 0, len(snap.Players))
	for _, p := range snap.Players {
		names = append(names, p.Username)
	}
	ids := map[string]string{}
	if len(names) > 0 {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		cur, err := col(ColPlayers).Find(ctx, bson.M{"username": bson.M{"$in": names}})
		if err == nil {
			var rows []PlayerModel
			_ = cur.All(ctx, &rows)
			for _, p := range rows {
				ids[p.Username] = p.PlayerID
			}
		}
	}
	out := make([]map[string]interface{}, 0, len(snap.Players))
	for _, p := range snap.Players {
		out = append(out, map[string]interface{}{
			"username": p.Username, "player_id": ids[p.Username], "match_id": p.MatchID, "mode_id": p.ModeID,
		})
	}
	jsonResponse(w, map[string]interface{}{"snapshot": snap, "players": out})
}

// GET /admin/api/server — سلامت سرور
func adminServerHandler(w http.ResponseWriter, r *http.Request) {
	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)
	snap, hubOK := takeHubSnapshot(false)

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	dbOK := db != nil && db.Client().Ping(ctx, nil) == nil
	collections := map[string]int64{}
	for _, name := range []string{ColPlayers, ColMessages, ColSupportMsgs, ColChatMessages, ColClans,
		ColMatches, ColIAPPurchases, ColGiftCodes, ColGiftRedemptions, ColAdminAudit} {
		n, _ := col(name).EstimatedDocumentCount(ctx)
		collections[name] = n
	}

	set := func(key string) bool { return os.Getenv(key) != "" }
	jsonResponse(w, map[string]interface{}{
		"started_at":  adminStartedAt,
		"uptime_sec":  int64(time.Since(adminStartedAt).Seconds()),
		"go_version":  runtime.Version(),
		"goroutines":  runtime.NumGoroutine(),
		"mem_alloc":   mem.Alloc,
		"mem_sys":     mem.Sys,
		"gc_count":    mem.NumGC,
		"db_ok":       dbOK,
		"hub_ok":      hubOK,
		"hub":         snap,
		"collections": collections,
		"config": map[string]bool{
			"google_signin":   googleCfg.webFlowReady(),
			"game_server_key": set("GAME_SERVER_KEY"),
			"bazaar_api":      set("BAZAAR_API_SECRET"),
			"myket_api":       set("MYKET_ACCESS_TOKEN"),
			"iap_debug":       os.Getenv("IAP_ALLOW_DEBUG") == "1",
			"trust_proxy":     trustProxy,
		},
	})
}

// GET /admin/api/audit?admin=&action=&target=&page=
func adminAuditHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	q := r.URL.Query()
	filter := bson.M{}
	for _, key := range []string{"admin", "action", "target"} {
		if v := q.Get(key); v != "" {
			filter[key] = v
		}
	}
	page, size := adminPage(r, 50)
	cur, err := col(ColAdminAudit).Find(ctx, filter, findPage(page, size, bson.D{{Key: "at", Value: -1}}))
	if err != nil {
		httpError(w, "خطا در خواندن", http.StatusInternalServerError)
		return
	}
	rows := []AdminAuditEntry{}
	_ = cur.All(ctx, &rows)
	jsonResponse(w, map[string]interface{}{
		"entries": rows, "total": countOf(ctx, ColAdminAudit, filter), "page": page, "size": size,
	})
}
