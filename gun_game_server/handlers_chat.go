package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// هندلرهای چت زنده — صفحه‌ی «چت» بازی
//
// سه کانال داریم:
//   private : گفتگوی دو نفره، فقط بین کسانی که دوست همدیگرند
//   city    : گفتگوی اعضای یک شهر (کلن) — فقط اعضا
//   global  : گفتگوی عمومی همه‌ی بازیکن‌ها
//
// هر گفتگو یک «اتاق» (room) دارد و پیام‌ها با همان کلید ذخیره می‌شوند:
//   global            → اتاق جهانی
//   city:<clan_id>    → اتاق یک شهر
//   dm:<id1>_<id2>    → اتاق خصوصی (آیدی‌ها مرتب‌شده تا برای هر دو طرف یکی باشد)
//
// پیام‌ها هم در دیتابیس ذخیره می‌شوند (برای تاریخچه) و هم همان لحظه روی
// WebSocket برای گیرنده‌های آنلاین فرستاده می‌شوند (type = "chat_message").
// =============================================================================

// ============== محدودیت نرخ ارسال ==============

// chatRateLimiter جلوی اسپم را می‌گیرد: هر بازیکن حداقل ChatSendCooldown
// میلی‌ثانیه بین دو پیام فاصله داشته باشد.
var chatRateLimiter = struct {
	sync.Mutex
	last map[string]time.Time
}{last: map[string]time.Time{}}

// allowChatSend اجازه‌ی ارسال می‌دهد و زمان را ثبت می‌کند
func allowChatSend(playerID string) bool {
	chatRateLimiter.Lock()
	defer chatRateLimiter.Unlock()

	now := time.Now()
	if last, ok := chatRateLimiter.last[playerID]; ok {
		if now.Sub(last) < time.Duration(ChatSendCooldown)*time.Millisecond {
			return false
		}
	}

	// نگه‌داشتن نامحدودِ کلیدها لازم نیست؛ ورودی‌های کهنه گاه‌به‌گاه پاک می‌شوند
	if len(chatRateLimiter.last) > 5000 {
		for id, t := range chatRateLimiter.last {
			if now.Sub(t) > time.Minute {
				delete(chatRateLimiter.last, id)
			}
		}
	}

	chatRateLimiter.last[playerID] = now
	return true
}

// ============== توابع کمکی اتاق ==============

// privateRoomID کلید اتاق خصوصی دو بازیکن — ترتیب آیدی‌ها مهم نیست
func privateRoomID(a, b string) string {
	if a > b {
		a, b = b, a
	}
	return "dm:" + a + "_" + b
}

// cityRoomID کلید اتاق چت یک شهر
func cityRoomID(clanID string) string {
	return "city:" + clanID
}

// resolveChatRoom مشخص می‌کند بازیکن اجازه‌ی این اتاق را دارد یا نه و کلید آن چیست.
//
// خروجی: کلید اتاق، پروفایل طرف مقابل (فقط در چت خصوصی)، پیام خطا.
// اگر پیام خطا خالی نباشد یعنی دسترسی مجاز نیست.
func resolveChatRoom(ctx context.Context, viewer *PlayerModel, channel, peerID string) (string, *PlayerModel, string) {
	switch channel {
	case ChatChannelGlobal:
		return ChatRoomGlobal, nil, ""

	case ChatChannelCity:
		if viewer.ClanID == "" {
			return "", nil, "برای چت شهر باید عضو یک شهر باشی"
		}
		return cityRoomID(viewer.ClanID), nil, ""

	case ChatChannelPrivate:
		if peerID == "" {
			return "", nil, "آیدی طرف مقابل ارسال نشده"
		}
		if peerID == viewer.PlayerID {
			return "", nil, "نمی‌توانی به خودت پیام بدهی"
		}
		// چت خصوصی فقط بین دوست‌هاست
		if !containsString(viewer.Friends, peerID) {
			return "", nil, "چت خصوصی فقط با دوستان ممکن است"
		}
		peer, err := getPlayerByID(ctx, peerID)
		if err != nil {
			return "", nil, "بازیکن پیدا نشد"
		}
		// اگر یکی از دو طرف دیگری را بلاک کرده باشد، گفتگو بسته است
		if containsString(viewer.Blocked, peerID) || containsString(peer.Blocked, viewer.PlayerID) {
			return "", nil, "این گفتگو در دسترس نیست"
		}
		return privateRoomID(viewer.PlayerID, peerID), peer, ""
	}

	return "", nil, "کانال چت نامعتبر است"
}

// containsString بررسی می‌کند رشته در لیست هست یا نه
func containsString(list []string, value string) bool {
	for _, item := range list {
		if item == value {
			return true
		}
	}
	return false
}

// ============== خوانده‌شدن اتاق‌ها ==============

// chatLastRead آخرین باری که بازیکن این اتاق‌ها را باز کرده را برمی‌گرداند
func chatLastRead(ctx context.Context, playerID string, rooms []string) map[string]time.Time {
	result := map[string]time.Time{}
	if len(rooms) == 0 {
		return result
	}

	cursor, err := col(ColChatReads).Find(ctx, bson.M{
		"player_id": playerID,
		"room":      bson.M{"$in": rooms},
	})
	if err != nil {
		return result
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var read ChatReadModel
		if cursor.Decode(&read) == nil {
			result[read.Room] = read.LastReadAt
		}
	}
	return result
}

// markChatRoomRead ثبت می‌کند که بازیکن این اتاق را تا همین لحظه دیده است
func markChatRoomRead(ctx context.Context, playerID, room string) {
	_, _ = col(ColChatReads).UpdateOne(ctx,
		bson.M{"player_id": playerID, "room": room},
		bson.M{"$set": bson.M{"last_read_at": time.Now()}},
		options.Update().SetUpsert(true))
}

// countChatUnread تعداد پیام‌های خوانده‌نشده‌ی یک اتاق را می‌شمارد
// (پیام‌های خودِ بازیکن و پیام‌های بلاک‌شده‌ها حساب نمی‌شوند)
func countChatUnread(ctx context.Context, viewer *PlayerModel, room string, since time.Time) int {
	filter := bson.M{
		"room":      room,
		"sender_id": bson.M{"$ne": viewer.PlayerID},
	}
	if len(viewer.Blocked) > 0 {
		filter["sender_id"] = bson.M{"$ne": viewer.PlayerID, "$nin": viewer.Blocked}
	}
	if !since.IsZero() {
		filter["created_at"] = bson.M{"$gt": since}
	}

	count, err := col(ColChatMessages).CountDocuments(ctx, filter,
		options.Count().SetLimit(100)) // بیشتر از ۹۹ تا لازم نیست دقیق باشد
	if err != nil {
		return 0
	}
	return int(count)
}

// lastChatMessage آخرین پیام هر اتاق را برای پیش‌نمایش لیست گفتگوها می‌آورد
func lastChatMessages(ctx context.Context, rooms []string) map[string]ChatMessageModel {
	result := map[string]ChatMessageModel{}
	if len(rooms) == 0 {
		return result
	}

	// یک کوئری برای همه‌ی اتاق‌ها: آخرین پیام هر room
	pipeline := mongo.Pipeline{
		bson.D{{Key: "$match", Value: bson.M{"room": bson.M{"$in": rooms}}}},
		bson.D{{Key: "$sort", Value: bson.D{{Key: "created_at", Value: -1}}}},
		bson.D{{Key: "$group", Value: bson.M{
			"_id": "$room",
			"doc": bson.M{"$first": "$$ROOT"},
		}}},
	}

	cursor, err := col(ColChatMessages).Aggregate(ctx, pipeline)
	if err != nil {
		return result
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var row struct {
			Doc ChatMessageModel `bson:"doc"`
		}
		if cursor.Decode(&row) == nil {
			result[row.Doc.Room] = row.Doc
		}
	}
	return result
}

// ============== ۱. نمای کلی چت (لیست گفتگوها) ==============

// getChatOverviewHandler سه بخش صفحه‌ی چت را یکجا برمی‌گرداند:
// کارت چت جهانی، کارت چت شهر، و لیست گفتگوهای خصوصی (دوستان).
//
// GET /chat/overview?username=<username>
func getChatOverviewHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}

	viewer, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// --- دوستان (هر دوست یک گفتگوی خصوصی است) ---
	friends := findPlayersByIDs(ctx, viewer.Friends)

	// --- جمع کردن کلید همه‌ی اتاق‌ها برای یک بار کوئری زدن ---
	rooms := []string{ChatRoomGlobal}
	cityRoom := ""
	if viewer.ClanID != "" {
		cityRoom = cityRoomID(viewer.ClanID)
		rooms = append(rooms, cityRoom)
	}
	privateRooms := map[string]string{} // player_id دوست → کلید اتاق
	for _, friend := range friends {
		room := privateRoomID(viewer.PlayerID, friend.PlayerID)
		privateRooms[friend.PlayerID] = room
		rooms = append(rooms, room)
	}

	lastRead := chatLastRead(ctx, viewer.PlayerID, rooms)
	lastMessages := lastChatMessages(ctx, rooms)

	// --- کارت چت جهانی ---
	totalUnread := 0
	globalUnread := countChatUnread(ctx, viewer, ChatRoomGlobal, lastRead[ChatRoomGlobal])
	totalUnread += globalUnread
	globalCard := map[string]interface{}{
		"channel":   ChatChannelGlobal,
		"room":      ChatRoomGlobal,
		"title":     "چت جهانی",
		"available": true,
		"unread":    globalUnread,
	}
	fillLastMessage(globalCard, lastMessages[ChatRoomGlobal], viewer.PlayerID)

	// --- کارت چت شهر ---
	cityCard := map[string]interface{}{
		"channel":   ChatChannelCity,
		"title":     "چت شهر",
		"available": false,
		"unread":    0,
		"hint":      "هنوز عضو هیچ شهری نیستی",
	}
	var clan *ClanModel
	if cityRoom != "" {
		cityUnread := countChatUnread(ctx, viewer, cityRoom, lastRead[cityRoom])
		totalUnread += cityUnread
		cityCard["available"] = true
		cityCard["room"] = cityRoom
		cityCard["unread"] = cityUnread
		delete(cityCard, "hint")
		if c, cerr := getClanByID(ctx, viewer.ClanID); cerr == nil {
			clan = c
			cityCard["title"] = clan.Name
			cityCard["member_count"] = clan.MemberCount()
		}
		fillLastMessage(cityCard, lastMessages[cityRoom], viewer.PlayerID)
	}

	// --- گفتگوهای خصوصی ---
	clanIDs := []string{}
	for _, friend := range friends {
		if friend.ClanID != "" {
			clanIDs = append(clanIDs, friend.ClanID)
		}
	}
	clanNames := clanNamesFor(ctx, clanIDs)

	privates := []map[string]interface{}{}
	privateUnread := 0
	for i := range friends {
		friend := friends[i]
		if containsString(viewer.Blocked, friend.PlayerID) {
			continue
		}

		room := privateRooms[friend.PlayerID]
		unread := countChatUnread(ctx, viewer, room, lastRead[room])
		totalUnread += unread
		privateUnread += unread

		row := map[string]interface{}{
			"channel":      ChatChannelPrivate,
			"room":         room,
			"peer_id":      friend.PlayerID,
			"username":     friend.Username,
			"avatar_id":    friend.AvatarID,
			"level":        friend.Level,
			"is_online":    friend.IsOnline,
			"last_seen_at": friend.LastSeenAt,
			"clan_name":    clanNames[friend.ClanID],
			"tier_id":      friend.Rank.TierID,
			"tier_name":    friend.Rank.TierName,
			"unread":       unread,
		}
		fillLastMessage(row, lastMessages[room], viewer.PlayerID)
		privates = append(privates, row)
	}

	// مرتب‌سازی: گفتگوهای خوانده‌نشده اول، بعد تازه‌ترین پیام، بعد آنلاین‌ها
	sort.SliceStable(privates, func(a, b int) bool {
		ua, _ := privates[a]["unread"].(int)
		ub, _ := privates[b]["unread"].(int)
		if (ua > 0) != (ub > 0) {
			return ua > 0
		}
		ta, aok := privates[a]["last_at"].(time.Time)
		tb, bok := privates[b]["last_at"].(time.Time)
		if aok != bok {
			return aok
		}
		if aok && bok && !ta.Equal(tb) {
			return ta.After(tb)
		}
		oa, _ := privates[a]["is_online"].(bool)
		ob, _ := privates[b]["is_online"].(bool)
		if oa != ob {
			return oa
		}
		return false
	})

	jsonResponse(w, map[string]interface{}{
		"player_id":    viewer.PlayerID,
		"username":     viewer.Username,
		"global":       globalCard,
		"city":         cityCard,
		"privates":     privates,
		"total_unread": totalUnread,
		// نشان قرمز دکمه‌ی چت در منوی اصلی فقط پیام‌های دوستان را می‌شمارد
		"private_unread": privateUnread,
		"online_count":   onlinePlayerCount(),
		"people":         chatPeople(ctx, viewer, friends, clan),
	})
}

// findPlayersByIDs پروفایل چند بازیکن را با یک کوئری می‌آورد.
//
// سند به سند decode می‌شود (نه cursor.All): اگر فقط یک سندِ قدیمی با فیلدی
// ناسازگار خراب باشد، cursor.All کل لیست را خالی برمی‌گرداند و ستون آنلاین و
// لیست دوستان صفر نشان داده می‌شد. حالا فقط همان یک سند کنار گذاشته می‌شود.
func findPlayersByIDs(ctx context.Context, ids []string) []PlayerModel {
	players := []PlayerModel{}
	if len(ids) == 0 {
		return players
	}
	cursor, err := col(ColPlayers).Find(ctx, bson.M{"player_id": bson.M{"$in": ids}})
	if err != nil {
		log.Printf("⚠️ chat: خواندن بازیکن‌ها ناموفق: %v", err)
		return players
	}
	defer cursor.Close(ctx)
	for cursor.Next(ctx) {
		var p PlayerModel
		if derr := cursor.Decode(&p); derr != nil {
			log.Printf("⚠️ chat: سند بازیکن decode نشد (%v): %v", cursor.Current.Lookup("player_id"), derr)
			continue
		}
		players = append(players, p)
	}
	return players
}

// chatPeople لیست ستون «آنلاین» صفحه‌ی چت: فقط دوستان و هم‌شهری‌ها
// (چت جهانی عمداً اینجا نیست). هر نفر یک بار می‌آید حتی اگر هم دوست باشد
// هم هم‌شهری. ترتیب: آنلاین‌ها اول، بعد تازه‌ترین بازدید.
func chatPeople(ctx context.Context, viewer *PlayerModel, friends []PlayerModel, clan *ClanModel) []map[string]interface{} {
	people := map[string]*PlayerModel{}
	for i := range friends {
		people[friends[i].PlayerID] = &friends[i]
	}

	roles := map[string]string{}
	if clan != nil {
		missing := []string{}
		for _, member := range clan.Members {
			roles[member.PlayerID] = member.Role
			if member.PlayerID != viewer.PlayerID && people[member.PlayerID] == nil {
				missing = append(missing, member.PlayerID)
			}
		}
		members := findPlayersByIDs(ctx, missing)
		for i := range members {
			people[members[i].PlayerID] = &members[i]
		}
	}

	rows := []map[string]interface{}{}
	for id, p := range people {
		if id == viewer.PlayerID || containsString(viewer.Blocked, id) {
			continue
		}
		role, inCity := roles[id]
		rows = append(rows, map[string]interface{}{
			"player_id":    p.PlayerID,
			"username":     p.Username,
			"avatar_id":    p.AvatarID,
			"level":        p.Level,
			"is_online":    p.IsOnline,
			"last_seen_at": p.LastSeenAt,
			"tier_id":      p.Rank.TierID,
			"is_friend":    containsString(viewer.Friends, id),
			"is_city":      inCity,
			"clan_role":    role,
		})
	}

	sort.SliceStable(rows, func(a, b int) bool {
		oa, _ := rows[a]["is_online"].(bool)
		ob, _ := rows[b]["is_online"].(bool)
		if oa != ob {
			return oa
		}
		ta, _ := rows[a]["last_seen_at"].(time.Time)
		tb, _ := rows[b]["last_seen_at"].(time.Time)
		if !ta.Equal(tb) {
			return ta.After(tb)
		}
		return rows[a]["username"].(string) < rows[b]["username"].(string)
	})
	return rows
}

// fillLastMessage پیش‌نمایش آخرین پیام یک اتاق را روی کارت می‌گذارد
func fillLastMessage(card map[string]interface{}, msg ChatMessageModel, viewerID string) {
	if msg.MessageID == "" {
		card["last_text"] = ""
		card["last_sender"] = ""
		return
	}
	card["last_text"] = msg.Text
	card["last_sender"] = msg.SenderName
	card["last_from_me"] = msg.SenderID == viewerID
	card["last_at"] = msg.CreatedAt
}

// onlinePlayerCount تعداد بازیکن‌های آنلاین (برای نمایش کنار چت جهانی)
func onlinePlayerCount() int {
	if db == nil {
		return 0
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	count, err := col(ColPlayers).CountDocuments(ctx, bson.M{"is_online": true})
	if err != nil {
		return 0
	}
	return int(count)
}

// ============== ۲. تاریخچه‌ی یک اتاق ==============

// getChatHistoryHandler پیام‌های یک اتاق را از قدیم به جدید برمی‌گرداند.
//
// GET /chat/history?username=<username>&channel=<private|city|global>
//
//	&peer_id=<player_id>&limit=<n>&before=<RFC3339>
//
// اگر before خالی باشد یعنی بازیکن دارد چت را باز می‌کند، پس اتاق
// «خوانده‌شده» علامت می‌خورد. `before` برای اسکرول به عقب استفاده می‌شود.
func getChatHistoryHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	query := r.URL.Query()
	username := query.Get("username")
	if username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}

	viewer, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	channel := query.Get("channel")
	peerID := query.Get("peer_id")
	room, peer, denied := resolveChatRoom(ctx, viewer, channel, peerID)
	if denied != "" {
		httpError(w, denied, http.StatusForbidden)
		return
	}

	limit := ChatHistoryLimit
	if raw := query.Get("limit"); raw != "" {
		if parsed, perr := strconv.Atoi(raw); perr == nil && parsed > 0 {
			limit = parsed
		}
	}
	if limit > ChatMaxHistoryLimit {
		limit = ChatMaxHistoryLimit
	}

	filter := bson.M{"room": room}
	if len(viewer.Blocked) > 0 {
		filter["sender_id"] = bson.M{"$nin": viewer.Blocked}
	}

	// اسکرول به عقب: فقط پیام‌های قدیمی‌تر از این زمان
	isFirstPage := true
	if raw := query.Get("before"); raw != "" {
		if parsed, perr := time.Parse(time.RFC3339Nano, raw); perr == nil {
			filter["created_at"] = bson.M{"$lt": parsed}
			isFirstPage = false
		}
	}
	// دریافت فقط پیام‌های جدیدتر (پولینگ سبک)
	if raw := query.Get("after"); raw != "" {
		if parsed, perr := time.Parse(time.RFC3339Nano, raw); perr == nil {
			filter["created_at"] = bson.M{"$gt": parsed}
		}
	}

	// تازه‌ترین‌ها را می‌گیریم بعد برعکس می‌کنیم تا ترتیب نمایش درست باشد
	cursor, err := col(ColChatMessages).Find(ctx, filter,
		options.Find().
			SetSort(bson.D{{Key: "created_at", Value: -1}}).
			SetLimit(int64(limit)))
	if err != nil {
		httpError(w, "خطا در خواندن پیام‌ها", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	messages := []ChatMessageModel{}
	_ = cursor.All(ctx, &messages)
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	// وضعیت آنلاینِ فرستنده‌ها همیشه لحظه‌ای خوانده می‌شود
	online := onlineStateFor(ctx, messages)

	payload := map[string]interface{}{
		"room":     room,
		"channel":  channel,
		"messages": messages,
		"online":   online,
		"has_more": len(messages) == limit,
	}

	// اطلاعات طرف مقابل برای هدر چت خصوصی
	if peer != nil {
		clanNames := clanNamesFor(ctx, []string{peer.ClanID})
		payload["peer"] = map[string]interface{}{
			"peer_id":      peer.PlayerID,
			"username":     peer.Username,
			"avatar_id":    peer.AvatarID,
			"level":        peer.Level,
			"is_online":    peer.IsOnline,
			"last_seen_at": peer.LastSeenAt,
			"clan_name":    clanNames[peer.ClanID],
			"tier_id":      peer.Rank.TierID,
			"tier_name":    peer.Rank.TierName,
		}
	}
	if channel == ChatChannelGlobal {
		payload["online_count"] = onlinePlayerCount()
	}
	if channel == ChatChannelCity {
		if clan, cerr := getClanByID(ctx, viewer.ClanID); cerr == nil {
			payload["title"] = clan.Name
			payload["member_count"] = clan.MemberCount()
		}
	}

	if isFirstPage {
		markChatRoomRead(ctx, viewer.PlayerID, room)
	}

	jsonResponse(w, payload)
}

// onlineStateFor وضعیت آنلاین بودن فرستنده‌های یک دسته پیام
// خروجی: player_id → آنلاین است یا نه
func onlineStateFor(ctx context.Context, messages []ChatMessageModel) map[string]bool {
	result := map[string]bool{}
	if len(messages) == 0 {
		return result
	}

	seen := map[string]bool{}
	ids := []string{}
	for _, msg := range messages {
		if msg.SenderID != "" && !seen[msg.SenderID] {
			seen[msg.SenderID] = true
			ids = append(ids, msg.SenderID)
		}
	}

	cursor, err := col(ColPlayers).Find(ctx,
		bson.M{"player_id": bson.M{"$in": ids}},
		options.Find().SetProjection(bson.M{"player_id": 1, "is_online": 1}))
	if err != nil {
		return result
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var row struct {
			PlayerID string `bson:"player_id"`
			IsOnline bool   `bson:"is_online"`
		}
		if cursor.Decode(&row) == nil {
			result[row.PlayerID] = row.IsOnline
		}
	}
	return result
}

// ============== ۳. فرستادن پیام ==============

// sendChatMessageHandler یک پیام چت را ذخیره و همان لحظه پخش می‌کند.
//
// POST /chat/send  {username, channel, peer_id?, text}
func sendChatMessageHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "متد باید POST باشد", http.StatusMethodNotAllowed)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	var body ChatSendBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httpError(w, "بدنه‌ی درخواست نامعتبر است", http.StatusBadRequest)
		return
	}

	text := sanitizeChatText(body.Text)
	if text == "" {
		httpError(w, "متن پیام خالی است", http.StatusBadRequest)
		return
	}
	if len([]rune(text)) > ChatMaxTextLength {
		httpError(w, "متن پیام خیلی بلند است", http.StatusBadRequest)
		return
	}

	sender, err := getPlayerByUsername(ctx, body.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if sender.IsBanned {
		httpError(w, "حساب تو مسدود است", http.StatusForbidden)
		return
	}
	// بستنِ چت از پنل مدیریت
	if sender.ChatMutedUntil != nil && time.Now().Before(*sender.ChatMutedUntil) {
		httpError(w, "چتِ تو تا "+persianDuration(time.Until(*sender.ChatMutedUntil))+" دیگر بسته است", http.StatusForbidden)
		return
	}

	room, peer, denied := resolveChatRoom(ctx, sender, body.Channel, body.PeerID)
	if denied != "" {
		httpError(w, denied, http.StatusForbidden)
		return
	}

	if !allowChatSend(sender.PlayerID) {
		httpError(w, "کمی آرام‌تر — پیام‌ها را پشت سر هم نفرست", http.StatusTooManyRequests)
		return
	}

	// نام شهر فرستنده برای نشان کنار اسمش در چت جهانی
	senderClan := ""
	if sender.ClanID != "" {
		senderClan = clanNamesFor(ctx, []string{sender.ClanID})[sender.ClanID]
	}

	now := time.Now()
	message := ChatMessageModel{
		MessageID:    newID("chat"),
		Room:         room,
		Channel:      body.Channel,
		SenderID:     sender.PlayerID,
		SenderName:   sender.Username,
		SenderAvatar: sender.AvatarID,
		SenderLevel:  sender.Level,
		SenderClan:   senderClan,
		SenderTier:   sender.Rank.TierName,
		Text:         text,
		CreatedAt:    now,
	}

	// پیام‌های عمومی موقتی‌اند تا دیتابیس بی‌نهایت بزرگ نشود؛ خصوصی‌ها می‌مانند
	if body.Channel != ChatChannelPrivate {
		expires := now.Add(time.Duration(ChatPublicTTLDays) * 24 * time.Hour)
		message.ExpiresAt = &expires
	}

	if _, err := col(ColChatMessages).InsertOne(ctx, message); err != nil {
		httpError(w, "پیام ذخیره نشد", http.StatusInternalServerError)
		return
	}

	// فرستنده خودش این اتاق را تا همین لحظه دیده است
	markChatRoomRead(ctx, sender.PlayerID, room)

	broadcastChatMessage(ctx, sender, peer, message)

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"message": message,
	})
}

// sanitizeChatText متن پیام را تمیز می‌کند: فاصله‌های اضافه، خط‌های جدید
// پشت سر هم و کاراکترهای کنترلی حذف می‌شوند.
func sanitizeChatText(raw string) string {
	cleaned := strings.Map(func(r rune) rune {
		if r == '\n' || r == '\t' {
			return ' '
		}
		if r < 32 || r == 127 {
			return -1
		}
		return r
	}, raw)

	return strings.TrimSpace(strings.Join(strings.Fields(cleaned), " "))
}

// broadcastChatMessage پیام تازه را روی WebSocket برای گیرنده‌ها می‌فرستد
func broadcastChatMessage(ctx context.Context, sender *PlayerModel, peer *PlayerModel, message ChatMessageModel) {
	payload := map[string]interface{}{
		"type":          "chat_message",
		"room":          message.Room,
		"channel":       message.Channel,
		"message_id":    message.MessageID,
		"sender_id":     message.SenderID,
		"sender_name":   message.SenderName,
		"sender_avatar": message.SenderAvatar,
		"sender_level":  message.SenderLevel,
		"sender_clan":   message.SenderClan,
		"sender_tier":   message.SenderTier,
		"text":          message.Text,
		"created_at":    message.CreatedAt.Format(time.RFC3339Nano),
	}

	switch message.Channel {
	case ChatChannelGlobal:
		NotifyEveryone(payload)

	case ChatChannelCity:
		clan, err := getClanByID(ctx, sender.ClanID)
		if err != nil {
			return
		}
		usernames := make([]string, 0, len(clan.Members))
		for _, member := range clan.Members {
			if member.Username != "" && member.Username != sender.Username {
				usernames = append(usernames, member.Username)
			}
		}
		NotifyUsers(usernames, payload)

	case ChatChannelPrivate:
		if peer != nil {
			payload["peer_id"] = sender.PlayerID // از دید گیرنده، طرف مقابل فرستنده است
			NotifyUser(peer.Username, payload)
		}
	}
}

// ============== ۴. علامت‌زدن به‌عنوان خوانده‌شده ==============

// readChatRoomHandler اتاق را برای این بازیکن خوانده‌شده علامت می‌زند.
//
// POST /chat/read  {username, channel, peer_id?}
func readChatRoomHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "متد باید POST باشد", http.StatusMethodNotAllowed)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var body ChatReadBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httpError(w, "بدنه‌ی درخواست نامعتبر است", http.StatusBadRequest)
		return
	}

	viewer, err := getPlayerByUsername(ctx, body.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	room, _, denied := resolveChatRoom(ctx, viewer, body.Channel, body.PeerID)
	if denied != "" {
		httpError(w, denied, http.StatusForbidden)
		return
	}

	markChatRoomRead(ctx, viewer.PlayerID, room)
	jsonResponse(w, map[string]interface{}{"success": true, "room": room})
}
