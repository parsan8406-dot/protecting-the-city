package main

import (
	"encoding/json"
	"testing"

	"go.mongodb.org/mongo-driver/bson"
)

// قانونِ اصلیِ بسته‌ی شانسی: هیچ لجندی و هیچ آیتمِ رایگانی داخلش نیست.
func TestLuckyBoxHasNoLegendOrFreebies(t *testing.T) {
	pool := luckyBoxPool()
	if len(pool) < 4 {
		t.Fatalf("قرعه خیلی کوچک است: %d آیتم", len(pool))
	}
	seen := map[string]bool{}
	for _, e := range pool {
		if e.Rarity == "legend" {
			t.Errorf("لجند نباید در بسته‌ی شانسی باشد: %s", e.ItemID)
		}
		if freeStarters[e.ItemID] {
			t.Errorf("آیتمِ رایگان نباید جایزه باشد: %s", e.ItemID)
		}
		if e.Weight <= 0 {
			t.Errorf("وزنِ %s نامعتبر است: %d", e.ItemID, e.Weight)
		}
		if e.Category != "character" && e.Category != "weapon" {
			t.Errorf("دسته‌ی %s نامعتبر است: %q", e.ItemID, e.Category)
		}
		if seen[e.ItemID] {
			t.Errorf("آیتمِ تکراری در قرعه: %s", e.ItemID)
		}
		seen[e.ItemID] = true
	}
	// هر دو نوع جایزه باید ممکن باشند
	var chars, guns int
	for _, e := range pool {
		if e.Category == "character" {
			chars++
		} else {
			guns++
		}
	}
	if chars == 0 || guns == 0 {
		t.Fatalf("قرعه باید هم کاراکتر داشته باشد هم سلاح: %d / %d", chars, guns)
	}
}

// چیزی که بازیکن دارد نباید دوباره دربیاید
func TestLuckyBoxSkipsOwned(t *testing.T) {
	all := luckyBoxPool()
	player := &PlayerModel{}
	for _, e := range all[:len(all)-1] {
		if e.Category == "character" {
			player.OwnedCharacters = append(player.OwnedCharacters, e.ItemID)
		} else {
			player.OwnedWeapons = append(player.OwnedWeapons, e.ItemID)
		}
	}
	left := luckyBoxChoices(player)
	if len(left) != 1 || left[0].ItemID != all[len(all)-1].ItemID {
		t.Fatalf("فقط باید یک جایزه بماند، %d ماند", len(left))
	}
	// وقتی همه را دارد، قرعه‌ای نمی‌ماند و خرید باید رد شود
	e := left[0]
	if e.Category == "character" {
		player.OwnedCharacters = append(player.OwnedCharacters, e.ItemID)
	} else {
		player.OwnedWeapons = append(player.OwnedWeapons, e.ItemID)
	}
	if got := luckyBoxChoices(player); len(got) != 0 {
		t.Fatalf("نباید جایزه‌ای بماند، %d ماند", len(got))
	}
	if _, ok := drawLuckyBox(nil); ok {
		t.Fatal("قرعه‌ی خالی نباید جایزه بدهد")
	}
}

// قرعه باید واقعاً پخش باشد و rare بیشتر از epic دربیاید (وزن ۳ به ۱)
func TestLuckyBoxDrawIsSpreadAndWeighted(t *testing.T) {
	pool := luckyBoxPool()
	hits := map[string]int{}
	byRarity := map[string]int{}
	const rolls = 4000
	for i := 0; i < rolls; i++ {
		e, ok := drawLuckyBox(pool)
		if !ok {
			t.Fatal("قرعه جایزه نداد")
		}
		hits[e.ItemID]++
		byRarity[e.Rarity]++
	}
	if len(hits) != len(pool) {
		t.Errorf("بعد از %d قرعه فقط %d آیتم از %d دیده شد", rolls, len(hits), len(pool))
	}
	if byRarity["rare"] <= byRarity["epic"] {
		t.Errorf("rare باید بیشتر از epic دربیاید: rare=%d epic=%d",
			byRarity["rare"], byRarity["epic"])
	}
}

// جریانِ کاملِ خرید روی دیتابیس: قلب کم می‌شود، جایزه به انبار می‌رود،
// همان جایزه دوباره درنمی‌آید، و با قلبِ ناکافی خرید رد می‌شود.
func TestLuckyBoxChargesAndGrants(t *testing.T) {
	ctx := withDB(t)
	p := seedStorePlayer(t, ctx, "__lucky_probe", luckyBoxPrice*2+10)

	got := map[string]bool{}
	for i := 0; i < 2; i++ {
		rec := storePost(luckyBoxHandler, "/", `{"username":"__lucky_probe"}`)
		if rec.Code != 200 {
			t.Fatalf("باز کردن %d: %d %s", i, rec.Code, rec.Body)
		}
		var res struct {
			ItemID   string `json:"item_id"`
			Category string `json:"category"`
			Rarity   string `json:"rarity"`
			Gems     int    `json:"gems"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &res); err != nil {
			t.Fatalf("پاسخ نامعتبر: %v", err)
		}
		if res.Rarity == "legend" {
			t.Fatalf("لجند درآمد: %s", res.ItemID)
		}
		if got[res.ItemID] {
			t.Fatalf("جایزه‌ی تکراری: %s", res.ItemID)
		}
		got[res.ItemID] = true

		want := p.Gems - luckyBoxPrice*(i+1)
		if res.Gems != want {
			t.Fatalf("قلبِ پاسخ %d است، باید %d باشد", res.Gems, want)
		}
		if live := reload(t, ctx, p.Username); live.Gems != want {
			t.Fatalf("قلبِ دیتابیس %d است، باید %d باشد", live.Gems, want)
		}
	}

	// حالا فقط ۱۰ قلب مانده — باید رد شود و چیزی کم نکند
	rec := storePost(luckyBoxHandler, "/", `{"username":"__lucky_probe"}`)
	if rec.Code == 200 {
		t.Fatal("با قلبِ ناکافی نباید باز شود")
	}
	if live := reload(t, ctx, p.Username); live.Gems != 10 {
		t.Fatalf("قلب نباید کم می‌شد: %d", live.Gems)
	}
	if owned := len(reload(t, ctx, p.Username).OwnedCharacters) +
		len(reload(t, ctx, p.Username).OwnedWeapons); owned != 2 {
		t.Fatalf("باید دقیقاً ۲ جایزه در انبار باشد، %d هست", owned)
	}
}

// خریدِ عادیِ کاراکتر/سلاح هم برای رکوردهایی که owned_* در آن‌ها null است
// باید کار کند (همان باگِ $addToSet روی null)
func TestBuyItemWorksWithNullOwnedArrays(t *testing.T) {
	ctx := withDB(t)
	name := "__nullarray_probe"
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
	_, err := col(ColPlayers).InsertOne(ctx, bson.M{
		"player_id": name + "_id", "username": name, "coins": 100000, "gems": 100000,
		"level": 1, "owned_characters": nil, "owned_weapons": nil,
	})
	if err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(func() { _, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name}) })

	var item ShopItem
	if err := col(ColShopItems).FindOne(ctx, bson.M{"category": "character"}).Decode(&item); err != nil {
		t.Skip("کاتالوگ کاراکتر ندارد")
	}

	rec := storePost(buyItemHandler, "/",
		`{"username":"`+name+`","item_id":"`+item.ItemID+`","category":"character"}`)
	if rec.Code != 200 {
		t.Fatalf("خرید با آرایه‌ی null شکست خورد: %d %s", rec.Code, rec.Body)
	}
	owned := reload(t, ctx, name).OwnedCharacters
	if len(owned) != 1 || owned[0] != item.ItemID {
		t.Fatalf("آیتم به انبار نرفت: %v", owned)
	}
}
