package main

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"math/big"
	"net/http"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// -----------------------------------------------------------------------------
// بسته‌ی شانسی (ویترینِ «پک شانس» در تب ویژه‌ی فروشگاه)
// -----------------------------------------------------------------------------
//
// با قلب خریده می‌شود و یک کاراکتر یا سلاحِ **غیرِ لجند** می‌دهد. لجندها
// عمداً بیرونند: آن‌ها باید آگاهانه و با قیمتِ خودشان خریده شوند، نه شانسی.
//
// قرعه همیشه سمت سرور کشیده می‌شود. اگر کلاینت تصمیم می‌گرفت، هر کسی با
// دستکاری پاسخ می‌توانست هر چه خواست بردارد.
//
// آیتمِ تکراری نمی‌دهد: هر چه بازیکن دارد از قرعه بیرون می‌ماند. وقتی همه‌ی
// جایزه‌ها را داشته باشد، خرید رد می‌شود و قلبی کم نمی‌شود — بهتر از این است
// که پول بگیریم و چیزی ندهیم.

const (
	luckyBoxPrice    = 200 // قلب
	luckyBoxCostType = "gems"
)

// luckyBoxEntry یک جایزه‌ی ممکن و وزنش در قرعه
type luckyBoxEntry struct {
	ItemID   string
	Category string // "character" | "weapon"
	Rarity   string
	Weight   int
}

// luckyBoxWeight شانسِ نسبیِ هر رده. rare سه برابرِ epic است تا باز کردنِ
// بسته اغلب «خوب» باشد و گاهی «عالی» — نه این‌که همیشه یک چیز دربیاید.
var luckyBoxWeight = map[string]int{
	"rare": 3,
	"epic": 1,
}

// luckyBoxPool جایزه‌ها را از همان جدول‌های تراز (balance.go و
// weapon_balance.go) می‌سازد تا اگر آیتمِ جدیدی اضافه شد، خودبه‌خود وارد
// قرعه شود. لجندها و آیتم‌های پیش‌فرضِ رایگان بیرون می‌مانند.
func luckyBoxPool() []luckyBoxEntry {
	pool := make([]luckyBoxEntry, 0, 16)
	add := func(itemID, category, rarity string) {
		weight, ok := luckyBoxWeight[rarity]
		if !ok || freeStarters[itemID] {
			return
		}
		pool = append(pool, luckyBoxEntry{itemID, category, rarity, weight})
	}
	for id, rarity := range characterRarity {
		add(id, "character", rarity)
	}
	for id, rarity := range weaponRarity {
		add(id, "weapon", rarity)
	}
	// نقشه در Go ترتیب ندارد؛ مرتب می‌کنیم تا قرعه و تست قابل‌تکرار بمانند
	sort.Slice(pool, func(i, j int) bool { return pool[i].ItemID < pool[j].ItemID })
	return pool
}

// luckyBoxChoices جایزه‌هایی که این بازیکن هنوز ندارد
func luckyBoxChoices(player *PlayerModel) []luckyBoxEntry {
	owned := make(map[string]bool, len(player.OwnedCharacters)+len(player.OwnedWeapons))
	for _, id := range player.OwnedCharacters {
		owned[id] = true
	}
	for _, id := range player.OwnedWeapons {
		owned[id] = true
	}
	out := make([]luckyBoxEntry, 0, 16)
	for _, e := range luckyBoxPool() {
		if !owned[e.ItemID] {
			out = append(out, e)
		}
	}
	return out
}

// drawLuckyBox یکی از جایزه‌ها را با وزنِ خودش انتخاب می‌کند
func drawLuckyBox(choices []luckyBoxEntry) (luckyBoxEntry, bool) {
	total := 0
	for _, e := range choices {
		total += e.Weight
	}
	if total <= 0 {
		return luckyBoxEntry{}, false
	}
	n, err := rand.Int(rand.Reader, big.NewInt(int64(total)))
	if err != nil {
		return choices[0], true
	}
	roll := int(n.Int64())
	for _, e := range choices {
		roll -= e.Weight
		if roll < 0 {
			return e, true
		}
	}
	return choices[len(choices)-1], true
}

// luckyBoxHandler
//
//	GET  /lucky_box                      → قیمت و لیستِ جایزه‌های ممکن (ویترین)
//	POST /lucky_box {"username": "..."}  → یک بار باز کردن
func luckyBoxHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	switch r.Method {
	case http.MethodOptions:
		w.WriteHeader(http.StatusOK)
	case http.MethodGet:
		luckyBoxInfo(w)
	case http.MethodPost:
		openLuckyBox(w, r)
	default:
		httpError(w, "متد مجاز نیست", http.StatusMethodNotAllowed)
	}
}

func luckyBoxInfo(w http.ResponseWriter) {
	pool := luckyBoxPool()
	items := make([]map[string]interface{}, 0, len(pool))
	for _, e := range pool {
		items = append(items, map[string]interface{}{
			"item_id":  e.ItemID,
			"category": e.Category,
			"rarity":   e.Rarity,
		})
	}
	jsonResponse(w, map[string]interface{}{
		"price":     luckyBoxPrice,
		"cost_type": luckyBoxCostType,
		"name":      "بسته‌ی شانسی",
		"pool":      items,
	})
}

func openLuckyBox(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	playersCol := col(ColPlayers)
	var player PlayerModel
	if err := playersCol.FindOne(ctx, bson.M{"username": req.Username}).Decode(&player); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	if player.Gems < luckyBoxPrice {
		httpError(w, "قلب کافی نداری!", http.StatusBadRequest)
		return
	}

	choices := luckyBoxChoices(&player)
	if len(choices) == 0 {
		httpError(w, "همه‌ی جایزه‌های این بسته را داری", http.StatusBadRequest)
		return
	}

	prize, ok := drawLuckyBox(choices)
	if !ok {
		httpError(w, "جایزه‌ای برای این بسته نمانده", http.StatusBadRequest)
		return
	}

	ownedField := "owned_weapons"
	if prize.Category == "character" {
		ownedField = "owned_characters"
	}

	// رکوردهای قدیمی owned_* را null دارند و $addToSet روی null کار نمی‌کند
	// (missions.go:ensureArrayFields توضیحش را دارد)
	if err := ensureArrayFields(ctx, playersCol, bson.M{"username": req.Username},
		"owned_characters", "owned_weapons"); err != nil {
		httpError(w, "خطا در ثبت خرید", http.StatusInternalServerError)
		return
	}

	// کم‌کردن قلب و افزودن جایزه در یک عملیات، با شرطِ «هنوز قلب کافی هست و
	// این آیتم را ندارد» — وگرنه دو تپ سریع می‌توانست دو بار کم کند.
	res, err := playersCol.UpdateOne(ctx,
		bson.M{
			"username": req.Username,
			"gems":     bson.M{"$gte": luckyBoxPrice},
			ownedField: bson.M{"$ne": prize.ItemID},
		},
		bson.M{
			"$inc":         bson.M{"gems": -luckyBoxPrice},
			"$addToSet":    bson.M{ownedField: prize.ItemID},
			"$currentDate": bson.M{"last_seen_at": true},
		})
	if err != nil {
		httpError(w, "خطا در ثبت خرید", http.StatusInternalServerError)
		return
	}
	if res.MatchedCount == 0 {
		httpError(w, "خرید انجام نشد: قلب کافی نیست", http.StatusBadRequest)
		return
	}

	player.Gems -= luckyBoxPrice
	if prize.Category == "character" {
		player.OwnedCharacters = append(player.OwnedCharacters, prize.ItemID)
	} else {
		player.OwnedWeapons = append(player.OwnedWeapons, prize.ItemID)
	}

	jsonResponse(w, map[string]interface{}{
		"success":          true,
		"item_id":          prize.ItemID,
		"category":         prize.Category,
		"rarity":           prize.Rarity,
		"name":             luckyBoxPrizeName(ctx, prize.ItemID),
		"coins":            player.Coins,
		"gems":             player.Gems,
		"owned_characters": player.OwnedCharacters,
		"owned_weapons":    player.OwnedWeapons,
	})
}

// luckyBoxPrizeName اسم نمایشیِ جایزه از کاتالوگ؛ اگر نبود، خودِ آیدی
func luckyBoxPrizeName(ctx context.Context, itemID string) string {
	var item ShopItem
	if err := col(ColShopItems).FindOne(ctx, bson.M{"item_id": itemID}).Decode(&item); err != nil {
		return itemID
	}
	if item.Name == "" {
		return itemID
	}
	return item.Name
}
