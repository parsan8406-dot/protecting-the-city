package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// کاپ‌های فصل باید کاملاً سمت سرور باشند: تعریف از دیتابیس، تجربه از سند
// بازیکن، و جایزه فقط یک بار. این تست‌ها همان مسیر واقعی HTTP را می‌زنند تا
// اگر کسی روزی عددی را از بدنه‌ی درخواست قبول کرد، اینجا لو برود.
//
// اگر مونگو بالا نباشد رد می‌شوند (مثل match_reward_db_test.go).

func seedCupPlayer(t *testing.T, ctx context.Context, name string, xp int) PlayerModel {
	t.Helper()
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
	p := PlayerModel{
		PlayerID:   "test_" + name,
		Username:   name,
		Coins:      0,
		Gems:       0,
		Experience: xp,
		Level:      1,
	}
	if _, err := col(ColPlayers).InsertOne(ctx, p); err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(func() {
		_, _ = col(ColPlayers).DeleteOne(context.Background(), bson.M{"username": name})
	})
	return p
}

func cupsOf(t *testing.T, username string) map[string]interface{} {
	t.Helper()
	rec := httptest.NewRecorder()
	getSeasonCupsHandler(rec, httptest.NewRequest(http.MethodGet,
		"/season/cups?username="+username, nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /season/cups کد %d داد: %s", rec.Code, rec.Body.String())
	}
	var out map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("پاسخ قابل خواندن نبود: %v", err)
	}
	return out
}

func claimCup(t *testing.T, username, cupID string) *httptest.ResponseRecorder {
	t.Helper()
	body, _ := json.Marshal(map[string]string{"username": username, "cup_id": cupID})
	req := httptest.NewRequest(http.MethodPost, "/season/cups/claim", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	claimSeasonCupHandler(rec, req)
	return rec
}

// تعریف کاپ‌ها باید از کالکشن season_cups بیاید، نه از لیستِ داخل کد
func TestSeasonCupsComeFromDatabase(t *testing.T) {
	ctx := withDB(t)
	if err := seedSeasonCups(ctx); err != nil {
		t.Skipf("seed نشد: %v", err)
	}

	defs := seasonCupDefs(ctx)
	if len(defs) != SeasonCupPerSeason {
		t.Fatalf("انتظار %d کاپ داشتیم، %d آمد", SeasonCupPerSeason, len(defs))
	}

	// عدد را در دیتابیس عوض می‌کنیم؛ سرور باید همان را بخواند
	first := defs[0]
	original := first.XPRequired
	if _, err := col(ColSeasonCups).UpdateOne(ctx,
		bson.M{"season_id": DefaultSeasonID, "cup_id": first.CupID},
		bson.M{"$set": bson.M{"xp_required": original + 111}}); err != nil {
		t.Fatalf("آپدیت کاتالوگ نشد: %v", err)
	}
	t.Cleanup(func() {
		_, _ = col(ColSeasonCups).UpdateOne(context.Background(),
			bson.M{"season_id": DefaultSeasonID, "cup_id": first.CupID},
			bson.M{"$set": bson.M{"xp_required": original}})
		invalidateSeasonCupCache()
	})

	invalidateSeasonCupCache()
	if got := seasonCupDefs(ctx)[0].XPRequired; got != original+111 {
		t.Fatalf("تعریف کاپ از دیتابیس خوانده نشد: %d به جای %d", got, original+111)
	}
}

// تجربه‌ی کم = جایزه ندارد، حتی اگر کلاینت مستقیم درخواست بدهد
func TestClaimSeasonCupRejectsBelowThreshold(t *testing.T) {
	ctx := withDB(t)
	if err := seedSeasonCups(ctx); err != nil {
		t.Skipf("seed نشد: %v", err)
	}
	defs := seasonCupDefs(ctx)

	name := "cup_test_poor"
	seedCupPlayer(t, ctx, name, 0)

	rec := claimCup(t, name, defs[0].CupID)
	if rec.Code == http.StatusOK {
		t.Fatalf("کاپ قفل گرفته شد! پاسخ: %s", rec.Body.String())
	}

	after, err := getPlayerByUsername(ctx, name)
	if err != nil {
		t.Fatalf("بازیکن خوانده نشد: %v", err)
	}
	if after.Coins != 0 || after.Gems != 0 {
		t.Fatalf("جایزه واریز شد: %d سکه، %d جم", after.Coins, after.Gems)
	}
	if len(currentSeasonCups(after).Claimed) != 0 {
		t.Fatalf("کاپ قفل داخل claimed رفت")
	}
}

// کاپ باز فقط یک بار جایزه می‌دهد (دوبار زدن دکمه = دوبار جایزه نه)
func TestClaimSeasonCupIsIdempotent(t *testing.T) {
	ctx := withDB(t)
	if err := seedSeasonCups(ctx); err != nil {
		t.Skipf("seed نشد: %v", err)
	}
	defs := seasonCupDefs(ctx)
	target := defs[0]

	name := "cup_test_rich"
	seedCupPlayer(t, ctx, name, target.XPRequired+10)

	if rec := claimCup(t, name, target.CupID); rec.Code != http.StatusOK {
		t.Fatalf("کاپ باز گرفته نشد: %d %s", rec.Code, rec.Body.String())
	}
	if rec := claimCup(t, name, target.CupID); rec.Code == http.StatusOK {
		t.Fatalf("کاپ دوبار گرفته شد: %s", rec.Body.String())
	}

	after, err := getPlayerByUsername(ctx, name)
	if err != nil {
		t.Fatalf("بازیکن خوانده نشد: %v", err)
	}
	if after.Coins != target.RewardCoins || after.Gems != target.RewardGems {
		t.Fatalf("جایزه یک بار واریز نشد: %d سکه، %d جم (انتظار %d و %d)",
			after.Coins, after.Gems, target.RewardCoins, target.RewardGems)
	}

	// وضعیت همان کاپ باید «claimed» شود
	body := cupsOf(t, name)
	cups, _ := body["cups"].([]interface{})
	if len(cups) == 0 {
		t.Fatal("لیست کاپ خالی برگشت")
	}
	first, _ := cups[0].(map[string]interface{})
	if first["state"] != "claimed" {
		t.Fatalf("وضعیت کاپ گرفته‌شده %v است", first["state"])
	}
}

// کاپی که در کاتالوگ نیست هیچ‌وقت جایزه نمی‌دهد
func TestClaimUnknownSeasonCup(t *testing.T) {
	ctx := withDB(t)
	if err := seedSeasonCups(ctx); err != nil {
		t.Skipf("seed نشد: %v", err)
	}

	name := "cup_test_fake"
	seedCupPlayer(t, ctx, name, 999999)

	if rec := claimCup(t, name, "cup_99"); rec.Code == http.StatusOK {
		t.Fatalf("کاپ ناموجود گرفته شد: %s", rec.Body.String())
	}
	after, err := getPlayerByUsername(ctx, name)
	if err != nil {
		t.Fatalf("بازیکن خوانده نشد: %v", err)
	}
	if after.Coins != 0 || after.Gems != 0 {
		t.Fatalf("جایزه‌ی کاپ ناموجود واریز شد")
	}
}

// شمارش کاپ‌های جدول رتبه‌بندی باید با همان آستانه‌های دیتابیس بخواند
func TestSeasonCupCountUsesCatalog(t *testing.T) {
	ctx := withDB(t)
	if err := seedSeasonCups(ctx); err != nil {
		t.Skipf("seed نشد: %v", err)
	}
	defs := seasonCupDefs(ctx)

	if got := seasonCupCount(defs[0].XPRequired - 1); got != 0 {
		t.Fatalf("زیر آستانه‌ی اول %d کاپ شمرده شد", got)
	}
	if got := seasonCupCount(defs[len(defs)-1].XPRequired); got != len(defs) {
		t.Fatalf("بالای آخرین آستانه %d کاپ شمرده شد", got)
	}
}

// کش نباید بیشتر از TTL کهنه بماند
func TestSeasonCupCacheTTL(t *testing.T) {
	if seasonCupCacheTTL <= 0 || seasonCupCacheTTL > 5*time.Minute {
		t.Fatalf("TTL کش کاپ‌ها منطقی نیست: %v", seasonCupCacheTTL)
	}
}
