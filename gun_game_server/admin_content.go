package main

import (
	"context"
	"net/http"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// پنل مدیریت — پیام به بازیکن‌ها، پشتیبانی، چت
// =============================================================================

const (
	adminSenderID   = "admin"
	adminSenderName = "پشتیبانی"

	// سقفِ جایزه‌ی یک پیام — جلوی صفرِ اضافه‌ی اشتباهی را می‌گیرد
	adminMaxRewardCoins = 1_000_000
	adminMaxRewardGems  = 10_000
	adminMaxRewardXP    = 1_000_000
)

// AdminCampaign یک ارسالِ گروهی یا همگانی از پنل
type AdminCampaign struct {
	CampaignID string         `bson:"_id" json:"campaign_id"`
	Target     string         `bson:"target" json:"target"` // players | all | active
	Title      string         `bson:"title" json:"title"`
	Body       string         `bson:"body" json:"body"`
	Reward     *MessageReward `bson:"reward,omitempty" json:"reward,omitempty"`
	Recipients int            `bson:"recipients" json:"recipients"`
	// BroadcastID پیامِ "*" (همگانیِ بدون جایزه)؛ خالی یعنی پیام‌ها تک‌به‌تک ساخته شده‌اند
	BroadcastID string     `bson:"broadcast_id,omitempty" json:"broadcast_id,omitempty"`
	ActiveDays  int        `bson:"active_days,omitempty" json:"active_days,omitempty"`
	CreatedBy   string     `bson:"created_by" json:"created_by"`
	CreatedAt   time.Time  `bson:"created_at" json:"created_at"`
	ExpiresAt   *time.Time `bson:"expires_at,omitempty" json:"expires_at,omitempty"`
	Revoked     bool       `bson:"revoked" json:"revoked"`
}

type adminSendRequest struct {
	Target     string `json:"target"`  // players | all | active
	Players    string `json:"players"` // آیدی یا نام، جدا با ویرگول یا خط جدید
	Title      string `json:"title"`
	Body       string `json:"body"`
	Coins      int    `json:"coins"`
	Gems       int    `json:"gems"`
	XP         int    `json:"xp"`
	ExpireDays int    `json:"expire_days"`
	ActiveDays int    `json:"active_days"`
}

func (req adminSendRequest) reward() *MessageReward {
	rw := &MessageReward{Coins: req.Coins, Gems: req.Gems, XP: req.XP, Items: []string{}}
	if rw.IsEmpty() {
		return nil
	}
	return rw
}

// resolvePlayers فهرستِ آیدی/نامِ واردشده را به بازیکن تبدیل می‌کند
func resolvePlayers(ctx context.Context, raw string) ([]PlayerModel, []string) {
	var found []PlayerModel
	var missing []string
	seen := map[string]bool{}
	for _, token := range strings.FieldsFunc(raw, func(r rune) bool { return r == ',' || r == '\n' || r == '،' }) {
		token = strings.TrimSpace(token)
		if token == "" {
			continue
		}
		p, err := getPlayerByID(ctx, token)
		if err != nil {
			p, err = getPlayerByUsername(ctx, token)
		}
		if err != nil {
			missing = append(missing, token)
			continue
		}
		if !seen[p.PlayerID] {
			seen[p.PlayerID] = true
			found = append(found, *p)
		}
	}
	return found, missing
}

// POST /admin/api/messages/send
//
// پیامِ همگانیِ بدون جایزه یک سندِ "*" است (همان سازوکارِ خوانده/حذف برای هر
// بازیکن). پیامِ جایزه‌دار باید برای هر نفر سندِ خودش را داشته باشد، چون قفلِ
// «یک بار دریافت» روی خودِ پیام است (claimOneMessage).
func adminSendMessageHandler(w http.ResponseWriter, r *http.Request) {
	var req adminSendRequest
	if !adminDecode(w, r, &req) {
		return
	}
	req.Title = strings.TrimSpace(req.Title)
	req.Body = strings.TrimSpace(req.Body)
	if req.Title == "" || req.Body == "" || len([]rune(req.Title)) > 80 || len([]rune(req.Body)) > 2000 {
		httpError(w, "عنوان (تا ۸۰ حرف) و متن (تا ۲۰۰۰ حرف) لازم است", http.StatusBadRequest)
		return
	}
	if req.Coins < 0 || req.Gems < 0 || req.XP < 0 ||
		req.Coins > adminMaxRewardCoins || req.Gems > adminMaxRewardGems || req.XP > adminMaxRewardXP {
		httpError(w, "مقدار جایزه خارج از محدوده است", http.StatusBadRequest)
		return
	}
	reward := req.reward()
	sess := adminFrom(r)
	if reward != nil && sess.Role != adminRoleAdmin {
		httpError(w, "فرستادنِ جایزه فقط برای مدیر کامل مجاز است", http.StatusForbidden)
		return
	}
	if req.ExpireDays <= 0 || req.ExpireDays > 365 {
		req.ExpireDays = 30
	}
	if req.Target != "players" && req.Target != "all" && req.Target != "active" {
		httpError(w, "گیرنده نامعتبر است", http.StatusBadRequest)
		return
	}
	if req.Target != "players" && sess.Role != adminRoleAdmin {
		httpError(w, "پیامِ همگانی فقط برای مدیر کامل مجاز است", http.StatusForbidden)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()
	now := time.Now()
	expires := now.AddDate(0, 0, req.ExpireDays)
	campaign := AdminCampaign{
		CampaignID: newID("camp"), Target: req.Target, Title: req.Title, Body: req.Body,
		Reward: reward, CreatedBy: sess.User, CreatedAt: now, ExpiresAt: &expires,
	}
	base := MessageModel{
		SenderID: adminSenderID, SenderName: adminSenderName, Type: MsgTypeAdmin,
		Title: req.Title, Body: req.Body, Reward: reward, RefID: campaign.CampaignID,
		CreatedAt: now, ExpiresAt: &expires,
	}

	var missing []string
	switch {
	case req.Target == "all" && reward == nil:
		msg := base
		msg.MessageID = newID("msg")
		msg.RecipientID = "*"
		if err := insertMessage(ctx, msg); err != nil {
			httpError(w, "ارسال نشد", http.StatusInternalServerError)
			return
		}
		campaign.BroadcastID = msg.MessageID
		campaign.Recipients = int(countOf(ctx, ColPlayers, humanPlayers))
		NotifyEveryone(map[string]interface{}{"type": "notification", "kind": MsgTypeAdmin})

	case req.Target == "players":
		players, miss := resolvePlayers(ctx, req.Players)
		missing = miss
		if len(players) == 0 {
			httpError(w, "هیچ بازیکنی پیدا نشد", http.StatusBadRequest)
			return
		}
		for _, p := range players {
			msg := base
			msg.MessageID = newID("msg")
			msg.RecipientID = p.PlayerID
			if err := insertMessage(ctx, msg); err == nil {
				campaign.Recipients++
				notifyAccountChanged(p.Username)
			}
		}

	default: // همه یا فعال‌ها، تک‌به‌تک
		filter := humans(nil)
		if req.Target == "active" {
			if req.ActiveDays <= 0 {
				req.ActiveDays = 7
			}
			campaign.ActiveDays = req.ActiveDays
			filter["last_seen_at"] = bson.M{"$gte": now.AddDate(0, 0, -req.ActiveDays)}
		}
		n, err := fanOutMessage(ctx, filter, base)
		if err != nil && n == 0 {
			httpError(w, "ارسال نشد", http.StatusInternalServerError)
			return
		}
		campaign.Recipients = n
		NotifyEveryone(map[string]interface{}{"type": "notification", "kind": MsgTypeAdmin})
	}

	_, _ = col(ColAdminCampaigns).InsertOne(ctx, campaign)
	audit(r, "message_send", campaign.CampaignID, map[string]interface{}{
		"target": req.Target, "title": req.Title, "recipients": campaign.Recipients,
		"coins": req.Coins, "gems": req.Gems, "xp": req.XP, "players": req.Players,
	})
	jsonResponse(w, map[string]interface{}{"success": true, "campaign": campaign, "missing": missing})
}

// fanOutMessage برای هر بازیکنِ فیلتر یک نسخه‌ی جدا می‌سازد (دسته‌های ۵۰۰تایی)
func fanOutMessage(ctx context.Context, filter bson.M, base MessageModel) (int, error) {
	cur, err := col(ColPlayers).Find(ctx, filter, options.Find().SetProjection(bson.M{"player_id": 1}))
	if err != nil {
		return 0, err
	}
	defer cur.Close(ctx)
	total := 0
	batch := make([]interface{}, 0, 500)
	flush := func() error {
		if len(batch) == 0 {
			return nil
		}
		res, err := col(ColMessages).InsertMany(ctx, batch, options.InsertMany().SetOrdered(false))
		if res != nil {
			total += len(res.InsertedIDs)
		}
		batch = batch[:0]
		return err
	}
	for cur.Next(ctx) {
		var row struct {
			PlayerID string `bson:"player_id"`
		}
		if cur.Decode(&row) != nil || row.PlayerID == "" {
			continue
		}
		msg := base
		msg.MessageID = newID("msg")
		msg.RecipientID = row.PlayerID
		batch = append(batch, msg)
		if len(batch) == cap(batch) {
			if err := flush(); err != nil {
				return total, err
			}
		}
	}
	return total, flush()
}

// GET /admin/api/messages/campaigns?page=
func adminCampaignsHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	page, size := adminPage(r, 20)
	cur, err := col(ColAdminCampaigns).Find(ctx, bson.M{}, findPage(page, size, bson.D{{Key: "created_at", Value: -1}}))
	if err != nil {
		httpError(w, "خطا در خواندن", http.StatusInternalServerError)
		return
	}
	var camps []AdminCampaign
	_ = cur.All(ctx, &camps)
	rows := make([]map[string]interface{}, 0, len(camps))
	for _, c := range camps {
		row := map[string]interface{}{"campaign": c}
		if c.BroadcastID != "" {
			row["read"] = countOf(ctx, ColPlayers, bson.M{"read_broadcasts": c.BroadcastID})
		} else {
			row["read"] = countOf(ctx, ColMessages, bson.M{"ref_id": c.CampaignID, "is_read": true})
			if c.Reward != nil {
				row["claimed"] = countOf(ctx, ColMessages, bson.M{"ref_id": c.CampaignID, "reward_claimed": true})
			}
		}
		rows = append(rows, row)
	}
	jsonResponse(w, map[string]interface{}{"campaigns": rows, "total": countOf(ctx, ColAdminCampaigns, bson.M{}), "page": page, "size": size})
}

// POST /admin/api/messages/revoke {"campaign_id"} — پیام‌های هنوز باقی‌مانده پاک می‌شوند.
// جایزه‌ای که قبلاً دریافت شده برنمی‌گردد.
func adminRevokeCampaignHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CampaignID string `json:"campaign_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()
	var camp AdminCampaign
	if err := col(ColAdminCampaigns).FindOne(ctx, bson.M{"_id": req.CampaignID}).Decode(&camp); err != nil {
		httpError(w, "پیدا نشد", http.StatusNotFound)
		return
	}
	if camp.Target != "players" && adminFrom(r).Role != adminRoleAdmin {
		httpError(w, "فقط مدیر کامل", http.StatusForbidden)
		return
	}
	res, err := col(ColMessages).DeleteMany(ctx, bson.M{"ref_id": camp.CampaignID, "sender_id": adminSenderID})
	if err != nil {
		httpError(w, "حذف نشد", http.StatusInternalServerError)
		return
	}
	_, _ = col(ColAdminCampaigns).UpdateOne(ctx, bson.M{"_id": camp.CampaignID}, bson.M{"$set": bson.M{"revoked": true}})
	audit(r, "message_revoke", camp.CampaignID, map[string]interface{}{"deleted": res.DeletedCount, "title": camp.Title})
	jsonResponse(w, map[string]interface{}{"success": true, "deleted": res.DeletedCount})
}

// ------------------------------------------------------------ پشتیبانی

// GET /admin/api/support?status=&q=&page=
func adminSupportListHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	q := r.URL.Query()
	filter := bson.M{}
	switch status := q.Get("status"); status {
	case "", "all":
	case "open":
		filter["status"] = bson.M{"$in": []string{SupportStatusNew, SupportStatusRead}}
	default:
		filter["status"] = status
	}
	if s := strings.TrimSpace(q.Get("q")); s != "" {
		filter["$or"] = []bson.M{
			{"username": bson.M{"$regex": regexEscape(s), "$options": "i"}},
			{"player_id": s},
			{"body": bson.M{"$regex": regexEscape(s), "$options": "i"}},
		}
	}
	page, size := adminPage(r, 30)
	cur, err := col(ColSupportMsgs).Find(ctx, filter, findPage(page, size, bson.D{{Key: "created_at", Value: -1}}))
	if err != nil {
		httpError(w, "خطا در خواندن", http.StatusInternalServerError)
		return
	}
	tickets := []SupportMessageModel{}
	_ = cur.All(ctx, &tickets)
	counts := map[string]int64{}
	for _, s := range []string{SupportStatusNew, SupportStatusRead, SupportStatusAnswered, SupportStatusClosed} {
		counts[s] = countOf(ctx, ColSupportMsgs, bson.M{"status": s})
	}
	jsonResponse(w, map[string]interface{}{
		"tickets": tickets, "total": countOf(ctx, ColSupportMsgs, filter), "counts": counts, "page": page, "size": size,
	})
}

// GET /admin/api/support/ticket?ticket_id= — با باز شدن، «جدید» به «خوانده‌شده» می‌رود
func adminSupportTicketHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	id := r.URL.Query().Get("ticket_id")
	var t SupportMessageModel
	if err := col(ColSupportMsgs).FindOne(ctx, bson.M{"ticket_id": id}).Decode(&t); err != nil {
		httpError(w, "پیدا نشد", http.StatusNotFound)
		return
	}
	if t.Status == SupportStatusNew {
		now := time.Now()
		_, _ = col(ColSupportMsgs).UpdateOne(ctx, bson.M{"ticket_id": id, "status": SupportStatusNew},
			bson.M{"$set": bson.M{"status": SupportStatusRead, "updated_at": now}})
		t.Status = SupportStatusRead
	}
	var player map[string]interface{}
	if p, err := getPlayerByID(ctx, t.PlayerID); err == nil {
		player = adminPlayerRow(*p)
	}
	history := findAll[SupportMessageModel](ctx, ColSupportMsgs,
		bson.M{"player_id": t.PlayerID, "ticket_id": bson.M{"$ne": id}}, "created_at", 20)
	jsonResponse(w, map[string]interface{}{"ticket": t, "player": player, "history": history})
}

// POST /admin/api/support/reply {"ticket_id","body","coins","gems","close"}
// پاسخ به‌صورت پیامِ «پشتیبانی» در صندوقِ خودِ بازیکن می‌نشیند.
func adminSupportReplyHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		TicketID string `json:"ticket_id"`
		Body     string `json:"body"`
		Coins    int    `json:"coins"`
		Gems     int    `json:"gems"`
		Close    bool   `json:"close"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	req.Body = strings.TrimSpace(req.Body)
	if req.Body == "" || len([]rune(req.Body)) > 2000 {
		httpError(w, "متن پاسخ لازم است (تا ۲۰۰۰ حرف)", http.StatusBadRequest)
		return
	}
	sess := adminFrom(r)
	if req.Coins < 0 || req.Gems < 0 || req.Coins > adminMaxRewardCoins || req.Gems > adminMaxRewardGems {
		httpError(w, "مقدار جایزه نامعتبر است", http.StatusBadRequest)
		return
	}
	if (req.Coins > 0 || req.Gems > 0) && sess.Role != adminRoleAdmin {
		httpError(w, "فرستادنِ جایزه فقط برای مدیر کامل مجاز است", http.StatusForbidden)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	var t SupportMessageModel
	if err := col(ColSupportMsgs).FindOne(ctx, bson.M{"ticket_id": req.TicketID}).Decode(&t); err != nil {
		httpError(w, "پیدا نشد", http.StatusNotFound)
		return
	}
	p, err := getPlayerByID(ctx, t.PlayerID)
	if err != nil {
		httpError(w, "بازیکنِ این پیام دیگر وجود ندارد", http.StatusNotFound)
		return
	}

	now := time.Now()
	expires := now.AddDate(0, 0, 60)
	quote := []rune(t.Body)
	if len(quote) > 120 {
		quote = append(quote[:120], '…')
	}
	msg := MessageModel{
		MessageID: newID("msg"), RecipientID: p.PlayerID,
		SenderID: adminSenderID, SenderName: adminSenderName, Type: MsgTypeAdmin,
		Title: "پاسخ پشتیبانی",
		Body:  req.Body + "\n\n— در پاسخ به: «" + string(quote) + "»",
		RefID: t.TicketID, CreatedAt: now, ExpiresAt: &expires,
	}
	if req.Coins > 0 || req.Gems > 0 {
		msg.Reward = &MessageReward{Coins: req.Coins, Gems: req.Gems, Items: []string{}}
	}
	if err := insertMessage(ctx, msg); err != nil {
		httpError(w, "ارسال نشد", http.StatusInternalServerError)
		return
	}
	status := SupportStatusAnswered
	if req.Close {
		status = SupportStatusClosed
	}
	reply := SupportReply{By: sess.User, Body: req.Body, MessageID: msg.MessageID, At: now}
	_, _ = col(ColSupportMsgs).UpdateOne(ctx, bson.M{"ticket_id": t.TicketID}, bson.M{
		"$push": bson.M{"replies": reply},
		"$set":  bson.M{"status": status, "updated_at": now},
	})
	notifyAccountChanged(p.Username)
	audit(r, "support_reply", p.PlayerID, map[string]interface{}{"ticket_id": t.TicketID, "coins": req.Coins, "gems": req.Gems})
	jsonResponse(w, map[string]interface{}{"success": true, "reply": reply, "status": status})
}

// POST /admin/api/support/status {"ticket_id","status"}
func adminSupportStatusHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		TicketID string `json:"ticket_id"`
		Status   string `json:"status"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	switch req.Status {
	case SupportStatusNew, SupportStatusRead, SupportStatusAnswered, SupportStatusClosed:
	default:
		httpError(w, "وضعیت نامعتبر", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	res, err := col(ColSupportMsgs).UpdateOne(ctx, bson.M{"ticket_id": req.TicketID},
		bson.M{"$set": bson.M{"status": req.Status, "updated_at": time.Now()}})
	if err != nil || res.MatchedCount == 0 {
		httpError(w, "پیدا نشد", http.StatusNotFound)
		return
	}
	audit(r, "support_status", req.TicketID, map[string]interface{}{"status": req.Status})
	jsonResponse(w, map[string]bool{"success": true})
}

// ------------------------------------------------------------ چت

// GET /admin/api/chat?channel=&room=&player_id=&q=&before=
func adminChatHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	q := r.URL.Query()
	filter := bson.M{}
	// چتِ خصوصی (دو نفره) فقط برای مدیر کامل باز است
	private := q.Get("channel") == ChatChannelPrivate || strings.HasPrefix(q.Get("room"), "dm:")
	if private && adminFrom(r).Role != adminRoleAdmin {
		httpError(w, "چتِ خصوصی فقط برای مدیر کامل قابل دیدن است", http.StatusForbidden)
		return
	}
	if ch := q.Get("channel"); ch != "" {
		filter["channel"] = ch
	} else if adminFrom(r).Role != adminRoleAdmin {
		filter["channel"] = bson.M{"$in": []string{ChatChannelGlobal, ChatChannelCity}}
	}
	if room := q.Get("room"); room != "" {
		filter["room"] = room
	}
	if pid := q.Get("player_id"); pid != "" {
		filter["sender_id"] = pid
	}
	if s := strings.TrimSpace(q.Get("q")); s != "" {
		filter["text"] = bson.M{"$regex": regexEscape(s), "$options": "i"}
	}
	if before, err := time.Parse(time.RFC3339Nano, q.Get("before")); err == nil {
		filter["created_at"] = bson.M{"$lt": before}
	}
	cur, err := col(ColChatMessages).Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(100))
	if err != nil {
		httpError(w, "خطا در خواندن", http.StatusInternalServerError)
		return
	}
	msgs := []ChatMessageModel{}
	_ = cur.All(ctx, &msgs)

	// نام شهرها برای اتاق‌های city:<clan_id>
	clanIDs := []string{}
	for _, m := range msgs {
		if strings.HasPrefix(m.Room, "city:") {
			clanIDs = append(clanIDs, strings.TrimPrefix(m.Room, "city:"))
		}
	}
	jsonResponse(w, map[string]interface{}{"messages": msgs, "clan_names": clanNamesFor(ctx, clanIDs)})
}

// POST /admin/api/chat/delete {"message_id"} یا {"player_id","all":true} (پاکسازیِ همه‌ی پیام‌های عمومیِ یک نفر)
func adminChatDeleteHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		MessageID string `json:"message_id"`
		PlayerID  string `json:"player_id"`
		All       bool   `json:"all"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	var res *mongo.DeleteResult
	var err error
	if req.All && req.PlayerID != "" {
		res, err = col(ColChatMessages).DeleteMany(ctx, bson.M{
			"sender_id": req.PlayerID,
			"channel":   bson.M{"$in": []string{ChatChannelGlobal, ChatChannelCity}},
		})
		audit(r, "chat_purge", req.PlayerID, nil)
	} else {
		var msg ChatMessageModel
		if e := col(ColChatMessages).FindOne(ctx, bson.M{"message_id": req.MessageID}).Decode(&msg); e != nil {
			httpError(w, "پیدا نشد", http.StatusNotFound)
			return
		}
		res, err = col(ColChatMessages).DeleteOne(ctx, bson.M{"message_id": req.MessageID})
		audit(r, "chat_delete", msg.SenderID, map[string]interface{}{"room": msg.Room, "text": msg.Text})
	}
	if err != nil {
		httpError(w, "حذف نشد", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, map[string]interface{}{"success": true, "deleted": res.DeletedCount})
}
