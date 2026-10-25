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
// پنل مدیریت — کد هدیه، خریدها، شهرها، حالت‌های بازی، فروشگاه
// =============================================================================

// ------------------------------------------------------------ کد هدیه

// GET /admin/api/gift_codes
func adminGiftCodesHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	codes := findAll[GiftCode](ctx, ColGiftCodes, bson.M{}, "created_at", 300)
	jsonResponse(w, map[string]interface{}{"codes": codes})
}

// POST /admin/api/gift_codes/create — همان بدنه‌ی /admin/gift_codes/create
func adminGiftCodeCreateHandler(w http.ResponseWriter, r *http.Request) {
	var req createGiftCodeRequest
	if !adminDecode(w, r, &req) {
		return
	}
	if req.Coins > adminMaxRewardCoins || req.Gems > adminMaxRewardGems {
		httpError(w, "مقدار جایزه خارج از محدوده است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	gift, msg, status := createGiftCode(ctx, req)
	if msg != "" {
		httpError(w, msg, status)
		return
	}
	audit(r, "gift_code_create", gift.Code, map[string]interface{}{
		"coins": gift.Coins, "gems": gift.Gems, "max_uses": gift.MaxUses, "expires_in_hours": req.ExpiresInHours,
	})
	jsonResponse(w, map[string]interface{}{"success": true, "code": gift})
}

// POST /admin/api/gift_codes/toggle {"code","active"}
func adminGiftCodeToggleHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code   string `json:"code"`
		Active bool   `json:"active"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	code := normalizeGiftCode(req.Code)
	res, err := col(ColGiftCodes).UpdateOne(ctx, bson.M{"_id": code}, bson.M{"$set": bson.M{"active": req.Active}})
	if err != nil || res.MatchedCount == 0 {
		httpError(w, "کد پیدا نشد", http.StatusNotFound)
		return
	}
	audit(r, "gift_code_toggle", code, map[string]interface{}{"active": req.Active})
	jsonResponse(w, map[string]bool{"success": true})
}

// GET /admin/api/gift_codes/redemptions?code=
func adminGiftCodeRedemptionsHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	code := normalizeGiftCode(r.URL.Query().Get("code"))
	rows := findAll[bson.M](ctx, ColGiftRedemptions, bson.M{"code": code}, "created_at", 300)
	ids := make([]string, 0, len(rows))
	for _, row := range rows {
		if id, ok := row["player_id"].(string); ok {
			ids = append(ids, id)
		}
	}
	names := map[string]string{}
	for _, p := range findPlayersByIDs(ctx, ids) {
		names[p.PlayerID] = p.Username
	}
	for _, row := range rows {
		if id, ok := row["player_id"].(string); ok {
			row["username"] = names[id]
		}
	}
	jsonResponse(w, map[string]interface{}{"redemptions": rows})
}

// ------------------------------------------------------------ خریدها

func iapRow(p IAPPurchase) map[string]interface{} {
	toman := 0
	if pack, ok := findGemPackByProduct(p.ProductID); ok {
		toman = pack.FinalPrice()
	}
	return map[string]interface{}{
		"id": p.ID, "store": p.Store, "product_id": p.ProductID, "player_id": p.PlayerID,
		"username": p.Username, "gems": p.Gems, "state": p.State, "created_at": p.CreatedAt,
		"token": p.PurchaseToken, "toman_estimate": toman,
	}
}

// GET /admin/api/purchases?q=&store=&state=&page=
func adminPurchasesHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	q := r.URL.Query()
	filter := bson.M{}
	if s := q.Get("store"); s != "" {
		filter["store"] = s
	}
	if s := q.Get("state"); s != "" {
		filter["state"] = s
	}
	if s := strings.TrimSpace(q.Get("q")); s != "" {
		filter["$or"] = []bson.M{
			{"username": bson.M{"$regex": regexEscape(s), "$options": "i"}},
			{"player_id": s}, {"purchase_token": s}, {"product_id": s},
		}
	}
	page, size := adminPage(r, 40)
	cur, err := col(ColIAPPurchases).Find(ctx, filter, findPage(page, size, bson.D{{Key: "created_at", Value: -1}}))
	if err != nil {
		httpError(w, "خطا در خواندن", http.StatusInternalServerError)
		return
	}
	var purchases []IAPPurchase
	_ = cur.All(ctx, &purchases)
	rows := make([]map[string]interface{}, 0, len(purchases))
	for _, p := range purchases {
		rows = append(rows, iapRow(p))
	}

	// جمعِ کل بر اساس محصول (فقط واریزشده‌ها)
	byProduct := []bson.M{}
	agg, err := col(ColIAPPurchases).Aggregate(ctx, []bson.M{
		{"$match": bson.M{"state": "credited"}},
		{"$group": bson.M{"_id": bson.M{"product": "$product_id", "store": "$store"}, "count": bson.M{"$sum": 1}, "gems": bson.M{"$sum": "$gems"}}},
		{"$sort": bson.M{"count": -1}},
	})
	if err == nil {
		_ = agg.All(ctx, &byProduct)
	}
	for _, row := range byProduct {
		if id, ok := row["_id"].(bson.M); ok {
			if pid, ok := id["product"].(string); ok {
				if pack, ok := findGemPackByProduct(pid); ok {
					row["unit_toman"] = pack.FinalPrice()
				}
			}
		}
	}
	jsonResponse(w, map[string]interface{}{
		"purchases": rows, "total": countOf(ctx, ColIAPPurchases, filter), "page": page, "size": size,
		"by_product": byProduct,
	})
}

// ------------------------------------------------------------ شهرها

// GET /admin/api/clans?q=&page=
func adminClansHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	filter := bson.M{}
	if s := strings.TrimSpace(r.URL.Query().Get("q")); s != "" {
		filter["$or"] = []bson.M{
			{"name": bson.M{"$regex": regexEscape(s), "$options": "i"}},
			{"tag": bson.M{"$regex": regexEscape(s), "$options": "i"}},
			{"clan_id": s},
		}
	}
	page, size := adminPage(r, 30)
	cur, err := col(ColClans).Find(ctx, filter, findPage(page, size, bson.D{{Key: "created_at", Value: -1}}))
	if err != nil {
		httpError(w, "خطا در خواندن", http.StatusInternalServerError)
		return
	}
	var clans []ClanModel
	_ = cur.All(ctx, &clans)
	rows := make([]map[string]interface{}, 0, len(clans))
	for i := range clans {
		row := clanSummary(&clans[i])
		name, _ := clanLeaderInfo(&clans[i])
		row["leader"] = name
		rows = append(rows, row)
	}
	jsonResponse(w, map[string]interface{}{"clans": rows, "total": countOf(ctx, ColClans, filter), "page": page, "size": size})
}

// GET /admin/api/clan?clan_id=
func adminClanHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	clan, err := getClanByID(ctx, r.URL.Query().Get("clan_id"))
	if err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}
	ids := make([]string, 0, len(clan.Members))
	for _, m := range clan.Members {
		ids = append(ids, m.PlayerID)
	}
	byID := map[string]PlayerModel{}
	for _, p := range findPlayersByIDs(ctx, ids) {
		byID[p.PlayerID] = p
	}
	members := make([]map[string]interface{}, 0, len(clan.Members))
	for _, m := range clan.Members {
		row := map[string]interface{}{"player_id": m.PlayerID, "username": m.Username, "role": m.Role, "joined_at": m.JoinedAt}
		if p, ok := byID[m.PlayerID]; ok {
			row["level"] = p.Level
			row["trophies"] = p.Trophies
			row["is_online"] = p.IsOnline
			row["last_seen_at"] = p.LastSeenAt
		}
		members = append(members, row)
	}
	requests := findAll[ClanJoinRequestModel](ctx, ColClanRequests, bson.M{"clan_id": clan.ClanID, "status": "pending"}, "created_at", 50)
	jsonResponse(w, map[string]interface{}{"clan": clanSummary(clan), "members": members, "requests": requests})
}

// POST /admin/api/clan/update {"clan_id","name","tag","description","is_public","min_level","max_members"}
func adminClanUpdateHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClanID      string  `json:"clan_id"`
		Name        *string `json:"name"`
		Tag         *string `json:"tag"`
		Description *string `json:"description"`
		IsPublic    *bool   `json:"is_public"`
		MinLevel    *int    `json:"min_level"`
		MaxMembers  *int    `json:"max_members"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	set := bson.M{}
	if req.Name != nil {
		name := strings.TrimSpace(*req.Name)
		if n := len([]rune(name)); n < ClanMinNameLen || n > ClanMaxNameLen {
			httpError(w, "طول نام شهر نامعتبر است", http.StatusBadRequest)
			return
		}
		set["name"] = name
	}
	if req.Tag != nil {
		tag := strings.ToUpper(strings.TrimSpace(*req.Tag))
		if n := len([]rune(tag)); n < ClanMinTagLen || n > ClanMaxTagLen {
			httpError(w, "طول تگ نامعتبر است", http.StatusBadRequest)
			return
		}
		set["tag"] = tag
	}
	if req.Description != nil {
		set["description"] = strings.TrimSpace(*req.Description)
	}
	if req.IsPublic != nil {
		set["is_public"] = *req.IsPublic
	}
	if req.MinLevel != nil && *req.MinLevel >= 0 {
		set["min_level"] = *req.MinLevel
	}
	if req.MaxMembers != nil {
		if *req.MaxMembers < 1 || *req.MaxMembers > 200 {
			httpError(w, "ظرفیت باید بین ۱ تا ۲۰۰ باشد", http.StatusBadRequest)
			return
		}
		set["max_members"] = *req.MaxMembers
	}
	if len(set) == 0 {
		httpError(w, "تغییری نیست", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	res, err := col(ColClans).UpdateOne(ctx, bson.M{"clan_id": req.ClanID}, bson.M{"$set": set})
	if mongo.IsDuplicateKeyError(err) {
		httpError(w, "این نام یا تگ مال شهر دیگری است", http.StatusConflict)
		return
	}
	if err != nil || res.MatchedCount == 0 {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}
	if clan, err := getClanByID(ctx, req.ClanID); err == nil {
		notifyClanChanged(clan)
	}
	audit(r, "clan_update", req.ClanID, set)
	jsonResponse(w, map[string]bool{"success": true})
}

// POST /admin/api/clan/kick {"clan_id","player_id"} — رهبر هم قابل اخراج است و
// رهبری به جانشین می‌رسد؛ اگر آخرین نفر باشد شهر منحل می‌شود.
func adminClanKickHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClanID   string `json:"clan_id"`
		PlayerID string `json:"player_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	clan, err := getClanByID(ctx, req.ClanID)
	if err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}
	role := clanMemberRole(clan, req.PlayerID)
	if role == "" {
		httpError(w, "این بازیکن عضو این شهر نیست", http.StatusBadRequest)
		return
	}
	if clan.MemberCount() <= 1 {
		disbandClan(ctx, clan)
		audit(r, "clan_disband", clan.ClanID, map[string]interface{}{"name": clan.Name, "via": "kick_last"})
		jsonResponse(w, map[string]interface{}{"success": true, "dissolved": true})
		return
	}
	if _, err := col(ColClans).UpdateOne(ctx, bson.M{"clan_id": clan.ClanID},
		bson.M{"$pull": bson.M{"members": bson.M{"player_id": req.PlayerID}}}); err != nil {
		httpError(w, "خطا در اخراج", http.StatusInternalServerError)
		return
	}
	_ = setPlayerClan(ctx, req.PlayerID, "", "")
	successor := ""
	if role == ClanRoleLeader {
		successor = promoteSuccessor(ctx, clan, req.PlayerID)
	}
	notifyClanChanged(clan)
	audit(r, "clan_kick", req.ClanID, map[string]interface{}{"player_id": req.PlayerID, "new_leader": successor})
	jsonResponse(w, map[string]interface{}{"success": true, "new_leader": successor})
}

// disbandClan همه‌ی اعضا آزاد و شهر و درخواست‌هایش پاک می‌شوند
func disbandClan(ctx context.Context, clan *ClanModel) {
	_, _ = col(ColPlayers).UpdateMany(ctx, bson.M{"clan_id": clan.ClanID},
		bson.M{"$set": bson.M{"clan_id": "", "clan_role": "", "updated_at": time.Now()}})
	_, _ = col(ColClans).DeleteOne(ctx, bson.M{"clan_id": clan.ClanID})
	_, _ = col(ColClanRequests).DeleteMany(ctx, bson.M{"clan_id": clan.ClanID})
	notifyClanChanged(clan)
}

// POST /admin/api/clan/disband {"clan_id"}
func adminClanDisbandHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ClanID string `json:"clan_id"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	clan, err := getClanByID(ctx, req.ClanID)
	if err != nil {
		httpError(w, "شهر پیدا نشد", http.StatusNotFound)
		return
	}
	disbandClan(ctx, clan)
	audit(r, "clan_disband", clan.ClanID, map[string]interface{}{"name": clan.Name, "members": clan.MemberCount()})
	jsonResponse(w, map[string]bool{"success": true})
}

// ------------------------------------------------------------ حالت‌های بازی

// GET /admin/api/modes
func adminModesHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	modes := []GameModeDef{}
	cur, err := col(ColGameModes).Find(ctx, bson.M{}, options.Find().SetSort(bson.D{{Key: "sort_order", Value: 1}}))
	if err == nil {
		_ = cur.All(ctx, &modes)
	}
	jsonResponse(w, map[string]interface{}{"modes": modes})
}

// POST /admin/api/modes/update {"mode_id", ...فیلدهای عددی/متنی}
// ساختارِ حالت (team_size و قانون راند) از کد می‌آید و اینجا قابل تغییر نیست.
func adminModeUpdateHandler(w http.ResponseWriter, r *http.Request) {
	var req map[string]interface{}
	if !adminDecode(w, r, &req) {
		return
	}
	modeID, _ := req["mode_id"].(string)
	intFields := []string{"win_trophies", "win_coins", "win_xp", "lose_trophies", "lose_coins", "lose_xp", "min_trophies", "sort_order"}
	strFields := []string{"name", "subtitle", "description"}
	set := bson.M{}
	for _, f := range intFields {
		if v, ok := req[f].(float64); ok {
			if v < 0 || v > 1_000_000 || v != float64(int(v)) {
				httpError(w, "عدد نامعتبر برای "+f, http.StatusBadRequest)
				return
			}
			set[f] = int(v)
		}
	}
	for _, f := range strFields {
		if v, ok := req[f].(string); ok {
			v = strings.TrimSpace(v)
			if v == "" && f == "name" {
				httpError(w, "نام خالی است", http.StatusBadRequest)
				return
			}
			set[f] = v
		}
	}
	if v, ok := req["is_active"].(bool); ok {
		set["is_active"] = v
	}
	if len(set) == 0 {
		httpError(w, "تغییری نیست", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	res, err := col(ColGameModes).UpdateOne(ctx, bson.M{"mode_id": modeID}, bson.M{"$set": set})
	if err != nil || res.MatchedCount == 0 {
		httpError(w, "حالت پیدا نشد", http.StatusNotFound)
		return
	}
	audit(r, "mode_update", modeID, set)
	jsonResponse(w, map[string]bool{"success": true})
}

// ------------------------------------------------------------ فروشگاه

// GET /admin/api/shop
func adminShopHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	items := []ShopItem{}
	cur, err := col(ColShopItems).Find(ctx, bson.M{}, options.Find().SetSort(bson.D{{Key: "section", Value: 1}, {Key: "category", Value: 1}}))
	if err == nil {
		_ = cur.All(ctx, &items)
	}
	for i := range items {
		items[i].CalculateFinalPrice()
	}
	// چند نفر هر آیتم را دارند — برای تصمیمِ تخفیف
	owners := map[string]int64{}
	for _, it := range items {
		switch it.Category {
		case "weapon":
			owners[it.ItemID] = countOf(ctx, ColPlayers, humans(bson.M{"owned_weapons": it.ItemID}))
		case "character":
			owners[it.ItemID] = countOf(ctx, ColPlayers, humans(bson.M{"owned_characters": it.ItemID}))
		}
	}
	jsonResponse(w, map[string]interface{}{"items": items, "owners": owners})
}

// POST /admin/api/shop/update {"item_id","discount_percent","featured_section"}
// قیمتِ پایه عمداً از کد می‌آید (pricing.go / store_currency.go) و هر بوت
// بازنویسی می‌شود؛ تخفیف و ویترین از دیتابیس است و می‌ماند.
func adminShopUpdateHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ItemID          string  `json:"item_id"`
		DiscountPercent *int    `json:"discount_percent"`
		FeaturedSection *string `json:"featured_section"`
	}
	if !adminDecode(w, r, &req) {
		return
	}
	set := bson.M{}
	if req.DiscountPercent != nil {
		if *req.DiscountPercent < 0 || *req.DiscountPercent > 90 {
			httpError(w, "تخفیف باید بین ۰ تا ۹۰ درصد باشد", http.StatusBadRequest)
			return
		}
		set["discount_percent"] = *req.DiscountPercent
	}
	update := bson.M{}
	if req.FeaturedSection != nil {
		switch fs := strings.TrimSpace(*req.FeaturedSection); fs {
		case "":
			update["$unset"] = bson.M{"featured_section": ""}
		case "weekly", "very_special":
			set["featured_section"] = fs
		default:
			httpError(w, "ویترین نامعتبر است", http.StatusBadRequest)
			return
		}
	}
	if len(set) > 0 {
		update["$set"] = set
	}
	if len(update) == 0 {
		httpError(w, "تغییری نیست", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	var item ShopItem
	if err := col(ColShopItems).FindOneAndUpdate(ctx, bson.M{"item_id": req.ItemID}, update,
		options.FindOneAndUpdate().SetReturnDocument(options.After)).Decode(&item); err != nil {
		httpError(w, "آیتم پیدا نشد", http.StatusNotFound)
		return
	}
	// final_price ذخیره‌شده را هم هم‌سو کن (بعضی مسیرها آن را مستقیم می‌خوانند)
	item.CalculateFinalPrice()
	_, _ = col(ColShopItems).UpdateOne(ctx, bson.M{"item_id": req.ItemID}, bson.M{"$set": bson.M{"final_price": item.FinalPrice}})
	audit(r, "shop_update", req.ItemID, map[string]interface{}{"discount_percent": req.DiscountPercent, "featured_section": req.FeaturedSection})
	jsonResponse(w, map[string]interface{}{"success": true, "item": item})
}
