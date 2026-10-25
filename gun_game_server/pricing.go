package main

import (
	"context"
	"fmt"

	"go.mongodb.org/mongo-driver/bson"
)

// -----------------------------------------------------------------------------
// قیمت‌گذاری کاتالوگ (Catalogue Pricing)
// -----------------------------------------------------------------------------
//
// قبل از این، قیمت‌ها دستی و ناهماهنگ بودند: دو آیتمِ هم‌رده قیمت‌های خیلی
// متفاوت داشتند (skin_boy پنج‌هزار سکه ولی skin_girl دوازده‌هزار و نیم، هر دو
// rare)، بعضی rareها با جم فروخته می‌شدند و بعضی epicها ارزان‌تر از rareها
// درمی‌آمدند. نتیجه این بود که قیمت هیچ ربطی به ارزشِ واقعیِ آیتم نداشت.
//
// حالا قیمت فقط و فقط از دو چیز می‌آید: **رده** و **نوعِ آیتم**. پس بازیکن
// با دیدنِ رنگِ رده می‌داند تقریباً چقدر باید بدهد و هیچ آیتمی «تله» نیست.
//
// نرخ تبدیل طراحی: هر ۱۰۰ سکه ≈ ۱ جم. قیمت‌های جم عمداً کمی ارزان‌ترند چون
// جم ارز پولیِ بازی است.
//
// نکته‌ی مهمِ تعادل: قیمت هیچ ربطی به قدرت ندارد. یک لجندِ گران فقط ۶٪
// قوی‌تر از یک rare است (balance.go) — چیزی که می‌خرید عمدتاً ظاهر و
// «سبکِ بازی» است، نه برد.

// catalogPrice قیمتِ استانداردِ هر ترکیبِ (بخش، رده، ارز)
type catalogPrice struct {
	CostType string
	Price    int
}

// characterPrices قیمت کاراکترها
var characterPrices = map[string]catalogPrice{
	"rare":   {"coins", 6000},
	"epic":   {"gems", 200},
	"legend": {"gems", 450},
}

// weaponPrices قیمت سلاح‌ها — کمی ارزان‌تر از کاراکترِ هم‌رده، چون بازیکن
// برای یک ست کامل به هر دو نیاز دارد.
var weaponPrices = map[string]catalogPrice{
	"rare":   {"coins", 4000},
	"epic":   {"gems", 150},
	"legend": {"gems", 350},
}

// freeStarters آیتم‌هایی که هر بازیکن از همان اول دارد. قیمتشان صفر می‌شود
// تا فروشگاه چیزی را که بازیکن از قبل دارد به قیمتِ epic نشان ندهد.
//
// عمداً از روی همان تجهیزاتِ پیش‌فرضِ newPlayerModel ساخته می‌شود تا اگر
// روزی تجهیزات شروع عوض شد، لیست رایگان‌ها خودبه‌خود با آن هماهنگ بماند.
var freeStarters = map[string]bool{
	defaultCharacterID: true,
	defaultWeaponID:    true,
	"pistol_default":   true,
}

// SeedCatalogPrices قیمت همه‌ی کاراکترها و سلاح‌ها را یکدست می‌کند.
// بسته‌های سکه/جم دست نمی‌خورند چون قیمتشان تصمیمِ تجاری است، نه تعادلی.
func SeedCatalogPrices(ctx context.Context) error {
	items := col(ColShopItems)

	cursor, err := items.Find(ctx, bson.M{"category": bson.M{"$in": []string{"character", "weapon"}}})
	if err != nil {
		return fmt.Errorf("خواندن کاتالوگ برای قیمت‌گذاری: %w", err)
	}
	defer cursor.Close(ctx)

	var docs []ShopItem
	if err := cursor.All(ctx, &docs); err != nil {
		return fmt.Errorf("decode کاتالوگ: %w", err)
	}

	for i := range docs {
		doc := &docs[i]

		table := characterPrices
		if doc.Category == "weapon" {
			table = weaponPrices
		}
		price, ok := table[doc.Rarity]
		if !ok {
			// رده‌ی ناشناس: دست نزن، بهتر از قیمتِ اشتباه است
			continue
		}

		costType, original := price.CostType, price.Price
		if freeStarters[doc.ItemID] {
			costType, original = "coins", 0
		}

		// تخفیفِ موجود حفظ می‌شود (کمپین‌های ویترین)، فقط قیمت پایه یکدست می‌شود
		final := original
		if doc.DiscountPercent > 0 {
			final = original - (original*doc.DiscountPercent)/100
		}

		if _, err := items.UpdateByID(ctx, doc.ID, bson.M{"$set": bson.M{
			"cost_type":      costType,
			"original_price": original,
			"final_price":    final,
		}}); err != nil {
			return fmt.Errorf("قیمت‌گذاری %s: %w", doc.ItemID, err)
		}
	}
	return nil
}
