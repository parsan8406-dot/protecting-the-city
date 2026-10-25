package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"go.mongodb.org/mongo-driver/bson"
)

// کد هدیه، جایزه‌ی تبلیغ، خرید سکه و تأیید خرید قلب — روی دیتابیس واقعی.

func storePost(h http.HandlerFunc, path, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h(rec, httptest.NewRequest(http.MethodPost, path, strings.NewReader(body)))
	return rec
}

func seedStorePlayer(t *testing.T, ctx context.Context, name string, gems int) PlayerModel {
	t.Helper()
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
	p := PlayerModel{Username: name, PlayerID: name + "_id", Coins: 0, Gems: gems, Level: 1}
	if _, err := col(ColPlayers).InsertOne(ctx, p); err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(func() { _, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name}) })
	return p
}

func TestGiftCodeOncePerPlayerAndCapacity(t *testing.T) {
	ctx := withDB(t)
	a := seedStorePlayer(t, ctx, "__gift_probe_a", 0)
	b := seedStorePlayer(t, ctx, "__gift_probe_b", 0)
	const code = "TESTPROBE99"
	_, _ = col(ColGiftCodes).DeleteOne(ctx, bson.M{"_id": code})
	_, _ = col(ColGiftRedemptions).DeleteMany(ctx, bson.M{"code": code})
	t.Cleanup(func() {
		_, _ = col(ColGiftCodes).DeleteOne(ctx, bson.M{"_id": code})
		_, _ = col(ColGiftRedemptions).DeleteMany(ctx, bson.M{"code": code})
	})

	if rec := storePost(createGiftCodeHandler, "/", `{"code":"testprobe99","coins":500,"gems":5,"max_uses":1}`); rec.Code != 200 {
		t.Fatalf("ساخت کد: %d %s", rec.Code, rec.Body)
	}
	if rec := storePost(redeemGiftCodeHandler, "/", `{"username":"`+a.Username+`","code":" testprobe99 "}`); rec.Code != 200 {
		t.Fatalf("استفاده‌ی اول: %d %s", rec.Code, rec.Body)
	}
	if p := reload(t, ctx, a.Username); p.Coins != 500 || p.Gems != 5 {
		t.Fatalf("جایزه واریز نشد: coins=%d gems=%d", p.Coins, p.Gems)
	}
	if rec := storePost(redeemGiftCodeHandler, "/", `{"username":"`+a.Username+`","code":"TESTPROBE99"}`); rec.Code != http.StatusConflict {
		t.Fatalf("استفاده‌ی دوباره باید رد شود: %d", rec.Code)
	}
	if rec := storePost(redeemGiftCodeHandler, "/", `{"username":"`+b.Username+`","code":"TESTPROBE99"}`); rec.Code != http.StatusGone {
		t.Fatalf("ظرفیت پر است، باید رد شود: %d", rec.Code)
	}
	if p := reload(t, ctx, b.Username); p.Coins != 0 {
		t.Fatalf("بازیکن دوم نباید جایزه بگیرد")
	}
}

func TestAdRewardCooldownAndToken(t *testing.T) {
	ctx := withDB(t)
	p := seedStorePlayer(t, ctx, "__ad_probe", 0)
	_, _ = col(ColAdRewards).DeleteMany(ctx, bson.M{"player_id": p.PlayerID})
	t.Cleanup(func() { _, _ = col(ColAdRewards).DeleteMany(ctx, bson.M{"player_id": p.PlayerID}) })

	if rec := storePost(adRewardClaimHandler, "/", `{"username":"__ad_probe","ad_token":"t1"}`); rec.Code != 200 {
		t.Fatalf("تبلیغ اول: %d %s", rec.Code, rec.Body)
	}
	// بلافاصله دوباره: فاصله‌ی حداقلی رعایت نشده
	if rec := storePost(adRewardClaimHandler, "/", `{"username":"__ad_probe","ad_token":"t2"}`); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("باید به‌خاطر فاصله رد شود: %d", rec.Code)
	}
	if got := reload(t, ctx, p.Username).Gems; got != adRewardGems {
		t.Fatalf("قلب = %d، باید %d باشد", got, adRewardGems)
	}
}

func TestCoinPackBuysWithGems(t *testing.T) {
	ctx := withDB(t)
	p := seedStorePlayer(t, ctx, "__coinpack_probe", 25)
	rec := storePost(buyItemHandler, "/", `{"username":"__coinpack_probe","item_id":"coins1000","category":"coin_pack"}`)
	if rec.Code != 200 {
		t.Fatalf("خرید سکه: %d %s", rec.Code, rec.Body)
	}
	if got := reload(t, ctx, p.Username); got.Coins != 1000 || got.Gems != 5 {
		t.Fatalf("coins=%d gems=%d", got.Coins, got.Gems)
	}
	if rec := storePost(buyItemHandler, "/", `{"username":"__coinpack_probe","item_id":"100gems","category":"gem_pack"}`); rec.Code == 200 {
		t.Fatalf("بسته‌ی قلب نباید بدون پرداخت شارژ شود")
	}
}

func TestIAPCreditsOnlyOnce(t *testing.T) {
	ctx := withDB(t)
	os.Setenv("IAP_ALLOW_DEBUG", "1")
	defer os.Unsetenv("IAP_ALLOW_DEBUG")
	p := seedStorePlayer(t, ctx, "__iap_probe", 0)
	const token = "debug-probe-token"
	_, _ = col(ColIAPPurchases).DeleteMany(ctx, bson.M{"purchase_token": token})
	t.Cleanup(func() { _, _ = col(ColIAPPurchases).DeleteMany(ctx, bson.M{"purchase_token": token}) })

	body := `{"username":"__iap_probe","store":"bazaar","product_id":"gems_200","purchase_token":"` + token + `"}`
	for i := 0; i < 2; i++ {
		if rec := storePost(iapVerifyHandler, "/", body); rec.Code != 200 {
			t.Fatalf("تأیید %d: %d %s", i, rec.Code, rec.Body)
		}
	}
	// یک بار شارژ می‌شود، و شارژ = تعدادِ بسته + هدیه‌اش (store_currency.go)
	pack, _ := findGemPackByProduct("gems_200")
	if got := reload(t, ctx, p.Username).Gems; got != pack.TotalAmount() {
		t.Fatalf("قلب = %d، باید فقط یک بار %d شارژ شود", got, pack.TotalAmount())
	}
	other := seedStorePlayer(t, ctx, "__iap_probe_other", 0)
	stolen := strings.Replace(body, "__iap_probe", other.Username, 1)
	if rec := storePost(iapVerifyHandler, "/", stolen); rec.Code != http.StatusForbidden {
		t.Fatalf("رسید حساب دیگر باید رد شود: %d", rec.Code)
	}
}
