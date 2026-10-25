package main

import (
	"testing"

	"go.mongodb.org/mongo-driver/bson"
)

// بسته‌ی بزرگ‌تر باید ارزش بیشتری داشته باشد. قبلاً ۲۵۰۰ و ۵۰۰۰ سکه دقیقاً
// یک نرخ داشتند و بازیکن با خریدِ بسته‌ی بزرگ‌تر هیچ سودی نمی‌کرد.
func TestBiggerPackIsBetterValue(t *testing.T) {
	for _, category := range []string{"coins", "gems"} {
		prevAmount, prevRate := 0, 0.0
		for _, p := range currencyPacks {
			if p.Category != category {
				continue
			}
			if p.Amount <= prevAmount && prevAmount != 0 {
				t.Fatalf("بسته‌های %s مرتب نیستند: %s", category, p.ItemID)
			}
			// نرخ = قیمت به ازای هر واحدِ *دریافتی* (با احتسابِ هدیه)؛
			// هرچه کمتر، بسته بهتر
			rate := float64(p.Price) / float64(p.TotalAmount())
			if prevRate > 0 && rate >= prevRate {
				t.Errorf("بسته‌ی %s (%d) ارزان‌تر از بسته‌ی کوچک‌تر نیست: %.2f >= %.2f",
					p.ItemID, p.Amount, rate, prevRate)
			}
			prevAmount, prevRate = p.Amount, rate
		}
	}
}

// تخفیفِ ویترینِ پیشنهاد ویژه هم نباید نردبان را به‌هم بزند: بسته‌ی بزرگ‌تر
// بعد از تخفیف هم باید ارزان‌تر تمام شود.
func TestDiscountKeepsTheLadder(t *testing.T) {
	prevRate := 0.0
	for _, p := range currencyPacks {
		if p.Category != "gems" {
			continue
		}
		if p.Discount < 0 || p.Discount > 100 {
			t.Fatalf("درصد تخفیف %s نامعتبر است: %d", p.ItemID, p.Discount)
		}
		rate := float64(p.FinalPrice()) / float64(p.TotalAmount())
		if prevRate > 0 && rate >= prevRate {
			t.Errorf("بعد از تخفیف، %s ارزان‌تر از بسته‌ی کوچک‌تر نیست: %.2f >= %.2f",
				p.ItemID, rate, prevRate)
		}
		prevRate = rate
	}
}

// هر بسته‌ی قلب باید شناسه‌ی محصول داشته باشد، وگرنه دکمه‌ی خریدش در بازار/مایکت
// به هیچ محصولی وصل نیست و کلاینت فقط پیام «تعریف نشده» نشان می‌دهد.
func TestGemPacksHaveProductID(t *testing.T) {
	for _, p := range currencyPacks {
		if p.Category == "gems" && p.ProductID == "" {
			t.Errorf("بسته‌ی قلب %s شناسه‌ی محصول ندارد", p.ItemID)
		}
		if p.Category == "coins" && p.CostType != "gems" {
			t.Errorf("بسته‌ی سکه %s باید با قلب خریده شود", p.ItemID)
		}
	}
}

// هدیه‌ی بسته‌های قلب: بسته‌ی بزرگ‌تر هدیه‌ی بزرگ‌تر، و بسته‌های سکه هدیه ندارند.
func TestGemPackBonusGrowsWithSize(t *testing.T) {
	prev := -1
	for _, p := range currencyPacks {
		if p.Category == "coins" {
			if p.Bonus != 0 {
				t.Errorf("بسته‌ی سکه نباید هدیه داشته باشد: %s", p.ItemID)
			}
			continue
		}
		if p.Bonus <= 0 {
			t.Errorf("بسته‌ی قلب %s هدیه ندارد", p.ItemID)
		}
		if prev >= 0 && p.Bonus <= prev {
			t.Errorf("هدیه‌ی %s از بسته‌ی کوچک‌تر بیشتر نیست: %d <= %d", p.ItemID, p.Bonus, prev)
		}
		if p.TotalAmount() != p.Amount+p.Bonus {
			t.Errorf("جمعِ %s غلط است", p.ItemID)
		}
		prev = p.Bonus
	}
}

// تخفیف مالِ دیتابیس است: اگر اپراتور تخفیفِ یک بسته را عوض کند، بوت‌شدنِ
// دوباره‌ی سرور نباید پاکش کند — ولی قیمتِ کامل و تعداد باید از کد بیایند.
func TestSeedKeepsDatabaseDiscount(t *testing.T) {
	ctx := withDB(t)
	const id = "100gems"
	items := col(ColShopItems)

	var before ShopItem
	if err := items.FindOne(ctx, bson.M{"item_id": id}).Decode(&before); err != nil {
		if err := SeedCurrencyPacks(ctx); err != nil {
			t.Skipf("کاتالوگ آماده نیست: %v", err)
		}
		_ = items.FindOne(ctx, bson.M{"item_id": id}).Decode(&before)
	}
	t.Cleanup(func() {
		_, _ = items.UpdateOne(ctx, bson.M{"item_id": id},
			bson.M{"$set": bson.M{"discount_percent": before.DiscountPercent}})
	})

	// اپراتور یک کمپینِ ۵۵ درصدی می‌گذارد
	if _, err := items.UpdateOne(ctx, bson.M{"item_id": id},
		bson.M{"$set": bson.M{"discount_percent": 55}}); err != nil {
		t.Fatal(err)
	}
	if err := SeedCurrencyPacks(ctx); err != nil {
		t.Fatal(err)
	}

	var after ShopItem
	if err := items.FindOne(ctx, bson.M{"item_id": id}).Decode(&after); err != nil {
		t.Fatal(err)
	}
	if after.DiscountPercent != 55 {
		t.Errorf("تخفیفِ دیتابیس پاک شد: %d", after.DiscountPercent)
	}
	pack, _ := findCurrencyPack(id)
	if after.OriginalPrice != pack.Price || after.Amount != pack.Amount || after.BonusAmount != pack.Bonus {
		t.Errorf("عدد و قیمتِ کامل باید از کد بیایند: price=%d amount=%d bonus=%d",
			after.OriginalPrice, after.Amount, after.BonusAmount)
	}
	// قیمتِ نهایی هنگام پاسخ‌دادن از روی تخفیفِ دیتابیس حساب می‌شود
	after.CalculateFinalPrice()
	if want := pack.Price - pack.Price*55/100; after.FinalPrice != want {
		t.Errorf("قیمت نهایی %d است، باید %d باشد", after.FinalPrice, want)
	}
}
