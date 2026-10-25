package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// هندلرهای پروفایل، دوستان، پیام‌ها، رتبه‌بندی و شهر
// (منطبق بر منوهای: پروفایل / دوستان / پیام ها / رتبه بندی)
// =============================================================================

// ============== توابع کمکی مشترک ==============

// getPlayerByUsername بازیکن را با نام کاربری پیدا می‌کند
func getPlayerByUsername(ctx context.Context, username string) (*PlayerModel, error) {
	var p PlayerModel
	err := col(ColPlayers).FindOne(ctx, bson.M{"username": username}).Decode(&p)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// getPlayerByID بازیکن را با آیدی عمومی پیدا می‌کند
func getPlayerByID(ctx context.Context, playerID string) (*PlayerModel, error) {
	var p PlayerModel
	err := col(ColPlayers).FindOne(ctx, bson.M{"player_id": playerID}).Decode(&p)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// insertMessage یک پیام جدید در صندوق گیرنده می‌گذارد
func insertMessage(ctx context.Context, msg MessageModel) error {
	if msg.MessageID == "" {
		msg.MessageID = newID("msg")
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now()
	}
	_, err := col(ColMessages).InsertOne(ctx, msg)
	return err
}

// clanNamesFor نام شهرها را برای مجموعه‌ای از clan_id ها می‌آورد
func clanNamesFor(ctx context.Context, clanIDs []string) map[string]string {
	result := map[string]string{}
	if len(clanIDs) == 0 {
		return result
	}
	cursor, err := col(ColClans).Find(ctx,
		bson.M{"clan_id": bson.M{"$in": clanIDs}},
		options.Find().SetProjection(bson.M{"clan_id": 1, "name": 1}))
	if err != nil {
		return result
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var c struct {
			ClanID string `bson:"clan_id"`
			Name   string `bson:"name"`
		}
		if cursor.Decode(&c) == nil {
			result[c.ClanID] = c.Name
		}
	}
	return result
}

// touchPlayer زمان آخرین بروزرسانی را ثبت می‌کند
func touchPlayer(ctx context.Context, username string, set bson.M) error {
	set["updated_at"] = time.Now()
	_, err := col(ColPlayers).UpdateOne(ctx, bson.M{"username": username}, bson.M{"$set": set})
	return err
}

// ============== ۱. پروفایل ==============

// getProfileHandler پروفایل کامل بازیکن را برمی‌گرداند
// GET /profile?username=<username>   یا   GET /profile?player_id=<id>
func getProfileHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	username := r.URL.Query().Get("username")
	playerID := r.URL.Query().Get("player_id")

	var player *PlayerModel
	var err error
	if username != "" {
		player, err = getPlayerByUsername(ctx, username)
	} else if playerID != "" {
		player, err = getPlayerByID(ctx, playerID)
	} else {
		httpError(w, "username یا player_id لازم است", http.StatusBadRequest)
		return
	}

	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// اطلاعات شهر عضو شده
	var clanInfo interface{}
	if player.ClanID != "" {
		var clan ClanModel
		if col(ColClans).FindOne(ctx, bson.M{"clan_id": player.ClanID}).Decode(&clan) == nil {
			clanInfo = map[string]interface{}{
				"clan_id":      clan.ClanID,
				"name":         clan.Name,
				"icon_path":    clan.IconPath,
				"level":        clan.Level,
				"member_count": clan.MemberCount(),
				"max_members":  clan.MaxMembers,
				"role":         player.ClanRole,
			}
		}
	}

	// صاحبِ پروفایل خودش است (با username آمده، نه player_id)؟ بخش‌های
	// خصوصی (پیام‌ها، وضعیت اکانت) فقط برای خودش ساخته می‌شوند.
	self := username != ""

	// دستاوردی که شرطش برقرار شده ولی هنوز باز نشده (مثلاً بردی که بعد از
	// بررسیِ پایان راند ثبت شد) همین‌جا باز می‌شود
	if self {
		checkAndUnlockAchievements(ctx, player)
	}
	achievements, catalog := buildAchievementView(ctx, player)

	// تعداد پیام‌های خوانده‌نشده (بج روی آیکن نامه)
	var unread int64
	if self {
		unread = countUnreadMessages(ctx, player)
	}

	season := seasonSummary(ctx)
	level, intoLevel, needLevel := levelFromExperience(player.Experience)
	rank := rankViewOf(player)

	// «آخرین سلاح»: آخرین سلاحی که در مسابقه دستش بوده؛ بازیکنی که هنوز
	// مسابقه نداده همان سلاحِ تجهیزشده‌اش را می‌بیند
	lastWeapon := player.Stats.LastUsedWeapon
	if lastWeapon == "" {
		lastWeapon = player.EquippedWeapon
	}

	recent := make([]RecentMatch, 0, len(player.RecentMatches))
	for i := len(player.RecentMatches) - 1; i >= 0; i-- {
		recent = append(recent, player.RecentMatches[i])
	}
	unlockedCount := 0
	for _, item := range catalog {
		if u, _ := item["unlocked"].(bool); u {
			unlockedCount++
		}
	}

	jsonResponse(w, map[string]interface{}{
		"player_id":          player.PlayerID,
		"username":           player.Username,
		"avatar_id":          player.AvatarID,
		"frame_id":           player.FrameID,
		"level":              level,
		"experience":         player.Experience,
		"display_xp":         intoLevel,
		"max_xp":             needLevel,
		"coins":              player.Coins,
		"gems":               player.Gems,
		"equipped_weapon":    player.EquippedWeapon,
		"equipped_character": player.EquippedCharacter,
		"owned_weapons":      player.OwnedWeapons,
		"owned_characters":   player.OwnedCharacters,
		"stats": map[string]interface{}{
			"total_matches":    player.Stats.TotalMatches,
			"wins":             player.Stats.Wins,
			"losses":           player.Stats.Losses,
			"win_rate":         player.Stats.WinRate(),
			"kills":            player.Stats.Kills,
			"deaths":           player.Stats.Deaths,
			"assists":          player.Stats.Assists,
			"kd_ratio":         player.Stats.KDRatio(),
			"playtime_seconds": player.Stats.PlaytimeSeconds,
			"playtime_hours":   player.Stats.PlaytimeSeconds / 3600,
			"missions_done":    player.Stats.MissionsDone,
			"grenade_kills":    player.Stats.GrenadeKills,
			"heals_given":      player.Stats.HealsGiven,
			"last_used_weapon": lastWeapon,
		},
		// رنک همیشه از کاپِ فعلی حساب می‌شود تا دیتای قدیمیِ ذخیره‌شده
		// (آستانه‌های قبلی) صفحه را اشتباه نشان ندهد.
		"rank":           rank,
		"best_tier_name": trophyTiers[tierIndexOf(rank.BestTierID)].Name,
		"trophies":       player.Trophies,
		"rank_tiers":     trophyTiers,
		// کارت فصل در صفحه‌ی رنک: شماره و زمان پایان فصل جاری
		"season_number":  season["number"],
		"season_ends_at": season["ends_at"],
		// تجربه‌ی فصل و کاپ‌ها را سرور حساب می‌کند؛ صفحه‌ی رنک همین را
		// نشان می‌دهد و خودش چیزی نمی‌سازد.
		"season_xp":             seasonXPOf(player),
		"season_cups":           seasonCupCount(seasonXPOf(player)),
		"achievements":          achievements,
		"achievement_catalog":   catalog,
		"achievements_unlocked": unlockedCount,
		"achievements_total":    len(catalog),
		"next_achievement":      nextAchievement(catalog),
		"recent_matches":        recent,
		"friend_count":          len(player.Friends),
		"clan":                  clanInfo,
		"is_online":             player.IsOnline,
		"last_seen_at":          player.LastSeenAt,
		"unread_messages":       unread,
		"google_linked":         self && isProtected(player.Auth),
		"created_at":            player.CreatedAt,
	})
}

// updateProfileHandler تغییر نام کاربری / آواتار / قاب
// POST /profile/update
func updateProfileHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	set := bson.M{}
	if req.AvatarID != "" {
		set["avatar_id"] = req.AvatarID
	}
	if req.FrameID != "" {
		set["frame_id"] = req.FrameID
	}
	newName := strings.TrimSpace(req.NewUsername)
	renaming := newName != "" && newName != req.Username
	if renaming {
		if msg := validateUsername(newName); msg != "" {
			httpError(w, msg, http.StatusBadRequest)
			return
		}
		taken, _ := col(ColPlayers).CountDocuments(ctx, bson.M{"username": newName})
		if taken > 0 {
			httpError(w, "این نام کاربری قبلاً گرفته شده است", http.StatusConflict)
			return
		}
		set["username"] = newName
	}

	if len(set) == 0 {
		httpError(w, "چیزی برای تغییر ارسال نشده", http.StatusBadRequest)
		return
	}

	if err := touchPlayer(ctx, req.Username, set); err != nil {
		if mongo.IsDuplicateKeyError(err) {
			httpError(w, "این نام کاربری قبلاً گرفته شده است", http.StatusConflict)
			return
		}
		httpError(w, "خطا در ذخیره تغییرات", http.StatusInternalServerError)
		return
	}

	// نام کاربری کنار چند رکورد دیگر هم کپی شده (اعضای شهر، درخواست‌ها)؛
	// بدون این، بقیه تا ابد اسم قدیمی را می‌دیدند
	if renaming {
		propagateRename(ctx, me.PlayerID, newName)
	}

	out := map[string]interface{}{"success": true}
	if renaming {
		out["username"] = newName
	}
	jsonResponse(w, out)
}

// UsernameMinLen / UsernameMaxLen بر اساس «حرف» شمرده می‌شوند نه بایت —
// هر حرف فارسی در UTF-8 دو بایت است و قبلاً «علی» رد می‌شد.
const (
	UsernameMinLen = 3
	UsernameMaxLen = 20
)

// validateUsername پیام خطا را برمی‌گرداند؛ رشته‌ی خالی یعنی نام معتبر است
func validateUsername(name string) string {
	n := utf8.RuneCountInString(name)
	if n < UsernameMinLen || n > UsernameMaxLen {
		return fmt.Sprintf("نام کاربری باید بین %d تا %d حرف باشد", UsernameMinLen, UsernameMaxLen)
	}
	for _, r := range name {
		switch {
		case unicode.IsLetter(r), unicode.IsDigit(r), r == '_', r == '-', r == '.', r == ' ', r == '\u200c':
		default:
			return "نام کاربری فقط می‌تواند حرف، عدد، فاصله و _ - . داشته باشد"
		}
	}
	if strings.Contains(name, "  ") {
		return "نام کاربری نباید فاصله‌ی پشت سر هم داشته باشد"
	}
	return ""
}

// propagateRename اسم تازه را در رکوردهایی که نام را کپی کرده‌اند می‌نشاند
func propagateRename(ctx context.Context, playerID, newName string) {
	_, _ = col(ColClans).UpdateMany(ctx,
		bson.M{"members.player_id": playerID},
		bson.M{"$set": bson.M{"members.$[m].username": newName}},
		options.Update().SetArrayFilters(options.ArrayFilters{
			Filters: []interface{}{bson.M{"m.player_id": playerID}},
		}))
	_, _ = col(ColFriendRequests).UpdateMany(ctx, bson.M{"from_id": playerID},
		bson.M{"$set": bson.M{"from_username": newName}})
	_, _ = col(ColFriendRequests).UpdateMany(ctx, bson.M{"to_id": playerID},
		bson.M{"$set": bson.M{"to_username": newName}})
	_, _ = col(ColClanRequests).UpdateMany(ctx, bson.M{"from_id": playerID},
		bson.M{"$set": bson.M{"from_username": newName}})
}

// ============== ۲. دوستان ==============

// getFriendsHandler لیست دوستان + درخواست‌های دریافتی
// GET /friends?username=<username>
func getFriendsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}

	player, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	friends := []PublicProfile{}
	if len(player.Friends) > 0 {
		cursor, err := col(ColPlayers).Find(ctx, bson.M{"player_id": bson.M{"$in": player.Friends}})
		if err == nil {
			defer cursor.Close(ctx)
			clanIDs := []string{}
			for cursor.Next(ctx) {
				var f PlayerModel
				if cursor.Decode(&f) == nil {
					profile := f.ToPublicProfile()
					friends = append(friends, profile)
					if f.ClanID != "" {
						clanIDs = append(clanIDs, f.ClanID)
					}
				}
			}
			// پر کردن نام شهر هر دوست
			names := clanNamesFor(ctx, clanIDs)
			for i := range friends {
				friends[i].ClanName = names[friends[i].ClanID]
			}
		}
	}

	// درخواست‌های دوستی در انتظار
	pending := []FriendRequestModel{}
	cursor, err := col(ColFriendRequests).Find(ctx, bson.M{
		"to_id":  player.PlayerID,
		"status": FriendReqPending,
	}, options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}))
	if err == nil {
		defer cursor.Close(ctx)
		_ = cursor.All(ctx, &pending)
	}

	jsonResponse(w, map[string]interface{}{
		"player_id":        player.PlayerID,
		"friends":          friends,
		"friend_count":     len(friends),
		"pending_requests": pending,
	})
}

// searchPlayerHandler جستجوی بازیکن با آیدی (بخش «یافتن کاربر با آیدی»)
// GET /friends/search?player_id=<id>
func searchPlayerHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	playerID := r.URL.Query().Get("player_id")
	if playerID == "" {
		httpError(w, "آیدی ارسال نشده", http.StatusBadRequest)
		return
	}

	target, err := getPlayerByID(ctx, playerID)
	if err != nil {
		httpError(w, "کاربری با این آیدی پیدا نشد", http.StatusNotFound)
		return
	}

	jsonResponse(w, target.ToPublicProfile())
}

// sendFriendRequestHandler ارسال درخواست دوستی
// POST /friends/request  {"username":"...","target_id":"45135"}
func sendFriendRequestHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req FriendRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	sender, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	target, err := getPlayerByID(ctx, req.TargetID)
	if err != nil {
		httpError(w, "کاربری با این آیدی پیدا نشد", http.StatusNotFound)
		return
	}

	if sender.PlayerID == target.PlayerID {
		httpError(w, "نمی‌توانید به خودتان درخواست دوستی بدهید", http.StatusBadRequest)
		return
	}

	// آیا از قبل دوست هستند؟
	for _, f := range sender.Friends {
		if f == target.PlayerID {
			httpError(w, "این بازیکن از قبل در لیست دوستان شماست", http.StatusConflict)
			return
		}
	}

	// آیا فرستنده بلاک شده است؟
	for _, b := range target.Blocked {
		if b == sender.PlayerID {
			httpError(w, "امکان ارسال درخواست وجود ندارد", http.StatusForbidden)
			return
		}
	}

	fr := FriendRequestModel{
		RequestID:    newID("freq"),
		FromID:       sender.PlayerID,
		FromUsername: sender.Username,
		ToID:         target.PlayerID,
		ToUsername:   target.Username,
		Status:       FriendReqPending,
		CreatedAt:    time.Now(),
	}

	if _, err := col(ColFriendRequests).InsertOne(ctx, fr); err != nil {
		if mongo.IsDuplicateKeyError(err) {
			httpError(w, "درخواست شما قبلاً ارسال شده است", http.StatusConflict)
			return
		}
		httpError(w, "خطا در ثبت درخواست", http.StatusInternalServerError)
		return
	}

	// ساخت پیام «درخواست دوستی» در صندوق مقصد
	_ = insertMessage(ctx, MessageModel{
		RecipientID: target.PlayerID,
		SenderID:    sender.PlayerID,
		SenderName:  sender.Username,
		Type:        MsgTypeFriendRequest,
		Title:       "درخواست دوستی",
		Body:        sender.Username + " به شما درخواست دوستی ارسال کرد",
		RefID:       fr.RequestID,
	})

	// اگر مقصد همین الان آنلاین است، بدون معطلی خبردار شود
	NotifyUser(target.Username, map[string]interface{}{
		"type": "notification",
		"kind": MsgTypeFriendRequest,
		"from": sender.Username,
	})

	jsonResponse(w, map[string]interface{}{"success": true, "request_id": fr.RequestID})
}

// respondFriendRequestHandler پذیرفتن یا رد درخواست دوستی
// POST /friends/respond  {"username":"...","request_id":"...","accept":true}
func respondFriendRequestHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req FriendRespondBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	var fr FriendRequestModel
	err = col(ColFriendRequests).FindOne(ctx, bson.M{
		"request_id": req.RequestID,
		"to_id":      me.PlayerID,
		"status":     FriendReqPending,
	}).Decode(&fr)
	if err != nil {
		httpError(w, "درخواست پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	newStatus := FriendReqRejected
	if req.Accept {
		newStatus = FriendReqAccepted
	}

	_, err = col(ColFriendRequests).UpdateOne(ctx,
		bson.M{"request_id": fr.RequestID},
		bson.M{"$set": bson.M{"status": newStatus, "responded_at": now}})
	if err != nil {
		httpError(w, "خطا در ثبت پاسخ", http.StatusInternalServerError)
		return
	}

	if req.Accept {
		// افزودن دوطرفه (addToSet از تکرار جلوگیری می‌کند)
		_, _ = col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": fr.ToID},
			bson.M{"$addToSet": bson.M{"friends": fr.FromID}, "$set": bson.M{"updated_at": now}})
		_, _ = col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": fr.FromID},
			bson.M{"$addToSet": bson.M{"friends": fr.ToID}, "$set": bson.M{"updated_at": now}})

		// اطلاع به فرستنده
		_ = insertMessage(ctx, MessageModel{
			RecipientID: fr.FromID,
			SenderID:    "system",
			SenderName:  "بازی",
			Type:        MsgTypeSystem,
			Title:       "درخواست دوستی پذیرفته شد",
			Body:        me.Username + " درخواست دوستی شما را پذیرفت",
		})

		NotifyUser(fr.FromUsername, map[string]interface{}{
			"type": "notification",
			"kind": "friend_accepted",
			"from": me.Username,
		})
	}

	// خودِ پاسخ‌دهنده هم لیستش عوض شده
	NotifyUser(me.Username, map[string]interface{}{
		"type": "notification",
		"kind": "friends_changed",
	})

	// پیام مربوط به این درخواست دیگر لازم نیست
	_, _ = col(ColMessages).DeleteMany(ctx, bson.M{"ref_id": fr.RequestID})

	jsonResponse(w, map[string]interface{}{"success": true, "status": newStatus})
}

// removeFriendHandler حذف دوست (دکمه «حذف دوست»)
// POST /friends/remove
func removeFriendHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req FriendRemoveBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	me, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	_, _ = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": me.PlayerID},
		bson.M{"$pull": bson.M{"friends": req.FriendID}, "$set": bson.M{"updated_at": now}})
	_, _ = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": req.FriendID},
		bson.M{"$pull": bson.M{"friends": me.PlayerID}, "$set": bson.M{"updated_at": now}})

	// درخواست‌های قدیمی بین این دو نفر پاک شوند تا بتوانند دوباره درخواست بدهند
	_, _ = col(ColFriendRequests).DeleteMany(ctx, bson.M{"$or": []bson.M{
		{"from_id": me.PlayerID, "to_id": req.FriendID},
		{"from_id": req.FriendID, "to_id": me.PlayerID},
	}})

	if other, err := getPlayerByID(ctx, req.FriendID); err == nil {
		NotifyUser(other.Username, map[string]interface{}{
			"type": "notification",
			"kind": "friends_changed",
		})
	}

	jsonResponse(w, map[string]interface{}{"success": true})
}

// sendGiftHandler ارسال هدیه به دوست (دکمه «هدیه»)
// POST /friends/gift
func sendGiftHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req SendGiftBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	sender, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	if req.Coins < 0 || req.Gems < 0 {
		httpError(w, "مقدار هدیه نامعتبر است", http.StatusBadRequest)
		return
	}
	if req.Coins == 0 && req.Gems == 0 {
		httpError(w, "هدیه خالی است", http.StatusBadRequest)
		return
	}
	if req.Coins > GiftMaxCoins || req.Gems > GiftMaxGems {
		httpError(w, fmt.Sprintf("سقف هر هدیه %d سکه و %d جم است", GiftMaxCoins, GiftMaxGems),
			http.StatusBadRequest)
		return
	}
	if sender.Coins < req.Coins || sender.Gems < req.Gems {
		httpError(w, "موجودی کافی ندارید", http.StatusBadRequest)
		return
	}

	// --- محدودیت: هر ۲۴ ساعت فقط یک هدیه ---
	now := time.Now()
	if sender.LastGiftAt != nil {
		elapsed := now.Sub(*sender.LastGiftAt)
		if elapsed < GiftCooldown {
			remaining := GiftCooldown - elapsed
			httpError(w, "تا هدیه‌ی بعدی "+persianDuration(remaining)+" مانده", http.StatusTooManyRequests)
			return
		}
	}

	// فقط به دوستان می‌توان هدیه داد
	isFriend := false
	for _, f := range sender.Friends {
		if f == req.FriendID {
			isFriend = true
			break
		}
	}
	if !isFriend {
		httpError(w, "این بازیکن در لیست دوستان شما نیست", http.StatusForbidden)
		return
	}

	xpGain := giftXP(req.Coins, req.Gems)

	// کسر از فرستنده + ثبت زمان هدیه + تجربه‌ی ناچیزِ پاداش
	_, err = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": sender.PlayerID},
		bson.M{
			"$inc": bson.M{"coins": -req.Coins, "gems": -req.Gems, "experience": xpGain},
			"$set": bson.M{"updated_at": now, "last_gift_at": now},
		})
	if err != nil {
		httpError(w, "خطا در ثبت هدیه", http.StatusInternalServerError)
		return
	}

	// هدیه به‌صورت پیام قابل دریافت به گیرنده می‌رسد (دریافت با /messages/claim)
	expires := now.AddDate(0, 0, 30)
	body := req.Note
	if body == "" {
		body = sender.Username + " برای شما هدیه فرستاد"
	}
	_ = insertMessage(ctx, MessageModel{
		RecipientID: req.FriendID,
		SenderID:    sender.PlayerID,
		SenderName:  sender.Username,
		Type:        MsgTypeGift,
		Title:       "هدیه از طرف " + sender.Username,
		Body:        body,
		Reward:      &MessageReward{Coins: req.Coins, Gems: req.Gems},
		ExpiresAt:   &expires,
	})

	// گیرنده اگر آنلاین است بدون معطلی خبردار شود
	if receiver, rerr := getPlayerByID(ctx, req.FriendID); rerr == nil {
		NotifyUser(receiver.Username, map[string]interface{}{
			"type": "notification",
			"kind": MsgTypeGift,
			"from": sender.Username,
		})
	}

	nextGift := now.Add(GiftCooldown)
	jsonResponse(w, map[string]interface{}{
		"success":      true,
		"xp_gained":    xpGain,
		"next_gift_at": nextGift,
		"coins":        sender.Coins - req.Coins,
		"gems":         sender.Gems - req.Gems,
	})
}

// ============== ۲.۱ قوانین هدیه ==============

const (
	// GiftCooldown فاصله‌ی لازم بین دو هدیه — هر ۲۴ ساعت یک بار
	GiftCooldown = 24 * time.Hour

	// سقف هر هدیه (جلوگیری از پول‌شویی بین اکانت‌ها)
	GiftMaxCoins = 5000
	GiftMaxGems  = 200

	// نرخ تبدیل هدیه به تجربه — عمداً خیلی کم است تا هدیه‌دادن
	// راهِ میان‌بُرِ لِوِل گرفتن نشود.
	GiftXPPerCoins = 500 // هر ۵۰۰ سکه → ۱ تجربه
	GiftXPPerGems  = 10  // هر ۱۰ جم    → ۱ تجربه
	GiftXPMax      = 15  // سقف تجربه‌ی هر هدیه
)

// giftXP تجربه‌ی ناچیزی که بابت هدیه‌دادن به فرستنده می‌رسد.
// مثال: ۱۰۰۰ سکه → ۲ تجربه، ۵۰ جم → ۵ تجربه، هدیه‌ی حداکثری → ۱۵ تجربه.
// اگر اصلاً هدیه‌ای داده شده باشد، حداقل ۱ تجربه می‌گیرد.
func giftXP(coins, gems int) int {
	xp := coins/GiftXPPerCoins + gems/GiftXPPerGems
	if xp < 1 && (coins > 0 || gems > 0) {
		xp = 1
	}
	if xp > GiftXPMax {
		xp = GiftXPMax
	}
	return xp
}

// persianDuration مدت باقی‌مانده را به شکل خوانا برمی‌گرداند («۳ ساعت و ۱۲ دقیقه»)
func persianDuration(d time.Duration) string {
	if d < time.Minute {
		return "کمتر از یک دقیقه"
	}
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	switch {
	case hours > 0 && minutes > 0:
		return fmt.Sprintf("%d ساعت و %d دقیقه", hours, minutes)
	case hours > 0:
		return fmt.Sprintf("%d ساعت", hours)
	default:
		return fmt.Sprintf("%d دقیقه", minutes)
	}
}

// ============== ۳. صندوق پیام ==============

// getMessagesHandler لیست پیام‌های بازیکن
// GET /messages?username=<username>
func getMessagesHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}

	player, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// پیام‌های شخصی + پیام‌های همگانی ("*")
	filter := bson.M{"recipient_id": bson.M{"$in": []string{player.PlayerID, "*"}}}
	cursor, err := col(ColMessages).Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(100))
	if err != nil {
		httpError(w, "خطا در خواندن پیام‌ها", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	messages := []MessageModel{}
	_ = cursor.All(ctx, &messages)

	// پیام همگانی یک سند برای همه است؛ خوانده/پنهان بودنش مال همین بازیکن است
	messages = personalizeBroadcasts(player, messages)
	unread := 0
	for _, m := range messages {
		if !m.IsRead {
			unread++
		}
	}

	jsonResponse(w, map[string]interface{}{
		"messages":     messages,
		"unread_count": unread,
	})
}

// personalizeBroadcasts پیام‌های "*" را با وضعیت همین بازیکن هماهنگ می‌کند:
// پنهان‌شده‌ها حذف و is_read از read_broadcasts خوانده می‌شود.
func personalizeBroadcasts(player *PlayerModel, messages []MessageModel) []MessageModel {
	read := map[string]bool{}
	for _, id := range player.ReadBroadcasts {
		read[id] = true
	}
	hidden := map[string]bool{}
	for _, id := range player.HiddenBroadcasts {
		hidden[id] = true
	}
	out := messages[:0]
	for _, m := range messages {
		if m.RecipientID == "*" {
			if hidden[m.MessageID] {
				continue
			}
			m.IsRead = read[m.MessageID]
		}
		out = append(out, m)
	}
	return out
}

// countUnreadMessages تعداد پیام‌های خوانده‌نشده با همان قانون صندوق پیام
// (نشان قرمز تاپ‌بار و پروفایل از این می‌خوانند)
func countUnreadMessages(ctx context.Context, player *PlayerModel) int64 {
	personal, _ := col(ColMessages).CountDocuments(ctx, bson.M{
		"recipient_id": player.PlayerID,
		"is_read":      false,
	})
	skip := append(append([]string{}, player.ReadBroadcasts...), player.HiddenBroadcasts...)
	filter := bson.M{"recipient_id": "*"}
	if len(skip) > 0 {
		filter["message_id"] = bson.M{"$nin": skip}
	}
	broadcast, _ := col(ColMessages).CountDocuments(ctx, filter)
	return personal + broadcast
}

// readMessageHandler علامت‌گذاری پیام به‌عنوان خوانده‌شده (تیک دوتایی)
// POST /messages/read
func readMessageHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req MessageActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	res, err := col(ColMessages).UpdateOne(ctx,
		bson.M{"message_id": req.MessageID, "recipient_id": player.PlayerID},
		bson.M{"$set": bson.M{"is_read": true, "read_at": now}})
	if err != nil {
		httpError(w, "خطا در بروزرسانی پیام", http.StatusInternalServerError)
		return
	}
	// پیام همگانی: خوانده شدن فقط برای همین بازیکن ثبت می‌شود، نه برای همه
	if res.MatchedCount == 0 {
		if n, _ := col(ColMessages).CountDocuments(ctx,
			bson.M{"message_id": req.MessageID, "recipient_id": "*"}); n > 0 {
			_, _ = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": player.PlayerID},
				bson.M{"$addToSet": bson.M{"read_broadcasts": req.MessageID}})
		}
	}

	jsonResponse(w, map[string]interface{}{"success": true})
}

// readAllMessagesHandler همه‌ی پیام‌ها خوانده‌شده (دکمه‌ی «خواندن همه»)
// POST /messages/read_all  {"username":"..."}
func readAllMessagesHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req MessageActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	now := time.Now()
	res, err := col(ColMessages).UpdateMany(ctx,
		bson.M{"recipient_id": player.PlayerID, "is_read": false},
		bson.M{"$set": bson.M{"is_read": true, "read_at": now}})
	if err != nil {
		httpError(w, "خطا در بروزرسانی پیام‌ها", http.StatusInternalServerError)
		return
	}

	// پیام‌های همگانی → فقط در read_broadcasts همین بازیکن
	cursor, err := col(ColMessages).Find(ctx, bson.M{"recipient_id": "*"},
		options.Find().SetProjection(bson.M{"message_id": 1}).SetLimit(100))
	if err == nil {
		ids := []string{}
		for cursor.Next(ctx) {
			var m struct {
				MessageID string `bson:"message_id"`
			}
			if cursor.Decode(&m) == nil {
				ids = append(ids, m.MessageID)
			}
		}
		cursor.Close(ctx)
		if len(ids) > 0 {
			_, _ = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": player.PlayerID},
				bson.M{"$addToSet": bson.M{"read_broadcasts": bson.M{"$each": ids}}})
		}
	}

	jsonResponse(w, map[string]interface{}{"success": true, "marked": res.ModifiedCount})
}

// claimMessageRewardHandler دریافت جایزه‌ی ضمیمه‌ی پیام
// POST /messages/claim
func claimMessageRewardHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req MessageActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	reward, err := claimOneMessage(ctx, player.PlayerID, req.MessageID)
	if err != nil {
		if errors.Is(err, errNothingToClaim) {
			httpError(w, "جایزه‌ای برای دریافت وجود ندارد", http.StatusBadRequest)
		} else {
			httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		}
		return
	}

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"coins":   player.Coins + reward.Coins,
		"gems":    player.Gems + reward.Gems,
		"reward":  reward,
	})
}

var errNothingToClaim = errors.New("nothing to claim")

// claimOneMessage جایزه‌ی یک پیام را اتمیک واریز می‌کند. قفل روی خودِ پیام است:
// فقط اگر هنوز دریافت نشده باشد به «دریافت‌شده» تغییر می‌کند، پس دو تپ
// هم‌زمان جایزه را دو بار نمی‌دهند. اگر واریز شکست بخورد، قفل برمی‌گردد.
func claimOneMessage(ctx context.Context, playerID, messageID string) (MessageReward, error) {
	var msg MessageModel
	err := col(ColMessages).FindOneAndUpdate(ctx,
		bson.M{
			"message_id":     messageID,
			"recipient_id":   playerID,
			"reward_claimed": false,
		},
		bson.M{"$set": bson.M{"reward_claimed": true, "is_read": true, "read_at": time.Now()}},
	).Decode(&msg)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			return MessageReward{}, errNothingToClaim
		}
		return MessageReward{}, err
	}
	if msg.Reward.IsEmpty() {
		return MessageReward{Items: []string{}}, nil
	}

	update := bson.M{
		"$inc": bson.M{"coins": msg.Reward.Coins, "gems": msg.Reward.Gems, "experience": msg.Reward.XP},
		"$set": bson.M{"updated_at": time.Now()},
	}
	if len(msg.Reward.Items) > 0 {
		update["$addToSet"] = bson.M{"owned_weapons": bson.M{"$each": msg.Reward.Items}}
	}
	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": playerID}, update); err != nil {
		_, _ = col(ColMessages).UpdateOne(ctx, bson.M{"message_id": msg.MessageID},
			bson.M{"$set": bson.M{"reward_claimed": false}})
		return MessageReward{}, err
	}
	out := *msg.Reward
	if out.Items == nil {
		out.Items = []string{}
	}
	return out, nil
}

// claimAllMessagesHandler همه‌ی جایزه‌های دریافت‌نشده یک‌جا (دکمه‌ی «دریافت همه»)
// POST /messages/claim_all  {"username":"..."}
func claimAllMessagesHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req MessageActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	cursor, err := col(ColMessages).Find(ctx, bson.M{
		"recipient_id":   player.PlayerID,
		"reward":         bson.M{"$exists": true, "$ne": nil},
		"reward_claimed": false,
	}, options.Find().SetProjection(bson.M{"message_id": 1}).SetLimit(50))
	if err != nil {
		httpError(w, "خطا در خواندن پیام‌ها", http.StatusInternalServerError)
		return
	}
	ids := []string{}
	for cursor.Next(ctx) {
		var m struct {
			MessageID string `bson:"message_id"`
		}
		if cursor.Decode(&m) == nil {
			ids = append(ids, m.MessageID)
		}
	}
	cursor.Close(ctx)

	total := MessageReward{Items: []string{}}
	claimed := 0
	for _, id := range ids {
		reward, err := claimOneMessage(ctx, player.PlayerID, id)
		if err != nil {
			continue
		}
		claimed++
		total.Coins += reward.Coins
		total.Gems += reward.Gems
		total.XP += reward.XP
		total.Items = append(total.Items, reward.Items...)
	}

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"claimed": claimed,
		"reward":  total,
		"coins":   player.Coins + total.Coins,
		"gems":    player.Gems + total.Gems,
	})
}

// deleteMessageHandler حذف پیام (دکمه ضربدر)
// POST /messages/delete
func deleteMessageHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req MessageActionBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// پیام حاوی جایزه‌ی دریافت‌نشده حذف نمی‌شود
	res, err := col(ColMessages).DeleteOne(ctx, bson.M{
		"message_id":   req.MessageID,
		"recipient_id": player.PlayerID,
		"$or": []bson.M{
			{"reward": bson.M{"$exists": false}},
			{"reward_claimed": true},
		},
	})
	if err == nil && res.DeletedCount == 0 {
		// پیام همگانی پاک نمی‌شود — فقط از صندوق همین بازیکن پنهان می‌شود
		if n, _ := col(ColMessages).CountDocuments(ctx,
			bson.M{"message_id": req.MessageID, "recipient_id": "*"}); n > 0 {
			_, _ = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": player.PlayerID},
				bson.M{"$addToSet": bson.M{"hidden_broadcasts": req.MessageID}})
			jsonResponse(w, map[string]interface{}{"success": true})
			return
		}
	}
	if err != nil || res.DeletedCount == 0 {
		httpError(w, "این پیام قابل حذف نیست (ابتدا جایزه را دریافت کنید)", http.StatusBadRequest)
		return
	}

	jsonResponse(w, map[string]interface{}{"success": true})
}

// ============== ۵. شهر (کلن) ==============

// getClanHandler اطلاعات یک شهر
// GET /clan?clan_id=<id>
func getClanHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	// بیننده (اختیاری) — تعیین می‌کند چه دکمه‌هایی برایش فعال باشد
	var viewer *PlayerModel
	if username := r.URL.Query().Get("username"); username != "" {
		if p, err := getPlayerByUsername(ctx, username); err == nil {
			viewer = p
		}
	}

	// اگر clan_id نیامد ولی بیننده مشخص است، شهرِ خودش را نشان می‌دهیم.
	// منوی شهر با همین حالت باز می‌شود و لازم نیست کلاینت آیدی را بداند.
	clanID := r.URL.Query().Get("clan_id")
	if clanID == "" && viewer != nil {
		clanID = viewer.ClanID
	}
	if clanID == "" {
		httpError(w, "clan_id ارسال نشده", http.StatusBadRequest)
		return
	}

	var clan ClanModel
	if err := col(ColClans).FindOne(ctx, bson.M{"clan_id": clanID}).Decode(&clan); err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}

	response := clanSummary(&clan)
	response["members"] = enrichClanMembers(ctx, &clan, viewer)

	// اختیارات بیننده تا کلاینت دکمه‌های مدیریتی را درست نشان دهد
	myRole := ""
	if viewer != nil {
		myRole = clanMemberRole(&clan, viewer.PlayerID)
	}
	response["my_role"] = myRole
	response["is_member"] = myRole != ""
	response["can_manage"] = clanRoleRank(myRole) >= clanRoleRank(ClanRoleOfficer)
	response["can_lead"] = myRole == ClanRoleLeader

	// کارت بالای صفحه و «اطلاعات شهر»
	leader, officers := clanLeaderInfo(&clan)
	response["leader_name"] = leader
	response["officer_count"] = officers
	response["world_rank"] = clanWorldRank(ctx, &clan)
	response["rename_cost"] = ClanRenameCost

	// وضعیت بیننده‌ای که عضو نیست — دکمه‌ی «عضویت» از روی این‌ها چیده می‌شود
	if viewer != nil {
		response["player_id"] = viewer.PlayerID
		response["my_clan_id"] = viewer.ClanID
		response["my_level"] = viewer.Level
		response["my_coins"] = viewer.Coins
		pending := false
		if myRole == "" {
			n, err := col(ColClanRequests).CountDocuments(ctx, bson.M{
				"clan_id": clan.ClanID,
				"from_id": viewer.PlayerID,
				"status":  ClanReqPending,
			})
			pending = err == nil && n > 0
		}
		response["request_pending"] = pending
	}

	// تعداد درخواست‌های بازِ عضویت — نشان قرمز روی دکمه‌ی «درخواست‌ها»
	if clanRoleRank(myRole) >= clanRoleRank(ClanRoleOfficer) {
		count, err := col(ColClanRequests).CountDocuments(ctx,
			bson.M{"clan_id": clan.ClanID, "status": ClanReqPending})
		if err == nil {
			response["pending_requests"] = count
		}
	}

	jsonResponse(w, response)
}

// ============== ۶. ثبت نتیجه مسابقه (منبع آمار پروفایل) ==============

// submitMatchResultHandler نتیجه یک مسابقه را ثبت و آمار بازیکنان را بروز می‌کند
// POST /match/result
func submitMatchResultHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req MatchResultBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	now := time.Now()
	if req.MatchID == "" {
		req.MatchID = newID("match")
	}

	record := MatchRecord{
		MatchID:         req.MatchID,
		Mode:            req.Mode,
		MapName:         req.MapName,
		StartedAt:       now.Add(-time.Duration(req.DurationSeconds) * time.Second),
		EndedAt:         now,
		DurationSeconds: req.DurationSeconds,
		Participants:    req.Participants,
	}

	if _, err := col(ColMatches).InsertOne(ctx, record); err != nil {
		if mongo.IsDuplicateKeyError(err) {
			httpError(w, "این مسابقه قبلاً ثبت شده است", http.StatusConflict)
			return
		}
		httpError(w, "خطا در ثبت مسابقه", http.StatusInternalServerError)
		return
	}

	// بروزرسانی آمار تجمعی هر بازیکن
	for _, part := range req.Participants {
		inc := bson.M{
			"stats.total_matches":    1,
			"stats.kills":            part.Kills,
			"stats.deaths":           part.Deaths,
			"stats.assists":          part.Assists,
			"stats.grenade_kills":    part.GrenadeKills,
			"stats.heals_given":      part.HealsGiven,
			"stats.playtime_seconds": req.DurationSeconds,
			"experience":             part.XPGained,
			"coins":                  part.CoinsGained,
			"rank.points":            part.RankDelta,
		}
		if part.Won {
			inc["stats.wins"] = 1
		} else {
			inc["stats.losses"] = 1
		}

		set := bson.M{"updated_at": now, "last_seen_at": now}
		if part.WeaponUsed != "" {
			set["stats.last_used_weapon"] = part.WeaponUsed
		}

		_, _ = col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": part.PlayerID},
			bson.M{"$inc": inc, "$set": set})

		// پیشرفت ماموریت‌های روزانه — تنها جایی که ماموریت‌ها جلو می‌روند.
		// عمداً از خودِ `part` خوانده می‌شود که همان چیزی است که در رکورد
		// مسابقه ثبت شد، نه چیزی که کلاینت جدا ادعا کند.
		_ = applyMatchToMissions(ctx, part.PlayerID, part, req.DurationSeconds)
		// چالش‌های فصل هم از همین نتیجه تغذیه می‌شوند
		_ = applyMatchToSeasonStats(ctx, part.PlayerID, part, req.DurationSeconds)

		// تجربه‌ی مسابقه به نوار پاداش فصل هم اضافه می‌شود
		_ = addSeasonPassXP(ctx, part.PlayerID, part.XPGained)

		// بررسی باز شدن دستاوردهای جدید
		if p, err := getPlayerByID(ctx, part.PlayerID); err == nil {
			checkAndUnlockAchievements(ctx, p)
		}
	}

	jsonResponse(w, map[string]interface{}{"success": true, "match_id": req.MatchID})
}
