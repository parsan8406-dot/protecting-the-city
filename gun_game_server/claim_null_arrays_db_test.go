package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// دریافت جایزه وقتی آرایه‌ی «گرفته‌شده‌ها» در دیتابیس null است.
//
// باگ واقعی: Go یک slice خالیِ nil را به‌صورت BSON null ذخیره می‌کند. مونگو
// $addToSet را روی null اجرا نمی‌کند («Cannot apply $addToSet to non-array
// field») و هندلرِ صندوق هر خطایی را «قبلاً گرفته شده» گزارش می‌کرد — پس
// بازیکن صندوقی را که هیچ‌وقت باز نکرده بود «گرفته‌شده» می‌دید.
//
// این تست‌ها دقیقاً همان رکوردِ خراب را می‌سازند و هندلر واقعی را صدا می‌زنند.

func seedClaimPlayer(t *testing.T, name string, extra bson.M) {
	t.Helper()
	ctx := withDB(t)
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
	doc := bson.M{
		"player_id":  name + "_id",
		"username":   name,
		"coins":      1000,
		"gems":       0,
		"experience": 0,
		"level":      1,
	}
	for k, v := range extra {
		doc[k] = v
	}
	if _, err := col(ColPlayers).InsertOne(ctx, doc); err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(func() {
		_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
		_, _ = col(ColDailyMissions).DeleteMany(ctx, bson.M{"player_id": name + "_id"})
	})
}

func postJSON(t *testing.T, handler http.HandlerFunc, body interface{}) (int, map[string]interface{}) {
	t.Helper()
	raw, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(raw))
	rec := httptest.NewRecorder()
	handler(rec, req)
	out := map[string]interface{}{}
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
}

func coinsOf(t *testing.T, name string) int {
	t.Helper()
	var p PlayerModel
	if err := col(ColPlayers).FindOne(withDB(t), bson.M{"username": name}).Decode(&p); err != nil {
		t.Fatalf("بازیکن خوانده نشد: %v", err)
	}
	return p.Coins
}

func TestDailyChestClaimWorksWhenBonusClaimedIsNull(t *testing.T) {
	ctx := withDB(t)
	const name = "__null_chest_probe"
	seedClaimPlayer(t, name, nil)

	// رکورد امروز دقیقاً مثل چیزی که در دیتابیس پیدا شد: bonus_claimed = null
	playerID := name + "_id"
	dayKey := missionDayKey(time.Now())
	states := bson.A{}
	for _, def := range pickDailyMissions(playerID, dayKey) {
		states = append(states, bson.M{"mission_id": def.MissionID, "progress": def.Target, "claimed": true})
	}
	if _, err := col(ColDailyMissions).InsertOne(ctx, bson.M{
		"player_id":     playerID,
		"day_key":       dayKey,
		"missions":      states,
		"bonus_claimed": nil,
		"created_at":    time.Now(),
		"updated_at":    time.Now(),
	}); err != nil {
		t.Skipf("نمی‌شود رکورد روزانه ساخت: %v", err)
	}

	before := coinsOf(t, name)
	code, body := postJSON(t, claimDailyBonusHandler, map[string]interface{}{"username": name, "need": 2})
	if code != http.StatusOK {
		t.Fatalf("صندوقِ بازنشده رد شد: %d %v", code, body["error"])
	}
	if got, want := coinsOf(t, name)-before, DailyBonusTiers[0].Coins; got != want {
		t.Fatalf("سکه‌ی صندوق واریز نشد: +%d، انتظار +%d", got, want)
	}

	// دوباره زدن باید واقعاً «قبلاً گرفته شده» باشد و چیزی واریز نکند
	after := coinsOf(t, name)
	code, _ = postJSON(t, claimDailyBonusHandler, map[string]interface{}{"username": name, "need": 2})
	if code != http.StatusBadRequest {
		t.Fatalf("دریافت دوباره باید رد شود، کد %d آمد", code)
	}
	if coinsOf(t, name) != after {
		t.Fatal("دریافت دوباره سکه واریز کرد")
	}
}

func TestNewDayRecordIsBornWithAnArray(t *testing.T) {
	ctx := withDB(t)
	const name = "__fresh_day_probe"
	seedClaimPlayer(t, name, nil)

	if _, err := loadOrCreateDailyMissions(ctx, name+"_id", time.Now()); err != nil {
		t.Fatalf("رکورد روز ساخته نشد: %v", err)
	}
	var raw bson.M
	if err := col(ColDailyMissions).FindOne(ctx, bson.M{"player_id": name + "_id"}).Decode(&raw); err != nil {
		t.Fatalf("رکورد روز خوانده نشد: %v", err)
	}
	if _, isArray := raw["bonus_claimed"].(bson.A); !isArray {
		t.Fatalf("bonus_claimed باید آرایه باشد، %T ذخیره شد", raw["bonus_claimed"])
	}
}

func TestSeasonTierClaimWorksWhenClaimedLevelsIsNull(t *testing.T) {
	const name = "__null_tier_probe"
	seedClaimPlayer(t, name, bson.M{"season_pass": bson.M{
		"season_id":      DefaultSeasonID,
		"xp":             seasonPassXPRequired(1),
		"claimed_levels": nil,
	}})

	before := coinsOf(t, name)
	code, body := postJSON(t, claimSeasonPassHandler,
		map[string]interface{}{"username": name, "level": 1, "track": "free"})
	if code != http.StatusOK {
		t.Fatalf("پله‌ی باز شده رد شد: %d %v", code, body["error"])
	}
	if got, want := coinsOf(t, name)-before, seasonPassReward(1).Coins; got != want {
		t.Fatalf("سکه‌ی پله واریز نشد: +%d، انتظار +%d", got, want)
	}
}

func TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(t *testing.T) {
	const name = "__null_challenge_probe"
	challenge := SeasonChallenges[0]
	seedClaimPlayer(t, name, bson.M{"season_pass": bson.M{
		"season_id":          DefaultSeasonID,
		"stats":              bson.M{string(challenge.Metric): challenge.Target},
		"claimed_challenges": nil,
	}})

	before := coinsOf(t, name)
	code, body := postJSON(t, claimSeasonChallengeHandler,
		map[string]interface{}{"username": name, "challenge_id": challenge.ChallengeID})
	if code != http.StatusOK {
		t.Fatalf("چالشِ تمام‌شده رد شد: %d %v", code, body["error"])
	}
	if got := coinsOf(t, name) - before; got != challenge.Coins {
		t.Fatalf("سکه‌ی چالش واریز نشد: +%d، انتظار +%d", got, challenge.Coins)
	}
}
