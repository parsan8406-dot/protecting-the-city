package main

import (
	"context"
	"net/http"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// پنل مدیریت — بازیکن‌ها
// =============================================================================

// adminPlayerRow ستون‌های جدولِ بازیکن‌ها — کل سند برای لیست سنگین است
func adminPlayerRow(p PlayerModel) map[string]interface{} {
	return map[string]interface{}{
		"player_id": p.PlayerID, "username": p.Username, "avatar_id": p.AvatarID,
		"level": p.Level, "coins": p.Coins, "gems": p.Gems, "trophies": p.Trophies,
		"is_online": p.IsOnline, "last_seen_at": p.LastSeenAt, "created_at": p.CreatedAt,
		"is_banned": banActive(p.IsBanned, p.BannedUntil, time.Now()), "is_bot": p.IsBot,
		"google": p.Auth.GoogleID != "", "clan_id": p.ClanID,
		"matches": p.Stats.TotalMatches,
	}
}

var adminPlayerProjection = bson.M{
	"player_id": 1, "username": 1, "avatar_id": 1, "level": 1, "coins": 1, "gems": 1,
	"trophies": 1, "is_online": 1, "last_seen_at": 1, "created_at": 1, "is_banned": 1,
	"banned_until": 1, "is_bot": 1, "auth.google_id": 1, "clan_id": 1, "stats.total_matches": 1,
}

// GET /admin/api/players?q=&filter=&sort=&page=
func adminPlayersHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	q := r.URL.Query()

	filter := bson.M{}
	switch q.Get("filter") {
	case "bots":
		filter["is_bot"] = true
	default:
		filter["is_bot"] = bson.M{"$ne": true}
	}
	switch q.Get("filter") {
	case "online":
		filter["is_online"] = true
	case "banned":
		filter["is_banned"] = true
	case "google":
		filter["auth.google_id"] = bson.M{"$exists": true, "$ne": ""}
	case "guest":
		filter["auth.google_id"] = bson.M{"$in": []interface{}{nil, ""}}
	case "muted":
		filter["chat_muted_until"] = bson.M{"$gt": time.Now()}
	case "new":
		filter["created_at"] = bson.M{"$gte": time.Now().Add(-24 * time.Hour)}
	}
	if search := strings.TrimSpace(q.Get("q")); search != "" {
		or := []bson.M{
			{"username": bson.M{"$regex": regexEscape(search), "$options": "i"}},
			{"player_id": search},
			{"auth.email": strings.ToLower(search)},
			{"clan_id": search},
		}
		filter["$or"] = or
	}

	sortKey := map[string]string{
		"created": "created_at", "seen": "last_seen_at", "level": "experience",
		"trophies": "trophies", "coins": "coins", "gems": "gems", "matches": "stats.total_matches",
	}[q.Get("sort")]
	if sortKey == "" {
		sortKey = "last_seen_at"
	}
	page, size := adminPage(r, 30)
	opts := findPage(page, size, bson.D{{Key: sortKey, Value: -1}}).SetProjection(adminPlayerProjection)
	cur, err := col(ColPlayers).Find(ctx, filter, opts)
	if err != nil {
		httpError(w, "خطا در جستجو", http.StatusInternalServerError)
		return
	}
	var players []PlayerModel
	_ = cur.All(ctx, &players)
	rows := make([]map[string]interface{}, 0, len(players))
	for _, p := range players {
		rows = append(rows, adminPlayerRow(p))
	}
	jsonResponse(w, map[string]interface{}{
		"players": rows, "total": countOf(ctx, ColPlayers, filter), "page": page, "size": size,
	})
}

// adminFindPlayer با player_id یا username (هر کدام که داده شده)
func adminFindPlayer(ctx context.Context, playerID, username string) (*PlayerModel, error) {
	if playerID != "" {
		return getPlayerByID(ctx, playerID)
	}
	return getPlayerByUsername(ctx, strings.TrimSpace(username))
}

func findAll[T any](ctx context.Context, colName string, filter bson.M, sortField string, limit int64) []T {
	out := []T{}
	cur, err := col(colName).Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: sortField, Value: -1}}).SetLimit(limit))
	if err != nil {
		return out
	}
	_ = cur.All(ctx, &out)
	return out
}

// GET /admin/api/player?player_id=  (یا ?username=)
func adminPlayerHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	p, err := adminFindPlayer(ctx, r.URL.Query().Get("player_id"), r.URL.Query().Get("username"))
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	sessions := make([]map[string]interface{}, 0, len(p.Auth.Sessions))
	for _, s := range p.Auth.Sessions {
		sessions = append(sessions, map[string]interface{}{"device": s.Device, "created_at": s.CreatedAt})
	}
	clanName := ""
	if p.ClanID != "" {
		clanName = clanNamesFor(ctx, []string{p.ClanID})[p.ClanID]
	}
	live := map[string]interface{}{"connected": false}
	runOnHub(func(h *Hub) {
		for c := range h.clients {
			if c.username == p.Username {
				live["connected"] = true
			}
		}
		if mid := h.playerRound[p.Username]; mid != "" {
			live["match_id"] = mid
			if rs := h.rounds[mid]; rs != nil {
				live["mode_id"] = rs.ModeID
			}
		}
	})

	friends := findPlayersByIDs(ctx, p.Friends)
	friendRows := make([]map[string]interface{}, 0, len(friends))
	for _, f := range friends {
		friendRows = append(friendRows, map[string]interface{}{"player_id": f.PlayerID, "username": f.Username, "level": f.Level})
	}

	var purchases []IAPPurchase = findAll[IAPPurchase](ctx, ColIAPPurchases, bson.M{"player_id": p.PlayerID}, "created_at", 50)
	purchaseRows := make([]map[string]interface{}, 0, len(purchases))
	for _, pc := range purchases {
		purchaseRows = append(purchaseRows, iapRow(pc))
	}

	level, into, need := levelFromExperience(p.Experience)
	jsonResponse(w, map[string]interface{}{
		"player": p, // PlayerModel خودش فیلدهای محرمانه را json:"-" کرده
		"computed": map[string]interface{}{
			"level_from_xp": level, "xp_into": into, "xp_need": need,
			"win_rate": p.Stats.WinRate(), "kd": p.Stats.KDRatio(),
		},
		"account": map[string]interface{}{
			"provider": p.Auth.Provider, "is_guest": p.Auth.IsGuest, "email": p.Auth.Email,
			"google_linked": p.Auth.GoogleID != "", "google_name": p.Auth.GoogleName,
			"linked_at": p.Auth.LinkedAt, "last_login_at": p.Auth.LastLoginAt, "sessions": sessions,
		},
		"moderation": map[string]interface{}{
			"is_banned":        banActive(p.IsBanned, p.BannedUntil, time.Now()),
			"ban_reason":       p.BanReason,
			"banned_at":        p.BannedAt,
			"banned_until":     p.BannedUntil,
			"chat_muted_until": p.ChatMutedUntil,
			"is_bot":           p.IsBot,
		},
		"recent_matches": nonNilMatches(p.RecentMatches),
		"clan_name":      clanName,
		"live":           live,
		"friends":        friendRows,
		"purchases":      purchaseRows,
		"messages":       findAll[MessageModel](ctx, ColMessages, bson.M{"recipient_id": p.PlayerID}, "created_at", 40),
		"tickets":        findAll[SupportMessageModel](ctx, ColSupportMsgs, bson.M{"player_id": p.PlayerID}, "created_at", 30),
		"redemptions":    findAll[bson.M](ctx, ColGiftRedemptions, bson.M{"player_id": p.PlayerID}, "created_at", 30),
		"notes":          findAll[bson.M](ctx, ColAdminNotes, bson.M{"player_id": p.PlayerID}, "at", 50),
		"audit":          findAll[AdminAuditEntry](ctx, ColAdminAudit, bson.M{"target": p.PlayerID}, "at", 50),
	})
}

func nonNilMatches(m []RecentMatch) []RecentMatch {
	if m == nil {
		return []RecentMatch{}
	}
	return m
}

// notifyAccountChanged به کلاینتِ آنلاین می‌گوید پیام/دارایی تازه دارد
func notifyAccountChanged(username string) {
	NotifyUser(username, map[string]interface{}{"type": "notification", "kind": MsgTypeAdmin})
}

// ------------------------------------------------------------ اقتصاد

type adminEconomyRequest struct {
	PlayerID string `json:"player_id"`
	Mode     string `json:"mode"` // "add" (پیش‌فرض) یا "set"
	Coins    *int   `json:"coins"`
	Gems     *int   `json:"gems"`
	Trophies *int   `json:"trophies"`
	XP       *int   `json:"experience"`
	Reason   string `json:"reason"`
}

// POST /admin/api/player/economy
// با mode=add عددها اضافه/کم می‌شوند (هیچ‌وقت زیر صفر نمی‌رود)، با set مستقیم.
// سطح همیشه از روی تجربه دوباره حساب می‌شود.
func adminPlayerEconomyHandler(w http.ResponseWriter, r *http.Request) {
	var req adminEconomyRequest
	if !adminDecode(w, r, &req) {
		return
	}
	if strings.TrimSpace(req.Reason) == "" {
		httpError(w, "دلیل تغییر را بنویسید", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	before, err := getPlayerByID(ctx, req.PlayerID)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	fields := map[string]*int{"coins": req.Coins, "gems": req.Gems, "trophies": req.Trophies, "experience": req.XP}
	// سقفِ هر تغییر — یک صفرِ اضافه (یا حسابِ دزدیده‌شده) نمی‌تواند اقتصاد را بترکاند
	caps := map[string]int{"coins": 10_000_000, "gems": 100_000, "trophies": 100_000, "experience": 10_000_000}
	for field, v := range fields {
		if v != nil && (*v > caps[field] || *v < -caps[field]) {
			httpError(w, "مقدار "+field+" بیش از حد مجاز است", http.StatusBadRequest)
			return
		}
	}
	set := bson.M{"updated_at": time.Now()}
	for field, v := range fields {
		if v == nil {
			continue
		}
		if req.Mode == "set" {
			if *v < 0 {
				httpError(w, "مقدار منفی مجاز نیست", http.StatusBadRequest)
				return
			}
			set[field] = *v
		} else if *v != 0 {
			// اتمیک و بدون رفتن زیر صفر، حتی اگر همین لحظه بازیکن خرید کند
			set[field] = bson.M{"$max": bson.A{0, bson.M{"$add": bson.A{bson.M{"$ifNull": bson.A{"$" + field, 0}}, *v}}}}
		}
	}
	if len(set) == 1 {
		httpError(w, "هیچ تغییری وارد نشده", http.StatusBadRequest)
		return
	}
	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.PlayerID}, bson.A{bson.M{"$set": set}}); err != nil {
		httpError(w, "ذخیره نشد: "+err.Error(), http.StatusInternalServerError)
		return
	}
	after, _ := getPlayerByID(ctx, req.PlayerID)
	if after != nil {
		if lvl, _, _ := levelFromExperience(after.Experience); lvl != after.Level {
			_, _ = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.PlayerID}, bson.M{"$set": bson.M{"level": lvl}})
			after.Level = lvl
		}
	}
	details := map[string]interface{}{"mode": req.Mode, "reason": req.Reason,
		"before": map[string]int{"coins": before.Coins, "gems": before.Gems, "trophies": before.Trophies, "experience": before.Experience}}
	if after != nil {
		details["after"] = map[string]int{"coins": after.Coins, "gems": after.Gems, "trophies": after.Trophies, "experience": after.Experience, "level": after.Level}
	}
	audit(r, "player_economy", req.PlayerID, details)
	notifyAccountChanged(before.Username)
	jsonResponse(w, map[string]interface{}{"success": true, "player": after})
}

// ------------------------------------------------------------ آیتم‌ها

// POST /admin/api/player/items {"player_id","action":"add|remove","kind":"weapon|character|skin","item_id"}
func adminPlayerItemsHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PlayerID string `json:"player_id"`
		Action   string `json:"action"`
		Kind     string `json:"kind"`
		ItemID   string `json:"item_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	req.ItemID = strings.TrimSpace(req.ItemID)
	field := map[string]string{"weapon": "owned_weapons", "character": "owned_characters", "skin": "owned_skins"}[req.Kind]
	if field == "" || req.ItemID == "" || (req.Action != "add" && req.Action != "remove") {
		httpError(w, "درخواست نامعتبر", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	p, err := getPlayerByID(ctx, req.PlayerID)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if req.Action == "add" {
		switch req.Kind {
		case "skin":
			if !isSkinID(req.ItemID) {
				httpError(w, "چنین اسکینی وجود ندارد", http.StatusBadRequest)
				return
			}
		default:
			if countOf(ctx, ColShopItems, bson.M{"item_id": req.ItemID, "category": req.Kind}) == 0 {
				httpError(w, "چنین آیتمی در فروشگاه نیست", http.StatusBadRequest)
				return
			}
		}
	} else {
		// آیتمِ مجهز را نمی‌شود گرفت — بازیکن با چیزی که ندارد وارد بازی می‌شد
		if (req.Kind == "weapon" && p.EquippedWeapon == req.ItemID) || (req.Kind == "character" && p.EquippedCharacter == req.ItemID) {
			httpError(w, "این آیتم الان مجهز است؛ اول بازیکن باید عوضش کند", http.StatusConflict)
			return
		}
	}
	update := bson.M{"$addToSet": bson.M{field: req.ItemID}}
	if req.Action == "remove" {
		update = bson.M{"$pull": bson.M{field: req.ItemID}}
	}
	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.PlayerID}, update); err != nil {
		httpError(w, "ذخیره نشد", http.StatusInternalServerError)
		return
	}
	audit(r, "player_items", req.PlayerID, map[string]interface{}{"action": req.Action, "kind": req.Kind, "item_id": req.ItemID})
	notifyAccountChanged(p.Username)
	jsonResponse(w, map[string]bool{"success": true})
}

// ------------------------------------------------------------ مسدودیت، چت، اخراج

// پشتیبانی حداکثر یک هفته مسدود می‌کند؛ دائمی فقط مدیر کامل
const supportMaxBanHours = 7 * 24

// POST /admin/api/player/ban {"player_id","reason","hours"} — hours=0 یعنی دائمی
func adminPlayerBanHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PlayerID string `json:"player_id"`
		Reason   string `json:"reason"`
		Hours    int    `json:"hours"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	req.Reason = strings.TrimSpace(req.Reason)
	if req.Reason == "" || req.Hours < 0 {
		httpError(w, "دلیل مسدودیت را بنویسید", http.StatusBadRequest)
		return
	}
	if adminFrom(r).Role != adminRoleAdmin && (req.Hours == 0 || req.Hours > supportMaxBanHours) {
		httpError(w, "پشتیبانی حداکثر ۷ روز می‌تواند مسدود کند", http.StatusForbidden)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	p, err := getPlayerByID(ctx, req.PlayerID)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	now := time.Now()
	set := bson.M{"is_banned": true, "ban_reason": req.Reason, "banned_at": now, "is_online": false}
	update := bson.M{"$set": set}
	if req.Hours > 0 {
		set["banned_until"] = now.Add(time.Duration(req.Hours) * time.Hour)
	} else {
		update["$unset"] = bson.M{"banned_until": ""}
	}
	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.PlayerID}, update); err != nil {
		httpError(w, "ذخیره نشد", http.StatusInternalServerError)
		return
	}
	kicked := kickFromHub(p.Username)
	audit(r, "player_ban", req.PlayerID, map[string]interface{}{"reason": req.Reason, "hours": req.Hours, "username": p.Username})
	jsonResponse(w, map[string]interface{}{"success": true, "kicked": kicked})
}

// POST /admin/api/player/unban {"player_id"}
func adminPlayerUnbanHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PlayerID string `json:"player_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	res, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.PlayerID}, bson.M{
		"$set":   bson.M{"is_banned": false},
		"$unset": bson.M{"ban_reason": "", "banned_at": "", "banned_until": ""},
	})
	if err != nil || res.MatchedCount == 0 {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	audit(r, "player_unban", req.PlayerID, nil)
	jsonResponse(w, map[string]bool{"success": true})
}

// POST /admin/api/player/mute {"player_id","hours","reason"} — hours=0 یعنی باز کردن چت
func adminPlayerMuteHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PlayerID string `json:"player_id"`
		Hours    int    `json:"hours"`
		Reason   string `json:"reason"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	if req.Hours < 0 || req.Hours > 24*365 {
		httpError(w, "مدت نامعتبر", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	update := bson.M{"$unset": bson.M{"chat_muted_until": ""}}
	if req.Hours > 0 {
		update = bson.M{"$set": bson.M{"chat_muted_until": time.Now().Add(time.Duration(req.Hours) * time.Hour)}}
	}
	res, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.PlayerID}, update)
	if err != nil || res.MatchedCount == 0 {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	audit(r, "player_mute", req.PlayerID, map[string]interface{}{"hours": req.Hours, "reason": req.Reason})
	jsonResponse(w, map[string]bool{"success": true})
}

// POST /admin/api/player/kick {"player_id"} — قطع اتصالِ زنده (مثلاً گیر کرده در راند)
func adminPlayerKickHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PlayerID string `json:"player_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	p, err := getPlayerByID(ctx, req.PlayerID)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	n := kickFromHub(p.Username)
	audit(r, "player_kick", req.PlayerID, map[string]interface{}{"connections": n})
	jsonResponse(w, map[string]interface{}{"success": true, "kicked": n})
}

// POST /admin/api/player/note {"player_id","text"} یا {"note_id","delete":true}
func adminPlayerNoteHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PlayerID string `json:"player_id"`
		Text     string `json:"text"`
		NoteID   string `json:"note_id"`
		Delete   bool   `json:"delete"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	if req.Delete {
		_, _ = col(ColAdminNotes).DeleteOne(ctx, bson.M{"_id": req.NoteID})
		audit(r, "note_delete", req.PlayerID, map[string]interface{}{"note_id": req.NoteID})
		jsonResponse(w, map[string]bool{"success": true})
		return
	}
	text := strings.TrimSpace(req.Text)
	if text == "" || len([]rune(text)) > 2000 {
		httpError(w, "متن یادداشت نامعتبر است", http.StatusBadRequest)
		return
	}
	note := bson.M{"_id": newID("note"), "player_id": req.PlayerID, "text": text, "by": adminFrom(r).User, "at": time.Now()}
	if _, err := col(ColAdminNotes).InsertOne(ctx, note); err != nil {
		httpError(w, "ذخیره نشد", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, map[string]interface{}{"success": true, "note": note})
}

// POST /admin/api/player/message/delete {"message_id"} — حذف یک پیام از صندوق بازیکن
func adminDeletePlayerMessageHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		MessageID string `json:"message_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	var msg MessageModel
	if err := col(ColMessages).FindOneAndDelete(ctx, bson.M{"message_id": req.MessageID}).Decode(&msg); err != nil {
		httpError(w, "پیام پیدا نشد", http.StatusNotFound)
		return
	}
	audit(r, "message_delete", msg.RecipientID, map[string]interface{}{"message_id": msg.MessageID, "title": msg.Title})
	jsonResponse(w, map[string]bool{"success": true})
}
