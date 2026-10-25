package main

import (
	"context"
	"fmt"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// -----------------------------------------------------------------------------
// بسته‌های ارز (سکه و قلب)
// -----------------------------------------------------------------------------
//
// مثل قیمت کاراکترها (pricing.go)، منبع حقیقت بسته‌ها همین کد است و هر بار
// سرور بالا می‌آید روی shop_items نوشته می‌شود. قبلاً سرور یک لیست جدا با
// آیدی‌های coins_small/... داشت که با آیدی‌های دیتابیس (coins1000/...) نمی‌خواند
// و در نتیجه هیچ خرید سکه‌ای انجام نمی‌شد.
//
// - بسته‌ی سکه با قلب خریده می‌شود (/buy_item).
// - بسته‌ی قلب فقط با پرداخت واقعی از بازار/مایکت (/iap/verify). ProductID
//   دقیقاً همان شناسه‌ای است که در پیشخوان بازار و مایکت تعریف می‌کنید.

type currencyPack struct {
	ItemID   string
	Category string // "coins" | "gems"
	Amount   int
	CostType string // "gems" برای سکه، "toman" برای قلب
	// Price قیمت کاملِ بسته — همین عدد در تب «سکه و قلب» نشان داده می‌شود.
	Price int
	// Discount درصد تخفیفِ ویترینِ «پیشنهاد ویژه». تب «سکه و قلب» همیشه
	// قیمت کامل را نشان می‌دهد و پیشنهاد ویژه همین قیمت را با این درصد
	// خط‌خورده/تخفیف‌خورده نشان می‌دهد. صفر یعنی بدون تخفیف.
	Discount int
	// Bonus قلبِ هدیه — *همیشه* روی Amount اضافه می‌شود، از هر کجای فروشگاه
	// که بسته خریده شود. ویترینِ «پیشنهاد ویژه» آن را برجسته نشان می‌دهد
	// («+۱۰») و تبِ «سکه و قلب» عددِ نهایی (Amount+Bonus) را روی کارت می‌نویسد.
	// بسته‌ی بزرگ‌تر هدیه‌ی بیشتری دارد.
	Bonus     int
	ProductID string
}

// نردبانِ قیمت — قانونش این است: هرچه بسته بزرگ‌تر، هر واحدش ارزان‌تر.
// قبلاً این قانون برقرار نبود (۲۵۰۰ و ۵۰۰۰ سکه دقیقاً یک نرخ داشتند، و
// ویترینِ پیشنهاد ویژه یک لیستِ دستیِ جدا بود که ۳ تا ۵ برابرِ تبِ ارز
// قیمت می‌داد). حالا هر دو ویترین از همین یک جدول می‌خوانند.
//
// سکه (با قلب): نرخِ سکه به ازای هر قلب ۵۰ → ۷۱ → ۸۳ → ۱۰۰
//
// قلب (با تومان): قیمت‌ها حدود ۴۰٪ بالا رفته‌اند و هر بسته یک هدیه‌ی قلب هم
// دارد. نرخِ واقعی = قیمت ÷ (تعداد + هدیه):
//
//	بسته      قیمت کامل   هدیه   نرخ کامل   تخفیف   نرخ با تخفیف
//	۱۰۰       ۸۵٬۰۰۰      +۱۰    ۷۷۳        ۱۰٪     ۶۹۵
//	۲۰۰       ۱۵۵٬۰۰۰     +۲۰    ۷۰۵        ۲۰٪     ۵۶۴
//	۳۰۰       ۲۲۵٬۰۰۰     +۳۰    ۶۸۲        ۲۴٪     ۵۱۸
//	۴۰۰       ۲۸۰٬۰۰۰     +۵۰    ۶۲۲        ۳۰٪     ۴۳۶
var currencyPacks = []currencyPack{
	{"coins1000", "coins", 1000, "gems", 20, 0, 0, ""},
	{"coins2500", "coins", 2500, "gems", 35, 0, 0, ""},
	{"coins5000", "coins", 5000, "gems", 60, 0, 0, ""},
	{"coins10000", "coins", 10000, "gems", 100, 0, 0, ""},

	{"100gems", "gems", 100, "toman", 85000, 10, 10, "gems_100"},
	{"200gems", "gems", 200, "toman", 155000, 20, 20, "gems_200"},
	{"300gems", "gems", 300, "toman", 225000, 24, 30, "gems_300"},
	{"400gems", "gems", 400, "toman", 280000, 30, 50, "gems_400"},
}

// FinalPrice قیمتِ تخفیف‌خورده‌ی بسته (ویترینِ پیشنهاد ویژه)
func (p currencyPack) FinalPrice() int {
	if p.Discount <= 0 {
		return p.Price
	}
	return p.Price - (p.Price*p.Discount)/100
}

// TotalAmount چیزی که واقعاً به حساب بازیکن می‌نشیند (تعداد + هدیه)
func (p currencyPack) TotalAmount() int {
	return p.Amount + p.Bonus
}

func findCurrencyPack(itemID string) (currencyPack, bool) {
	for _, p := range currencyPacks {
		if p.ItemID == itemID {
			return p, true
		}
	}
	return currencyPack{}, false
}

func findGemPackByProduct(productID string) (currencyPack, bool) {
	for _, p := range currencyPacks {
		if p.Category == "gems" && p.ProductID != "" && p.ProductID == productID {
			return p, true
		}
	}
	return currencyPack{}, false
}

// SeedCurrencyPacks بسته‌ها را روی کاتالوگ می‌نویسد.
//
// چه چیزی از کد می‌آید و چه چیزی از دیتابیس:
//
//   - تعداد، هدیه، قیمتِ کامل و شناسه‌ی محصول از کد می‌آیند و هر بار بازنویسی
//     می‌شوند — این‌ها پول واقعی‌اند و نباید با یک تایپ در دیتابیس عوض شوند.
//   - **تخفیف از دیتابیس می‌آید.** عددِ داخل جدولِ بالا فقط مقدارِ اولیه‌ی
//     یک دیتابیسِ خالی است؛ بعد از آن هر چه در `discount_percent` بنویسید
//     سرِ جایش می‌ماند و بوت‌شدنِ سرور پاکش نمی‌کند. پس کمپین تخفیف بدون
//     دیپلوی مجدد راه می‌افتد.
//   - اسم و عکس هم اگر آیتم از قبل باشد دست نمی‌خورد.
//
// قیمتِ نهایی اصلاً ذخیره نمی‌شود که کهنه نشود: getShopHandler آن را هر بار
// از روی `original_price` و `discount_percent`ِ دیتابیس حساب می‌کند
// (ShopItem.CalculateFinalPrice).
func SeedCurrencyPacks(ctx context.Context) error {
	items := col(ColShopItems)
	for _, p := range currencyPacks {
		_, err := items.UpdateOne(ctx,
			bson.M{"item_id": p.ItemID},
			bson.M{
				"$set": bson.M{
					"category":       p.Category,
					"section":        "currency",
					"amount":         p.Amount,
					"bonus_amount":   p.Bonus,
					"cost_type":      p.CostType,
					"original_price": p.Price,
					"product_id":     p.ProductID,
				},
				"$setOnInsert": bson.M{
					"name":             fmt.Sprintf("%d %s", p.TotalAmount(), map[string]string{"coins": "سکه", "gems": "قلب"}[p.Category]),
					"discount_percent": p.Discount,
					"final_price":      p.FinalPrice(),
				},
			},
			options.Update().SetUpsert(true),
		)
		if err != nil {
			return fmt.Errorf("ثبت بسته‌ی %s: %w", p.ItemID, err)
		}
	}
	return nil
}
