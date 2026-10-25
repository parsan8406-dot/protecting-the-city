package main

import (
	"context"
	"encoding/json"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// هندلرهای منوی «شهر» (کلن)
//
//   GET  /clans                 لیست شهرها برای عضویت (+ جستجو)
//   GET  /clan                  اطلاعات یک شهر + اعضای غنی‌شده
//   GET  /clan/requests         صف درخواست‌های عضویت (رهبر و معاون)
//   POST /clan/create           ساخت شهر
//   POST /clan/join             درخواست عضویت / عضویت مستقیم
//   POST /clan/leave            ترک شهر
//   POST /clan/respond          پذیرفتن یا رد درخواست عضویت
//   POST /clan/kick             اخراج عضو
//   POST /clan/role             تغییر نقش عضو (ارتقا / تنزل)
//   POST /clan/update           ویرایش پروفایل شهر (نام، تگ، نشان، ...) — فقط رهبر
//   POST /clan/transfer         سپردن رهبری به یک عضو دیگر — فقط رهبر
//
// نکته امنیتی: مثل بقیه‌ی اندپوینت‌ها فعلاً فقط `username` گرفته می‌شود و
// احراز هویت واقعی ندارد — همان کار باقی‌مانده‌ی شماره ۲ در DATA_MODEL.md.
// =============================================================================

// ============== توابع کمکی شهر ==============

// getClanByID شهر را با شناسه پیدا می‌کند
func getClanByID(ctx context.Context, clanID string) (*ClanModel, error) {
	var c ClanModel
	err := col(ColClans).FindOne(ctx, bson.M{"clan_id": clanID}).Decode(&c)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// clanMemberRole نقش یک بازیکن را داخل شهر برمی‌گرداند.
// رشته‌ی خالی یعنی عضو این شهر نیست.
func clanMemberRole(clan *ClanModel, playerID string) string {
	for _, m := range clan.Members {
		if m.PlayerID == playerID {
			return m.Role
		}
	}
	return ""
}

// enrichClanMembers اطلاعات زنده‌ی هر عضو (سطح، آواتار، آنلاین بودن، رتبه)
// را از کالکشن players می‌آورد. خودِ کالکشن clans فقط نام و نقش را نگه می‌دارد
// تا با تغییر نام یا سطح بازیکن قدیمی نشود.
//
// خروجی به همان ترتیبِ اهمیت نقش و سپس تاریخ عضویت مرتب می‌شود.
func enrichClanMembers(ctx context.Context, clan *ClanModel, viewer *PlayerModel) []map[string]interface{} {
	ids := make([]string, 0, len(clan.Members))
	for _, m := range clan.Members {
		ids = append(ids, m.PlayerID)
	}

	// یک کوئری برای همه‌ی اعضا
	live := map[string]PlayerModel{}
	if len(ids) > 0 {
		cursor, err := col(ColPlayers).Find(ctx, bson.M{"player_id": bson.M{"$in": ids}})
		if err == nil {
			defer cursor.Close(ctx)
			for cursor.Next(ctx) {
				var p PlayerModel
				if cursor.Decode(&p) == nil {
					live[p.PlayerID] = p
				}
			}
		}
	}

	// دوستان بیننده را در یک ست می‌ریزیم تا وضعیت دکمه‌ی «افزودن دوست» مشخص شود
	friendSet := map[string]bool{}
	viewerID := ""
	if viewer != nil {
		viewerID = viewer.PlayerID
		for _, f := range viewer.Friends {
			friendSet[f] = true
		}
	}

	// درخواست‌های دوستی باز از طرف بیننده، تا دکمه دوباره فعال نشود
	pendingSet := map[string]bool{}
	if viewerID != "" && len(ids) > 0 {
		cursor, err := col(ColFriendRequests).Find(ctx, bson.M{
			"from_id": viewerID,
			"to_id":   bson.M{"$in": ids},
			"status":  FriendReqPending,
		})
		if err == nil {
			defer cursor.Close(ctx)
			for cursor.Next(ctx) {
				var fr FriendRequestModel
				if cursor.Decode(&fr) == nil {
					pendingSet[fr.ToID] = true
				}
			}
		}
	}

	out := make([]map[string]interface{}, 0, len(clan.Members))
	for _, m := range clan.Members {
		row := map[string]interface{}{
			"player_id": m.PlayerID,
			"username":  m.Username,
			"role":      m.Role,
			"joined_at": m.JoinedAt,
			"is_me":     m.PlayerID == viewerID,
			"is_friend": friendSet[m.PlayerID],
			// درخواست دوستی از قبل فرستاده شده؟ دکمه باید غیرفعال بماند
			"friend_request_sent": pendingSet[m.PlayerID],
		}

		if p, ok := live[m.PlayerID]; ok {
			row["username"] = p.Username // نام تازه، اگر عوض شده باشد
			row["avatar_id"] = p.AvatarID
			row["frame_id"] = p.FrameID
			row["level"] = p.Level
			row["is_online"] = p.IsOnline
			row["last_seen_at"] = p.LastSeenAt
			row["tier_id"] = p.Rank.TierID
			row["tier_name"] = p.Rank.TierName
			row["trophies"] = p.Trophies
			row["kills"] = p.Stats.Kills
			row["wins"] = p.Stats.Wins
			row["total_matches"] = p.Stats.TotalMatches
		} else {
			// بازیکن حذف شده — ردیف را با مقادیر امن پر می‌کنیم
			row["avatar_id"] = ""
			row["level"] = 0
			row["is_online"] = false
			row["tier_id"] = ""
			row["tier_name"] = ""
			row["trophies"] = 0
		}

		out = append(out, row)
	}

	// رهبر بالا، بعد معاون‌ها، بعد اعضا؛ در هر گروه آنلاین‌ها جلوتر
	sortClanRows(out)
	return out
}

// sortClanRows مرتب‌سازی اعضا: نقش بالاتر اول، بعد آنلاین‌ها، بعد سطح بالاتر
func sortClanRows(rows []map[string]interface{}) {
	for i := 1; i < len(rows); i++ {
		for j := i; j > 0 && clanRowLess(rows[j], rows[j-1]); j-- {
			rows[j], rows[j-1] = rows[j-1], rows[j]
		}
	}
}

func clanRowLess(a, b map[string]interface{}) bool {
	ra := clanRoleRank(toString(a["role"]))
	rb := clanRoleRank(toString(b["role"]))
	if ra != rb {
		return ra > rb
	}
	oa, _ := a["is_online"].(bool)
	ob, _ := b["is_online"].(bool)
	if oa != ob {
		return oa
	}
	return toInt(a["level"]) > toInt(b["level"])
}

func toString(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func toInt(v interface{}) int {
	if i, ok := v.(int); ok {
		return i
	}
	return 0
}

// clanSummary نمای خلاصه‌ی شهر برای لیست مرور
func clanSummary(c *ClanModel) map[string]interface{} {
	return map[string]interface{}{
		"clan_id":      c.ClanID,
		"name":         c.Name,
		"tag":          c.Tag,
		"description":  c.Description,
		"icon_path":    c.IconPath,
		"level":        c.Level,
		"experience":   c.Experience,
		"member_count": c.MemberCount(),
		"max_members":  c.MaxMembers,
		"is_public":    c.IsPublic,
		"min_level":    c.MinLevel,
		"is_full":      c.MemberCount() >= c.MaxMembers,
		"owner_id":     c.OwnerID,
		"created_at":   c.CreatedAt,
	}
}

// syncClanMemberCount شمار اعضا را روی رکورد بازیکنان همگام نگه نمی‌دارد،
// بلکه فقط clan_id/clan_role خود بازیکن را ست یا پاک می‌کند.
func setPlayerClan(ctx context.Context, playerID, clanID, role string) error {
	_, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": playerID},
		bson.M{"$set": bson.M{
			"clan_id":    clanID,
			"clan_role":  role,
			"updated_at": time.Now(),
		}})
	return err
}

// clanIconPattern شکل مجاز نشان شهر: "emblem:<نماد>:<رنگ>" (city_emblem.gd).
// هر چیز دیگری (مثلاً یک مسیر res:// دلخواه) رد می‌شود.
var clanIconPattern = regexp.MustCompile(`^emblem:[0-9]{1,2}:[0-9]{1,2}$`)

// validClanIcon نشان خالی (پیش‌فرض) یا هم‌شکل clanIconPattern
func validClanIcon(icon string) bool {
	return icon == "" || clanIconPattern.MatchString(icon)
}

// clanWorldRank جایگاه شهر در رتبه‌بندی کل شهرها (۱ = بهترین).
// همان ترتیب تب «شهرها» در صفحه‌ی رتبه بندی است: مجموع کاپ اعضا
// (handlers_leaderboard.go → cityStanding).
func clanWorldRank(ctx context.Context, c *ClanModel) int {
	position, _ := cityStanding(ctx, c.ClanID)
	return position
}

// clanLeaderInfo نام رهبر و تعداد معاون‌ها برای کارت «اطلاعات شهر»
func clanLeaderInfo(c *ClanModel) (string, int) {
	leader := ""
	officers := 0
	for _, m := range c.Members {
		switch m.Role {
		case ClanRoleLeader:
			leader = m.Username
		case ClanRoleOfficer:
			officers++
		}
	}
	return leader, officers
}

// notifyClanChanged به همه‌ی اعضا خبر می‌دهد صفحه‌ی شهرشان را تازه کنند
func notifyClanChanged(c *ClanModel) {
	for _, m := range c.Members {
		NotifyUser(m.Username, map[string]interface{}{
			"type": "notification",
			"kind": "clan_changed",
		})
	}
}

// ============== ۱. لیست شهرها برای عضویت ==============

// getClansHandler لیست شهرهایی که می‌شود در آنها عضو شد
// GET /clans?username=<me>&search=<name|tag>&page=0
func getClansHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 6*time.Second)
	defer cancel()

	search := strings.TrimSpace(r.URL.Query().Get("search"))
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 0 {
		page = 0
	}

	filter := bson.M{}
	if search != "" {
		// جستجوی ساده روی نام و تگ — بدون حساسیت به بزرگی و کوچکی حروف
		safe := regexEscape(search)
		filter["$or"] = []bson.M{
			{"name": bson.M{"$regex": safe, "$options": "i"}},
			{"tag": bson.M{"$regex": safe, "$options": "i"}},
		}
	}

	opts := options.Find().
		SetSort(bson.D{{Key: "level", Value: -1}, {Key: "experience", Value: -1}}).
		SetSkip(int64(page * ClanBrowsePageSize)).
		SetLimit(int64(ClanBrowsePageSize))

	cursor, err := col(ColClans).Find(ctx, filter, opts)
	if err != nil {
		httpError(w, "خطا در گرفتن لیست شهرها", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	clans := []map[string]interface{}{}
	for cursor.Next(ctx) {
		var c ClanModel
		if cursor.Decode(&c) != nil {
			continue
		}
		clans = append(clans, clanSummary(&c))
	}

	// اگر بیننده مشخص است، بگو خودش الان کجاست تا کلاینت دکمه‌ها را درست بچیند
	response := map[string]interface{}{
		"clans": clans,
		"page":  page,
	}

	if username := r.URL.Query().Get("username"); username != "" {
		if me, err := getPlayerByUsername(ctx, username); err == nil {
			response["player_id"] = me.PlayerID
			response["my_clan_id"] = me.ClanID
			response["my_level"] = me.Level
			response["my_coins"] = me.Coins
			response["create_cost"] = ClanCreateCost

			// درخواست‌های بازِ خودم، تا دکمه‌ی «درخواست فرستاده شد» نشان داده شود
			pending := []string{}
			cur, err := col(ColClanRequests).Find(ctx, bson.M{
				"from_id": me.PlayerID,
				"status":  ClanReqPending,
			})
			if err == nil {
				defer cur.Close(ctx)
				for cur.Next(ctx) {
					var req ClanJoinRequestModel
					if cur.Decode(&req) == nil {
						pending = append(pending, req.ClanID)
					}
				}
			}
			response["my_pending_clan_ids"] = pending
		}
	}

	jsonResponse(w, response)
}

// regexEscape کاراکترهای ویژه‌ی regex را خنثی می‌کند تا جستجوی کاربر
// نتواند الگوی سنگین یا مخرب به دیتابیس بدهد.
func regexEscape(s string) string {
	var b strings.Builder
	for _, r := range s {
		if strings.ContainsRune(`\.+*?()|[]{}^$`, r) {
			b.WriteRune('\\')
		}
		b.WriteRune(r)
	}
	return b.String()
}

// ============== ۲. ساخت شهر ==============

// createClanHandler ساخت شهر جدید (دکمه‌ی «ایجاد شهر»)
// POST /clan/create
func createClanHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanCreateBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	if me.ClanID != "" {
		httpError(w, "اول باید شهر فعلی‌ات را ترک کنی", http.StatusConflict)
		return
	}

	name := strings.TrimSpace(req.Name)
	tag := strings.ToUpper(strings.TrimSpace(req.Tag))
	desc := strings.TrimSpace(req.Description)

	if n := len([]rune(name)); n < ClanMinNameLen || n > ClanMaxNameLen {
		httpError(w, "نام شهر باید بین ۳ تا ۱۸ کاراکتر باشد", http.StatusBadRequest)
		return
	}
	if n := len([]rune(tag)); n < ClanMinTagLen || n > ClanMaxTagLen {
		httpError(w, "تگ شهر باید بین ۲ تا ۵ کاراکتر باشد", http.StatusBadRequest)
		return
	}
	if len([]rune(desc)) > ClanMaxDescLen {
		httpError(w, "توضیحات شهر بیش از حد طولانی است", http.StatusBadRequest)
		return
	}
	if me.Coins < ClanCreateCost {
		httpError(w, "سکه‌ات برای ساخت شهر کافی نیست", http.StatusPaymentRequired)
		return
	}

	if !validClanIcon(req.IconPath) {
		httpError(w, "نشان شهر نامعتبر است", http.StatusBadRequest)
		return
	}

	minLevel := req.MinLevel
	if minLevel < 0 {
		minLevel = 0
	}
	if minLevel > ClanMaxMinLevel {
		minLevel = ClanMaxMinLevel
	}

	now := time.Now()
	clan := ClanModel{
		ClanID:      newID("clan"),
		Name:        name,
		Tag:         tag,
		Description: desc,
		IconPath:    req.IconPath,
		Level:       1,
		Experience:  0,
		MaxMembers:  ClanDefaultMaxMem,
		OwnerID:     me.PlayerID,
		IsPublic:    req.IsPublic,
		MinLevel:    minLevel,
		CreatedAt:   now,
		Members: []ClanMember{{
			PlayerID: me.PlayerID,
			Username: me.Username,
			Role:     ClanRoleLeader,
			JoinedAt: now,
		}},
	}

	if _, err := col(ColClans).InsertOne(ctx, clan); err != nil {
		if mongo.IsDuplicateKeyError(err) {
			httpError(w, "شهری با این نام از قبل وجود دارد", http.StatusConflict)
			return
		}
		httpError(w, "خطا در ساخت شهر", http.StatusInternalServerError)
		return
	}

	// هزینه را کم و بازیکن را رهبر شهر می‌کنیم.
	// شرط coins روی همین آپدیت گذاشته شده تا دو درخواست هم‌زمان نتوانند
	// دو بار از یک موجودی خرج کنند.
	res, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": me.PlayerID, "coins": bson.M{"$gte": ClanCreateCost}},
		bson.M{
			"$inc": bson.M{"coins": -ClanCreateCost},
			"$set": bson.M{
				"clan_id":    clan.ClanID,
				"clan_role":  ClanRoleLeader,
				"updated_at": now,
			},
		})
	if err != nil || res.ModifiedCount == 0 {
		// پرداخت نشد — شهر نیمه‌ساخته را پس می‌گیریم تا رکورد یتیم نماند
		_, _ = col(ColClans).DeleteOne(ctx, bson.M{"clan_id": clan.ClanID})
		httpError(w, "سکه‌ات برای ساخت شهر کافی نیست", http.StatusPaymentRequired)
		return
	}

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"clan":    clanSummary(&clan),
		"coins":   me.Coins - ClanCreateCost,
	})
}

// ============== ۳. عضویت و ترک ==============

// joinClanHandler درخواست عضویت در شهر
// POST /clan/join  {"username":"...","clan_id":"..."}
//
// شهر عمومی: بازیکن بدون واسطه عضو می‌شود.
// شهر خصوصی: یک درخواست در clan_requests ثبت و به رهبر خبر داده می‌شود.
func joinClanHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanJoinBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if me.ClanID != "" {
		httpError(w, "تو الان عضو یک شهر هستی", http.StatusConflict)
		return
	}

	clan, err := getClanByID(ctx, req.ClanID)
	if err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}
	if clan.MemberCount() >= clan.MaxMembers {
		httpError(w, "ظرفیت این شهر پر است", http.StatusConflict)
		return
	}
	if me.Level < clan.MinLevel {
		httpError(w, "سطح تو برای عضویت در این شهر کافی نیست", http.StatusForbidden)
		return
	}

	now := time.Now()

	// --- شهر خصوصی: فقط درخواست ثبت می‌شود ---
	if !clan.IsPublic {
		joinReq := ClanJoinRequestModel{
			RequestID:    newID("creq"),
			ClanID:       clan.ClanID,
			ClanName:     clan.Name,
			FromID:       me.PlayerID,
			FromUsername: me.Username,
			FromLevel:    me.Level,
			FromAvatarID: me.AvatarID,
			Status:       ClanReqPending,
			CreatedAt:    now,
		}

		if _, err := col(ColClanRequests).InsertOne(ctx, joinReq); err != nil {
			if mongo.IsDuplicateKeyError(err) {
				httpError(w, "درخواست تو قبلاً فرستاده شده", http.StatusConflict)
				return
			}
			httpError(w, "خطا در ثبت درخواست", http.StatusInternalServerError)
			return
		}

		// خبر دادن به رهبر و معاون‌ها
		for _, m := range clan.Members {
			if clanRoleRank(m.Role) < clanRoleRank(ClanRoleOfficer) {
				continue
			}
			_ = insertMessage(ctx, MessageModel{
				RecipientID: m.PlayerID,
				SenderID:    me.PlayerID,
				SenderName:  me.Username,
				Type:        MsgTypeSystem,
				Title:       "درخواست عضویت در شهر",
				Body:        me.Username + " می‌خواهد به شهر " + clan.Name + " بپیوندد",
				RefID:       joinReq.RequestID,
			})
			NotifyUser(m.Username, map[string]interface{}{
				"type": "notification",
				"kind": "clan_request",
				"from": me.Username,
			})
		}

		jsonResponse(w, map[string]interface{}{
			"success":    true,
			"pending":    true,
			"request_id": joinReq.RequestID,
			"message":    "درخواست عضویت فرستاده شد",
		})
		return
	}

	// --- شهر عمومی: عضویت مستقیم ---
	// شرط $size روی همین آپدیت است تا دو نفر هم‌زمان از ظرفیت آخر رد نشوند.
	res, err := col(ColClans).UpdateOne(ctx,
		bson.M{
			"clan_id":           clan.ClanID,
			"members.player_id": bson.M{"$ne": me.PlayerID},
			"$expr":             bson.M{"$lt": []interface{}{bson.M{"$size": "$members"}, "$max_members"}},
		},
		bson.M{"$push": bson.M{"members": ClanMember{
			PlayerID: me.PlayerID,
			Username: me.Username,
			Role:     ClanRoleMember,
			JoinedAt: now,
		}}})
	if err != nil || res.ModifiedCount == 0 {
		httpError(w, "ظرفیت این شهر پر است", http.StatusConflict)
		return
	}

	if err := setPlayerClan(ctx, me.PlayerID, clan.ClanID, ClanRoleMember); err != nil {
		// عضویت روی شهر ثبت شد ولی روی بازیکن نه — برش می‌گردانیم
		_, _ = col(ColClans).UpdateOne(ctx,
			bson.M{"clan_id": clan.ClanID},
			bson.M{"$pull": bson.M{"members": bson.M{"player_id": me.PlayerID}}})
		httpError(w, "خطا در ثبت عضویت", http.StatusInternalServerError)
		return
	}

	// به اعضای شهر خبر بده
	for _, m := range clan.Members {
		NotifyUser(m.Username, map[string]interface{}{
			"type": "notification",
			"kind": "clan_changed",
		})
	}

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"pending": false,
		"clan_id": clan.ClanID,
		"message": "به شهر " + clan.Name + " خوش آمدی",
	})
}

// leaveClanHandler ترک شهر
// POST /clan/leave  {"username":"..."}
//
// اگر رهبر برود و کسی مانده باشد، رهبری به قدیمی‌ترین معاون (یا قدیمی‌ترین
// عضو) منتقل می‌شود. اگر آخرین نفر باشد، خودِ شهر حذف می‌شود.
func leaveClanHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanJoinBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if me.ClanID == "" {
		httpError(w, "تو عضو هیچ شهری نیستی", http.StatusBadRequest)
		return
	}

	clan, err := getClanByID(ctx, me.ClanID)
	if err != nil {
		// شهر از بین رفته ولی بازیکن هنوز به آن اشاره دارد — پاکش می‌کنیم
		_ = setPlayerClan(ctx, me.PlayerID, "", "")
		jsonResponse(w, map[string]interface{}{"success": true, "message": "از شهر خارج شدی"})
		return
	}

	myRole := clanMemberRole(clan, me.PlayerID)

	// رکورد بازیکن به این شهر اشاره می‌کند ولی اسمش در لیست اعضا نیست.
	// فقط اشاره‌ی خرابِ خودش را پاک می‌کنیم — به شهر دست نمی‌زنیم، وگرنه
	// یک رکورد ناهماهنگ می‌توانست شهر دیگران را منحل کند.
	if myRole == "" {
		_ = setPlayerClan(ctx, me.PlayerID, "", "")
		jsonResponse(w, map[string]interface{}{"success": true, "message": "از شهر خارج شدی"})
		return
	}

	// آخرین نفر — شهر منحل می‌شود
	if clan.MemberCount() <= 1 {
		_, _ = col(ColClans).DeleteOne(ctx, bson.M{"clan_id": clan.ClanID})
		_, _ = col(ColClanRequests).DeleteMany(ctx, bson.M{"clan_id": clan.ClanID})
		_ = setPlayerClan(ctx, me.PlayerID, "", "")
		jsonResponse(w, map[string]interface{}{
			"success":   true,
			"dissolved": true,
			"message":   "شهر " + clan.Name + " منحل شد",
		})
		return
	}

	// حذف از لیست اعضا
	if _, err := col(ColClans).UpdateOne(ctx,
		bson.M{"clan_id": clan.ClanID},
		bson.M{"$pull": bson.M{"members": bson.M{"player_id": me.PlayerID}}}); err != nil {
		httpError(w, "خطا در ترک شهر", http.StatusInternalServerError)
		return
	}
	_ = setPlayerClan(ctx, me.PlayerID, "", "")

	// اگر رهبر رفت، جانشین تعیین کن
	successor := ""
	if myRole == ClanRoleLeader {
		successor = promoteSuccessor(ctx, clan, me.PlayerID)
	}

	for _, m := range clan.Members {
		if m.PlayerID == me.PlayerID {
			continue
		}
		NotifyUser(m.Username, map[string]interface{}{
			"type": "notification",
			"kind": "clan_changed",
		})
	}

	jsonResponse(w, map[string]interface{}{
		"success":    true,
		"message":    "از شهر " + clan.Name + " خارج شدی",
		"new_leader": successor,
	})
}

// promoteSuccessor بعد از رفتن رهبر، قدیمی‌ترین معاون را رهبر می‌کند؛
// اگر معاونی نبود، قدیمی‌ترین عضو را. نام رهبر جدید را برمی‌گرداند.
func promoteSuccessor(ctx context.Context, clan *ClanModel, leavingID string) string {
	var best *ClanMember
	for i := range clan.Members {
		m := &clan.Members[i]
		if m.PlayerID == leavingID {
			continue
		}
		if best == nil {
			best = m
			continue
		}
		br := clanRoleRank(best.Role)
		mr := clanRoleRank(m.Role)
		if mr > br || (mr == br && m.JoinedAt.Before(best.JoinedAt)) {
			best = m
		}
	}
	if best == nil {
		return ""
	}

	now := time.Now()
	_, _ = col(ColClans).UpdateOne(ctx,
		bson.M{"clan_id": clan.ClanID, "members.player_id": best.PlayerID},
		bson.M{"$set": bson.M{
			"members.$.role": ClanRoleLeader,
			"owner_id":       best.PlayerID,
		}})
	_ = setPlayerClan(ctx, best.PlayerID, clan.ClanID, ClanRoleLeader)

	_ = insertMessage(ctx, MessageModel{
		RecipientID: best.PlayerID,
		SenderID:    "system",
		SenderName:  "بازی",
		Type:        MsgTypeSystem,
		Title:       "رهبری شهر",
		Body:        "رهبر قبلی شهر " + clan.Name + " را ترک کرد — حالا تو رهبر این شهری",
		CreatedAt:   now,
	})
	NotifyUser(best.Username, map[string]interface{}{
		"type": "notification",
		"kind": "clan_changed",
	})

	return best.Username
}

// ============== ۴. صف درخواست‌های عضویت ==============

// getClanRequestsHandler درخواست‌های بازِ عضویت در شهرِ من
// GET /clan/requests?username=<me>
func getClanRequestsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 6*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, r.URL.Query().Get("username"))
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if me.ClanID == "" {
		jsonResponse(w, map[string]interface{}{"requests": []interface{}{}, "can_manage": false})
		return
	}

	clan, err := getClanByID(ctx, me.ClanID)
	if err != nil {
		jsonResponse(w, map[string]interface{}{"requests": []interface{}{}, "can_manage": false})
		return
	}

	// فقط رهبر و معاون صف را می‌بینند
	canManage := clanRoleRank(clanMemberRole(clan, me.PlayerID)) >= clanRoleRank(ClanRoleOfficer)
	if !canManage {
		jsonResponse(w, map[string]interface{}{"requests": []interface{}{}, "can_manage": false})
		return
	}

	cursor, err := col(ColClanRequests).Find(ctx,
		bson.M{"clan_id": clan.ClanID, "status": ClanReqPending},
		options.Find().SetSort(bson.D{{Key: "created_at", Value: 1}}))
	if err != nil {
		httpError(w, "خطا در گرفتن درخواست‌ها", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	requests := []ClanJoinRequestModel{}
	for cursor.Next(ctx) {
		var req ClanJoinRequestModel
		if cursor.Decode(&req) == nil {
			requests = append(requests, req)
		}
	}

	jsonResponse(w, map[string]interface{}{
		"requests":   requests,
		"can_manage": true,
		"clan_id":    clan.ClanID,
	})
}

// respondClanRequestHandler پذیرفتن یا رد درخواست عضویت
// POST /clan/respond  {"username":"...","request_id":"...","accept":true}
func respondClanRequestHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanRespondBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	var joinReq ClanJoinRequestModel
	err = col(ColClanRequests).FindOne(ctx, bson.M{
		"request_id": req.RequestID,
		"status":     ClanReqPending,
	}).Decode(&joinReq)
	if err != nil {
		httpError(w, "درخواست پیدا نشد", http.StatusNotFound)
		return
	}

	clan, err := getClanByID(ctx, joinReq.ClanID)
	if err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}
	if clanRoleRank(clanMemberRole(clan, me.PlayerID)) < clanRoleRank(ClanRoleOfficer) {
		httpError(w, "اختیار پاسخ به این درخواست را نداری", http.StatusForbidden)
		return
	}

	now := time.Now()
	status := ClanReqRejected
	if req.Accept {
		status = ClanReqAccepted
	}

	if req.Accept {
		// در این فاصله ممکن است متقاضی جای دیگری عضو شده باشد
		applicant, err := getPlayerByID(ctx, joinReq.FromID)
		if err != nil {
			httpError(w, "متقاضی پیدا نشد", http.StatusNotFound)
			return
		}
		if applicant.ClanID != "" {
			_, _ = col(ColClanRequests).UpdateOne(ctx,
				bson.M{"request_id": joinReq.RequestID},
				bson.M{"$set": bson.M{"status": ClanReqRejected, "responded_at": now}})
			httpError(w, "این بازیکن الان عضو شهر دیگری است", http.StatusConflict)
			return
		}

		res, err := col(ColClans).UpdateOne(ctx,
			bson.M{
				"clan_id":           clan.ClanID,
				"members.player_id": bson.M{"$ne": applicant.PlayerID},
				"$expr":             bson.M{"$lt": []interface{}{bson.M{"$size": "$members"}, "$max_members"}},
			},
			bson.M{"$push": bson.M{"members": ClanMember{
				PlayerID: applicant.PlayerID,
				Username: applicant.Username,
				Role:     ClanRoleMember,
				JoinedAt: now,
			}}})
		if err != nil || res.ModifiedCount == 0 {
			httpError(w, "ظرفیت شهر پر است", http.StatusConflict)
			return
		}

		if err := setPlayerClan(ctx, applicant.PlayerID, clan.ClanID, ClanRoleMember); err != nil {
			_, _ = col(ColClans).UpdateOne(ctx,
				bson.M{"clan_id": clan.ClanID},
				bson.M{"$pull": bson.M{"members": bson.M{"player_id": applicant.PlayerID}}})
			httpError(w, "خطا در ثبت عضویت", http.StatusInternalServerError)
			return
		}
	}

	_, _ = col(ColClanRequests).UpdateOne(ctx,
		bson.M{"request_id": joinReq.RequestID},
		bson.M{"$set": bson.M{"status": status, "responded_at": now}})

	// پیام‌های «درخواست عضویت» که برای مدیران ساخته شده بود دیگر لازم نیست
	_, _ = col(ColMessages).DeleteMany(ctx, bson.M{"ref_id": joinReq.RequestID})

	// خبر به متقاضی
	title := "درخواست عضویت رد شد"
	body := "درخواست عضویت تو در شهر " + clan.Name + " پذیرفته نشد"
	if req.Accept {
		title = "به شهر خوش آمدی"
		body = "درخواست عضویت تو در شهر " + clan.Name + " پذیرفته شد"
	}
	_ = insertMessage(ctx, MessageModel{
		RecipientID: joinReq.FromID,
		SenderID:    "system",
		SenderName:  "بازی",
		Type:        MsgTypeSystem,
		Title:       title,
		Body:        body,
	})
	NotifyUser(joinReq.FromUsername, map[string]interface{}{
		"type": "notification",
		"kind": "clan_changed",
	})

	jsonResponse(w, map[string]interface{}{"success": true, "status": status})
}

// ============== ۵. مدیریت اعضا ==============

// kickClanMemberHandler اخراج عضو از شهر
// POST /clan/kick  {"username":"...","target_id":"..."}
func kickClanMemberHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanMemberActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, clan, myRole, ok := requireClanAuthority(ctx, w, req.Username, ClanRoleOfficer)
	if !ok {
		return
	}

	if req.TargetID == me.PlayerID {
		httpError(w, "برای رفتن از شهر از دکمه‌ی ترک استفاده کن", http.StatusBadRequest)
		return
	}

	targetRole := clanMemberRole(clan, req.TargetID)
	if targetRole == "" {
		httpError(w, "این بازیکن عضو شهر تو نیست", http.StatusNotFound)
		return
	}
	// فقط می‌شود کسی را اخراج کرد که نقشش پایین‌تر است
	if clanRoleRank(targetRole) >= clanRoleRank(myRole) {
		httpError(w, "اختیار اخراج این عضو را نداری", http.StatusForbidden)
		return
	}

	if _, err := col(ColClans).UpdateOne(ctx,
		bson.M{"clan_id": clan.ClanID},
		bson.M{"$pull": bson.M{"members": bson.M{"player_id": req.TargetID}}}); err != nil {
		httpError(w, "خطا در اخراج عضو", http.StatusInternalServerError)
		return
	}
	_ = setPlayerClan(ctx, req.TargetID, "", "")

	targetName := ""
	for _, m := range clan.Members {
		if m.PlayerID == req.TargetID {
			targetName = m.Username
			break
		}
	}

	_ = insertMessage(ctx, MessageModel{
		RecipientID: req.TargetID,
		SenderID:    "system",
		SenderName:  "بازی",
		Type:        MsgTypeSystem,
		Title:       "اخراج از شهر",
		Body:        "تو از شهر " + clan.Name + " اخراج شدی",
	})
	if targetName != "" {
		NotifyUser(targetName, map[string]interface{}{
			"type": "notification",
			"kind": "clan_changed",
		})
	}
	for _, m := range clan.Members {
		NotifyUser(m.Username, map[string]interface{}{
			"type": "notification",
			"kind": "clan_changed",
		})
	}

	jsonResponse(w, map[string]interface{}{"success": true, "message": "عضو اخراج شد"})
}

// setClanRoleHandler تغییر نقش عضو (ارتقا به معاون / تنزل به عضو)
// POST /clan/role  {"username":"...","target_id":"...","role":"officer"}
//
// فقط رهبر می‌تواند نقش عوض کند، و نقش «رهبر» از این مسیر داده نمی‌شود.
func setClanRoleHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanMemberActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	if req.Role != ClanRoleOfficer && req.Role != ClanRoleMember {
		httpError(w, "نقش نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	_, clan, _, ok := requireClanAuthority(ctx, w, req.Username, ClanRoleLeader)
	if !ok {
		return
	}

	targetRole := clanMemberRole(clan, req.TargetID)
	if targetRole == "" {
		httpError(w, "این بازیکن عضو شهر تو نیست", http.StatusNotFound)
		return
	}
	if targetRole == ClanRoleLeader {
		httpError(w, "نقش رهبر از این مسیر عوض نمی‌شود", http.StatusBadRequest)
		return
	}

	if _, err := col(ColClans).UpdateOne(ctx,
		bson.M{"clan_id": clan.ClanID, "members.player_id": req.TargetID},
		bson.M{"$set": bson.M{"members.$.role": req.Role}}); err != nil {
		httpError(w, "خطا در تغییر نقش", http.StatusInternalServerError)
		return
	}
	_ = setPlayerClan(ctx, req.TargetID, clan.ClanID, req.Role)

	for _, m := range clan.Members {
		if m.PlayerID == req.TargetID {
			label := "معاون شهر"
			if req.Role == ClanRoleMember {
				label = "عضو عادی"
			}
			_ = insertMessage(ctx, MessageModel{
				RecipientID: req.TargetID,
				SenderID:    "system",
				SenderName:  "بازی",
				Type:        MsgTypeSystem,
				Title:       "تغییر نقش در شهر",
				Body:        "نقش تو در شهر " + clan.Name + " حالا " + label + " است",
			})
		}
		NotifyUser(m.Username, map[string]interface{}{
			"type": "notification",
			"kind": "clan_changed",
		})
	}

	jsonResponse(w, map[string]interface{}{"success": true, "role": req.Role})
}

// ============== ۶. پروفایل و رهبری شهر ==============

// updateClanHandler ویرایش پروفایل شهر (دیالوگ «ویرایش شهر»)
// POST /clan/update  {"username","name","tag","description","icon_path","is_public","min_level"}
//
// فقط رهبر. فیلدهای نیامده دست نمی‌خورند. عوض کردن نام یا تگ ClanRenameCost
// سکه خرج دارد؛ بقیه‌ی تغییرات رایگان است.
func updateClanHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanUpdateBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, clan, _, ok := requireClanAuthority(ctx, w, req.Username, ClanRoleLeader)
	if !ok {
		return
	}

	set := bson.M{}
	renamed := false

	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if name != clan.Name {
			if n := len([]rune(name)); n < ClanMinNameLen || n > ClanMaxNameLen {
				httpError(w, "نام شهر باید بین ۳ تا ۱۸ کاراکتر باشد", http.StatusBadRequest)
				return
			}
			set["name"] = name
			renamed = true
		}
	}
	if req.Tag != nil {
		tag := strings.ToUpper(strings.TrimSpace(*req.Tag))
		if tag != clan.Tag {
			if n := len([]rune(tag)); n < ClanMinTagLen || n > ClanMaxTagLen {
				httpError(w, "تگ شهر باید بین ۲ تا ۵ کاراکتر باشد", http.StatusBadRequest)
				return
			}
			set["tag"] = tag
			renamed = true
		}
	}
	if req.Description != nil {
		desc := strings.TrimSpace(*req.Description)
		if len([]rune(desc)) > ClanMaxDescLen {
			httpError(w, "توضیحات شهر بیش از حد طولانی است", http.StatusBadRequest)
			return
		}
		if desc != clan.Description {
			set["description"] = desc
		}
	}
	if req.IconPath != nil && *req.IconPath != clan.IconPath {
		if !validClanIcon(*req.IconPath) {
			httpError(w, "نشان شهر نامعتبر است", http.StatusBadRequest)
			return
		}
		set["icon_path"] = *req.IconPath
	}
	if req.IsPublic != nil && *req.IsPublic != clan.IsPublic {
		set["is_public"] = *req.IsPublic
	}
	if req.MinLevel != nil {
		minLevel := *req.MinLevel
		if minLevel < 0 {
			minLevel = 0
		}
		if minLevel > ClanMaxMinLevel {
			minLevel = ClanMaxMinLevel
		}
		if minLevel != clan.MinLevel {
			set["min_level"] = minLevel
		}
	}

	if len(set) == 0 {
		jsonResponse(w, map[string]interface{}{"success": true, "message": "تغییری ثبت نشد", "coins": me.Coins})
		return
	}

	// هزینه‌ی تغییر نام اول کم می‌شود — شرط coins روی همین آپدیت است تا دو
	// درخواست هم‌زمان نتوانند دو بار از یک موجودی خرج کنند.
	coins := me.Coins
	if renamed {
		res, err := col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": me.PlayerID, "coins": bson.M{"$gte": ClanRenameCost}},
			bson.M{"$inc": bson.M{"coins": -ClanRenameCost}})
		if err != nil || res.ModifiedCount == 0 {
			httpError(w, "سکه‌ات برای تغییر نام شهر کافی نیست", http.StatusPaymentRequired)
			return
		}
		coins -= ClanRenameCost
	}

	refund := func() {
		if renamed {
			_, _ = col(ColPlayers).UpdateOne(ctx,
				bson.M{"player_id": me.PlayerID},
				bson.M{"$inc": bson.M{"coins": ClanRenameCost}})
		}
	}

	if _, err := col(ColClans).UpdateOne(ctx, bson.M{"clan_id": clan.ClanID}, bson.M{"$set": set}); err != nil {
		refund()
		if mongo.IsDuplicateKeyError(err) {
			httpError(w, "شهری با این نام از قبل وجود دارد", http.StatusConflict)
			return
		}
		httpError(w, "خطا در ذخیره‌ی تغییرات شهر", http.StatusInternalServerError)
		return
	}

	// نام شهر روی درخواست‌های باز هم کپی شده — هم‌نامشان می‌کنیم
	if name, ok := set["name"].(string); ok {
		_, _ = col(ColClanRequests).UpdateMany(ctx,
			bson.M{"clan_id": clan.ClanID, "status": ClanReqPending},
			bson.M{"$set": bson.M{"clan_name": name}})
	}

	notifyClanChanged(clan)

	updated, err := getClanByID(ctx, clan.ClanID)
	if err != nil {
		updated = clan
	}
	jsonResponse(w, map[string]interface{}{
		"success": true,
		"message": "تغییرات شهر ذخیره شد",
		"clan":    clanSummary(updated),
		"coins":   coins,
	})
}

// transferClanLeaderHandler سپردن رهبری به یک عضو دیگر
// POST /clan/transfer  {"username":"...","target_id":"..."}
//
// عضو هدف رهبر می‌شود و رهبر فعلی معاون.
func transferClanLeaderHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req ClanMemberActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	me, clan, _, ok := requireClanAuthority(ctx, w, req.Username, ClanRoleLeader)
	if !ok {
		return
	}
	if req.TargetID == me.PlayerID {
		httpError(w, "تو همین الان رهبر شهری", http.StatusBadRequest)
		return
	}

	targetName := ""
	for _, m := range clan.Members {
		if m.PlayerID == req.TargetID {
			targetName = m.Username
			break
		}
	}
	if targetName == "" {
		httpError(w, "این بازیکن عضو شهر تو نیست", http.StatusNotFound)
		return
	}

	// اول رهبر جدید، بعد تنزل رهبر قبلی — اگر وسط کار خطا بخورد شهر
	// بی‌رهبر نمی‌ماند (بدترین حالت: دو رهبر، که رهبر قبلی با ترک یا
	// دوباره انتقال درستش می‌کند).
	if _, err := col(ColClans).UpdateOne(ctx,
		bson.M{"clan_id": clan.ClanID, "members.player_id": req.TargetID},
		bson.M{"$set": bson.M{"members.$.role": ClanRoleLeader, "owner_id": req.TargetID}}); err != nil {
		httpError(w, "خطا در انتقال رهبری", http.StatusInternalServerError)
		return
	}
	_, _ = col(ColClans).UpdateOne(ctx,
		bson.M{"clan_id": clan.ClanID, "members.player_id": me.PlayerID},
		bson.M{"$set": bson.M{"members.$.role": ClanRoleOfficer}})

	_ = setPlayerClan(ctx, req.TargetID, clan.ClanID, ClanRoleLeader)
	_ = setPlayerClan(ctx, me.PlayerID, clan.ClanID, ClanRoleOfficer)

	_ = insertMessage(ctx, MessageModel{
		RecipientID: req.TargetID,
		SenderID:    "system",
		SenderName:  "بازی",
		Type:        MsgTypeSystem,
		Title:       "رهبری شهر",
		Body:        me.Username + " رهبری شهر " + clan.Name + " را به تو سپرد",
	})
	notifyClanChanged(clan)

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"message": "رهبری شهر به " + targetName + " سپرده شد",
	})
}

// requireClanAuthority بازیکن، شهرش و نقشش را می‌آورد و مطمئن می‌شود
// نقش او دست‌کم به اندازه‌ی minRole اختیار دارد. اگر نه، خودش پاسخ خطا
// را می‌نویسد و ok=false برمی‌گرداند.
func requireClanAuthority(ctx context.Context, w http.ResponseWriter, username, minRole string) (*PlayerModel, *ClanModel, string, bool) {
	me, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return nil, nil, "", false
	}
	if me.ClanID == "" {
		httpError(w, "تو عضو هیچ شهری نیستی", http.StatusBadRequest)
		return nil, nil, "", false
	}
	clan, err := getClanByID(ctx, me.ClanID)
	if err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return nil, nil, "", false
	}
	myRole := clanMemberRole(clan, me.PlayerID)
	if clanRoleRank(myRole) < clanRoleRank(minRole) {
		httpError(w, "اختیار انجام این کار را نداری", http.StatusForbidden)
		return nil, nil, "", false
	}
	return me, clan, myRole, true
}
