package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// ============== Helper Functions ==============

// enableCORS CORS headers را برای پاسخ HTTP اضافه می‌کند
func enableCORS(w *http.ResponseWriter) {
	(*w).Header().Set("Access-Control-Allow-Origin", "*")
	(*w).Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	(*w).Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Device")
}

// httpError خطا را به صورت JSON ارسال می‌کند
func httpError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}

// jsonResponse داده‌ها را به صورت JSON ارسال می‌کند
func jsonResponse(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(data)
}

// ============== HTTP Handlers ==============

// getPlayerHandler اطلاعات بازیکن را بازیابی می‌کند یا بازیکن جدید ایجاد می‌کند
// درخواست: GET /get_player?username=<username>
// پاسخ: اطلاعات بازیکن (سکه، جم، سطح، تجربه، آیتم‌های مالک‌شده)
func getPlayerHandler(w http.ResponseWriter, r *http.Request) {
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

	playersCol := col(ColPlayers)
	var player PlayerModel
	created := false

	// جستجو برای بازیکن موجود
	err := playersCol.FindOne(ctx, bson.M{"username": username}).Decode(&player)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			// اسمِ حسابِ *تازه* باید همان قانونِ تغییرِ نام را رد کند
			// (handlers_social.go). قبلاً هیچ بررسی‌ای نبود، پس با یک
			// درخواست می‌شد حسابی با اسمِ یک‌مگابایتی یا پر از کاراکترِ
			// کنترلی ساخت. حساب‌های *موجود* از این رد نمی‌شوند تا اسم‌های
			// قدیمی که قبل از این قانون ساخته شده‌اند از کار نیفتند.
			if msg := validateUsername(username); msg != "" {
				httpError(w, msg, http.StatusBadRequest)
				return
			}
			created = true
			// بازیکن جدید: ساخت آیدی عمومی یکتا + مقادیر پیش‌فرض
			playerID, idErr := GenerateUniquePlayerID(ctx)
			if idErr != nil {
				httpError(w, "خطا در ساخت آیدی بازیکن", http.StatusInternalServerError)
				return
			}

			player = NewDefaultPlayer(username, playerID)

			_, err = playersCol.InsertOne(ctx, player)
			if err != nil {
				httpError(w, "خطا در ساخت اکانت جدید", http.StatusInternalServerError)
				return
			}
			fmt.Printf("🌟 اکانت جدید ساخته شد: %s (ID: %s)\n", username, playerID)

			// پیام خوش‌آمدگویی در صندوق پیام‌ها
			_ = insertMessage(ctx, MessageModel{
				RecipientID: playerID,
				SenderID:    "system",
				SenderName:  "بازی",
				Type:        MsgTypeSystem,
				Title:       "پیام از بازی",
				Body:        "سلام امیدوارم که حال دلت خوش باشه. این پیام از طرف بازیه! موفق باشی :)",
			})
		} else {
			httpError(w, "خطا در بازیابی اطلاعات بازیکن", http.StatusInternalServerError)
			return
		}
	}

	// توکن دستگاه (handlers_auth.go): حساب تازه همین‌جا اولین دستگاهش را
	// می‌گیرد؛ حساب قدیمی‌ای که هنوز هیچ دستگاهی ندارد، اولین دستگاهی که
	// بیاید مالکش می‌شود. توکن فقط همین یک بار در پاسخ می‌آید.
	sessionToken := ""
	if created {
		sessionToken, _ = issueSession(ctx, player.PlayerID, deviceName(r))
	} else if len(player.Auth.Sessions) == 0 && !isProtected(player.Auth) {
		sessionToken, _ = claimFirstSession(ctx, player.PlayerID, deviceName(r))
	}

	// ثبت وضعیت آنلاین
	_, _ = playersCol.UpdateOne(ctx, bson.M{"username": username},
		bson.M{"$set": bson.M{"is_online": true, "last_seen_at": time.Now(), "auth.last_login_at": time.Now()}})

	// محاسبه سطح براساس تجربه
	// هر سطح نیاز به (سطح * ۱۰۰) تجربه دارد
	currentLevel := 1
	currentXp := player.Experience

	for {
		maxXp := currentLevel * 100
		if currentXp >= maxXp {
			currentXp -= maxXp
			currentLevel++
		} else {
			break
		}
	}

	finalMaxXp := currentLevel * 100

	// بروزرسانی سطح در دیتابیس اگر تغیر کرده باشد
	if currentLevel != player.Level {
		player.Level = currentLevel
		_, _ = playersCol.UpdateOne(ctx, bson.M{"username": username}, bson.M{"$set": bson.M{"level": currentLevel}})
	}

	// تعداد پیام‌های خوانده‌نشده (بج روی آیکن نامه در نوار بالا)
	unread := countUnreadMessages(ctx, &player)

	// پاسخ نهایی
	responseData := map[string]interface{}{
		"player_id":          player.PlayerID,
		"username":           player.Username,
		"avatar_id":          player.AvatarID,
		"frame_id":           player.FrameID,
		"coins":              player.Coins,
		"gems":               player.Gems,
		"level":              player.Level,
		"display_xp":         currentXp,  // تجربه نمایشی برای سطح فعلی
		"max_xp":             finalMaxXp, // حداکثر تجربه برای سطح فعلی
		"owned_weapons":      player.OwnedWeapons,
		"owned_characters":   player.OwnedCharacters,
		"equipped_character": player.EquippedCharacter,
		"equipped_weapon":    player.EquippedWeapon,
		"owned_skins":        nonNilStrings(player.OwnedSkins),
		"equipped_skins":     equippedSkinsView(&player),
		"item_levels":        player.ItemLevels,
		"unread_messages":    unread,
		"friend_count":       len(player.Friends),
		"clan_id":            player.ClanID,
		"tutorial_done":      player.TutorialDone,
		"google_linked":      isProtected(player.Auth),
		"device_verified":    sessionToken != "" || sessionMatches(player.Auth.Sessions, bearerToken(r)),
	}
	if sessionToken != "" {
		responseData["session_token"] = sessionToken
	}

	jsonResponse(w, responseData)
}

// tutorialDoneHandler پایانِ آموزشِ بارِ اول را روی حساب ثبت می‌کند.
// درخواست: POST /tutorial/done  {"username": "..."}
func tutorialDoneHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Username string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		httpError(w, "درخواست ناقص است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	res, err := col(ColPlayers).UpdateOne(ctx, bson.M{"username": req.Username},
		bson.M{"$set": bson.M{"tutorial_done": true, "updated_at": time.Now()}})
	if err != nil {
		httpError(w, "ذخیره نشد", http.StatusInternalServerError)
		return
	}
	if res.MatchedCount == 0 {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	jsonResponse(w, map[string]interface{}{"success": true})
}

// getShopHandler لیست آیتم‌های فروشگاه را برمی‌گرداند
// درخواست: GET /get_shop یا GET /api/shop
// پاسخ: آرایه‌ای از ShopItem
func getShopHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != http.MethodGet {
		httpError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// بازیابی تمام آیتم‌های فروشگاه
	cursor, err := col(ColShopItems).Find(ctx, bson.M{})
	if err != nil {
		httpError(w, "Error fetching shop items", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	var items []ShopItem
	if err := cursor.All(ctx, &items); err != nil {
		httpError(w, "Error parsing shop items", http.StatusInternalServerError)
		return
	}

	// محاسبه قیمت نهایی تمام آیتم‌ها
	for i := range items {
		items[i].CalculateFinalPrice()
	}

	jsonResponse(w, items)
}

// buyItemHandler درخواست خرید آیتم را پردازش می‌کند
// درخواست: POST /buy_item
// بدنه: {"username": "...", "item_id": "...", "category": "..."}
// دسته‌های موجود: "coin_pack", "gem_pack", "weapon", "character"
func buyItemHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req BuyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	playersCol := col(ColPlayers)
	var player PlayerModel
	err := playersCol.FindOne(ctx, bson.M{"username": req.Username}).Decode(&player)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// اسکین‌ها فقط از بتل‌پس می‌آیند
	if isSkinID(req.ItemID) {
		httpError(w, "اسکین‌ها فقط از بتل‌پس به دست می‌آیند", http.StatusForbidden)
		return
	}

	// ۱. خرید بسته‌های سکه
	if req.Category == "coin_pack" {
		if handleCoinPackPurchase(w, playersCol, ctx, &player, req.ItemID) {
			return
		}
		respondPurchase(w, &player, req.ItemID)
		return
	}

	// ۲. بسته‌های قلب با پول واقعی خریده می‌شوند و فقط بعد از تأیید رسید
	// بازار/مایکت شارژ می‌شوند (handlers_iap.go). قبلاً همین‌جا رایگان شارژ می‌شد.
	if req.Category == "gem_pack" {
		httpError(w, "خرید قلب فقط از طریق درگاه فروشگاه انجام می‌شود", http.StatusBadRequest)
		return
	}

	// ۳. خرید آیتم‌های عادی (سلاح، کاراکتر)
	if req.Category != "weapon" && req.Category != "character" {
		httpError(w, "دسته‌ی آیتم نامعتبر است", http.StatusBadRequest)
		return
	}
	if handleRegularItemPurchase(w, playersCol, ctx, &player, req) {
		return
	}

	respondPurchase(w, &player, req.ItemID)
}

// respondPurchase وضعیت تازه‌ی بازیکن را بعد از خرید موفق برمی‌گرداند تا کلاینت
// بدون یک درخواست اضافه، سکه/جم و لیست مالکیت را همان لحظه به‌روز کند.
func respondPurchase(w http.ResponseWriter, player *PlayerModel, itemID string) {
	jsonResponse(w, map[string]interface{}{
		"success":          true,
		"item_id":          itemID,
		"coins":            player.Coins,
		"gems":             player.Gems,
		"owned_characters": player.OwnedCharacters,
		"owned_weapons":    player.OwnedWeapons,
	})
}

// handleCoinPackPurchase بسته‌ی سکه را با قلب می‌خرد (store_currency.go)
// بازگشت: true اگر خطا رخ داد
func handleCoinPackPurchase(w http.ResponseWriter, playersCol *mongo.Collection, ctx context.Context, player *PlayerModel, itemID string) bool {
	pack, ok := findCurrencyPack(itemID)
	if !ok || pack.Category != "coins" {
		httpError(w, "بسته سکه نامعتبر است", http.StatusBadRequest)
		return true
	}
	costGems, rewardCoins := pack.Price, pack.Amount

	if player.Gems < costGems {
		httpError(w, "قلب کافی نداری!", http.StatusBadRequest)
		return true
	}

	// فیلتر شرطی: اگر بین خواندن بازیکن و نوشتن، قلبش خرج شده باشد
	// (مثلاً دو تپ پشت‌سرهم) این آپدیت اصلاً مچ نمی‌شود و خرید رد می‌شود.
	res, err := playersCol.UpdateOne(ctx,
		bson.M{"username": player.Username, "gems": bson.M{"$gte": costGems}},
		bson.M{"$inc": bson.M{"gems": -costGems, "coins": rewardCoins}},
	)
	if err != nil {
		httpError(w, "خطا در تراکنش دیتابیس", http.StatusInternalServerError)
		return true
	}
	if res.MatchedCount == 0 {
		httpError(w, "قلب کافی نداری!", http.StatusBadRequest)
		return true
	}

	player.Gems -= costGems
	player.Coins += rewardCoins
	return false
}

// handleRegularItemPurchase آیتم‌های عادی (سلاح، کاراکتر) را خریداری می‌کند
// بازگشت: true اگر خطا رخ داد
func handleRegularItemPurchase(w http.ResponseWriter, playersCol *mongo.Collection, ctx context.Context, player *PlayerModel, req BuyRequest) bool {
	// بازیابی آیتم از فروشگاه
	var item ShopItem
	err := col(ColShopItems).FindOne(ctx, bson.M{"item_id": req.ItemID}).Decode(&item)
	if err != nil {
		httpError(w, "آیتم پیدا نشد", http.StatusNotFound)
		return true
	}

	item.CalculateFinalPrice()

	// تعیین لیست مالکیت براساس نوع آیتم
	ownedField := "owned_weapons"
	var ownedList []string
	if req.Category == "character" {
		ownedField = "owned_characters"
		ownedList = player.OwnedCharacters
	} else {
		ownedList = player.OwnedWeapons
	}

	// چک کردن آیا بازیکن قبلاً این آیتم را دارد
	for _, id := range ownedList {
		if id == req.ItemID {
			httpError(w, "این آیتم را قبلاً خریده‌اید!", http.StatusBadRequest)
			return true
		}
	}

	// تعیین ارزی که باید کم شود
	costField := ""
	switch item.CostType {
	case "coins":
		costField = "coins"
		if player.Coins < item.FinalPrice {
			httpError(w, "سکه کافی نیست!", http.StatusBadRequest)
			return true
		}
	case "gems":
		costField = "gems"
		if player.Gems < item.FinalPrice {
			httpError(w, "جم کافی نیست!", http.StatusBadRequest)
			return true
		}
	}

	// بروزرسانی اتمیک: کم کردن پول و اضافه کردن آیتم در یک عملیات، با شرطِ
	// «هنوز پول کافی هست و آیتم را ندارد». اینطوری دو تپ سریع پشت‌سرهم
	// نمی‌تواند دو بار آیتم را بخرد یا موجودی را منفی کند.
	// رکوردهای قدیمی owned_* را null دارند و $addToSet روی null کار نمی‌کند،
	// پس خریدِ هر کاراکتر/سلاحی برای آن بازیکن‌ها شکست می‌خورد
	// (missions.go:ensureArrayFields توضیحش را دارد).
	if err := ensureArrayFields(ctx, playersCol, bson.M{"username": req.Username},
		"owned_characters", "owned_weapons"); err != nil {
		httpError(w, "خطا در ثبت خرید", http.StatusInternalServerError)
		return true
	}

	filter := bson.M{
		"username": req.Username,
		ownedField: bson.M{"$ne": req.ItemID},
	}
	update := bson.M{
		"$addToSet": bson.M{ownedField: req.ItemID},
	}
	if costField != "" && item.FinalPrice > 0 {
		filter[costField] = bson.M{"$gte": item.FinalPrice}
		update["$inc"] = bson.M{costField: -item.FinalPrice}
	}

	res, err := playersCol.UpdateOne(ctx, filter, update)
	if err != nil {
		httpError(w, "خطا در ثبت خرید", http.StatusInternalServerError)
		return true
	}
	if res.MatchedCount == 0 {
		httpError(w, "خرید انجام نشد: موجودی کافی نیست یا این آیتم را دارید", http.StatusBadRequest)
		return true
	}

	// انعکاس تغییرات روی نسخه‌ی درون‌حافظه تا پاسخِ خروجی تازه باشد
	if costField == "coins" {
		player.Coins -= item.FinalPrice
	} else if costField == "gems" {
		player.Gems -= item.FinalPrice
	}
	if req.Category == "character" {
		player.OwnedCharacters = append(player.OwnedCharacters, req.ItemID)
	} else {
		player.OwnedWeapons = append(player.OwnedWeapons, req.ItemID)
	}
	return false
}

// equipItemHandler درخواست تجهیز کردن یک آیتم را پردازش می‌کند
// درخواست: POST /equip_item
// بدنه: {"username": "...", "item_id": "...", "category": "..."}
// دسته‌های موجود: "weapon", "character"
// توجه: بازیکن باید مالک این آیتم باشد (یا آیتم پیش‌فرض باشد)
func equipItemHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req EquipRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	// بازیابی اطلاعات بازیکن
	var player PlayerModel
	err := col(ColPlayers).FindOne(ctx, bson.M{"username": req.Username}).Decode(&player)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// بررسی مالکیت آیتم
	isOwned := false
	if req.Category == "character" {
		// کاراکتر پیش‌فرض همیشه دردسترس است
		if req.ItemID == "skin_default" {
			isOwned = true
		} else {
			for _, item := range player.OwnedCharacters {
				if item == req.ItemID {
					isOwned = true
					break
				}
			}
		}
	} else if req.Category == "weapon" {
		// سلاح‌های پیش‌فرض همیشه دردسترس‌اند (ak47 سلاح شروع هر اکانت جدید است)
		if req.ItemID == "pistol_default" || req.ItemID == "ak47" {
			isOwned = true
		} else {
			for _, item := range player.OwnedWeapons {
				if item == req.ItemID {
					isOwned = true
					break
				}
			}
		}
	}

	if !isOwned || isSkinID(req.ItemID) {
		httpError(w, "تقلب تشخیص داده شد: شما مالک این آیتم نیستید!", http.StatusForbidden)
		return
	}

	// تعیین فیلد دیتابیس براساس نوع آیتم
	dbField := "equipped_weapon"
	if req.Category == "character" {
		dbField = "equipped_character"
	}

	// بروزرسانی فیلد در دیتابیس
	update := bson.M{"$set": bson.M{dbField: req.ItemID}}
	_, err = col(ColPlayers).UpdateOne(ctx, bson.M{"username": req.Username}, update)
	if err != nil {
		httpError(w, "خطا در ثبت اطلاعات", http.StatusInternalServerError)
		return
	}

	// تجهیز فعلی را برمی‌گردانیم تا صفحه‌ی انتخاب کاراکتر بدون درخواست اضافه سینک شود
	equippedCharacter := player.EquippedCharacter
	equippedWeapon := player.EquippedWeapon
	if req.Category == "character" {
		equippedCharacter = req.ItemID
	} else {
		equippedWeapon = req.ItemID
	}

	jsonResponse(w, map[string]interface{}{
		"success":            true,
		"item_id":            req.ItemID,
		"category":           req.Category,
		"equipped_character": equippedCharacter,
		"equipped_weapon":    equippedWeapon,
	})
}
