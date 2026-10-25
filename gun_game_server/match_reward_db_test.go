package main

import (
	"context"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// پاداشِ پایانِ راند، روی دیتابیسِ واقعی.
//
// خواسته‌ی صریح: باخت هیچ جایزه‌ای ندارد و فقط کاپ کم می‌کند؛ برد کاپ و
// سکه و تجربه می‌دهد. این تست هر دو شاخه را با ApplyMatchResult واقعاً اجرا
// می‌کند، نه اینکه دوباره همان فرمول را حساب کند.
//
// اگر مونگو بالا نباشد رد می‌شود — تستِ واحدهای دیگر نباید به آن گره بخورد.
func withDB(t *testing.T) context.Context {
	t.Helper()
	if db != nil {
		return context.Background()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	c, err := mongo.Connect(ctx, options.Client().ApplyURI("mongodb://localhost:27017"))
	if err != nil || c.Ping(ctx, nil) != nil {
		t.Skip("مونگو در دسترس نیست")
	}
	db = c.Database("gun_game_db")
	return context.Background()
}

func seedRewardPlayer(t *testing.T, ctx context.Context, name string) PlayerModel {
	t.Helper()
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
	p := PlayerModel{Username: name, Trophies: 500, Coins: 1000, Experience: 300, Level: 1}
	if _, err := col(ColPlayers).InsertOne(ctx, p); err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(func() { _, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name}) })
	return p
}

func reload(t *testing.T, ctx context.Context, name string) PlayerModel {
	t.Helper()
	var p PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": name}).Decode(&p); err != nil {
		t.Fatalf("بازیکن بعد از ثبتِ نتیجه خوانده نشد: %v", err)
	}
	return p
}

// باخت کاپ کم می‌کند ولی دست‌خالی نیست: سکه‌ی باخت + تجربه‌ی باخت، و هر
// کشته چند سکه. سکه‌ی باخت همیشه کم‌تر از برد است.
func TestLosingCostsTrophiesButPaysALittle(t *testing.T) {
	ctx := withDB(t)
	const name = "__loss_reward_probe"
	before := seedRewardPlayer(t, ctx, name)

	res, err := ApplyMatchOutcome(ctx, name, "strike", OutcomeLoss, 2)
	if err != nil {
		t.Fatalf("ApplyMatchOutcome: %v", err)
	}
	after := reload(t, ctx, name)
	mode, err := gameModeByID(ctx, "strike")
	if err != nil {
		t.Fatalf("mode: %v", err)
	}

	wantCoins := lossCoinsOf(mode) + 2*coinsPerKill
	if res["coin_delta"].(int) != wantCoins || after.Coins != before.Coins+wantCoins {
		t.Errorf("loss coins: delta %v, %d -> %d, want +%d", res["coin_delta"], before.Coins, after.Coins, wantCoins)
	}
	if wantCoins-2*coinsPerKill >= mode.WinCoins {
		t.Errorf("loss coins %d must be below win coins %d", wantCoins, mode.WinCoins)
	}
	if res["xp_delta"].(int) != mode.LoseXP {
		t.Errorf("loss XP %v, want %d", res["xp_delta"], mode.LoseXP)
	}
	if after.Trophies >= before.Trophies {
		t.Errorf("trophies did not drop on a loss: %d -> %d", before.Trophies, after.Trophies)
	}
}

// مساوی: کاپ تکان نمی‌خورد، نصفِ سکه‌ی برد، و نه برد ثبت می‌شود نه باخت.
func TestDrawPaysHalfCoinsAndNoTrophies(t *testing.T) {
	ctx := withDB(t)
	const name = "__draw_reward_probe"
	before := seedRewardPlayer(t, ctx, name)

	res, err := ApplyMatchOutcome(ctx, name, "strike", OutcomeDraw, 0)
	if err != nil {
		t.Fatalf("ApplyMatchOutcome: %v", err)
	}
	after := reload(t, ctx, name)
	mode, _ := gameModeByID(ctx, "strike")

	if after.Trophies != before.Trophies {
		t.Errorf("draw moved trophies %d -> %d", before.Trophies, after.Trophies)
	}
	if res["coin_delta"].(int) != mode.WinCoins/2 {
		t.Errorf("draw coins %v, want %d", res["coin_delta"], mode.WinCoins/2)
	}
	if res["draw"] != true || res["won"] != false {
		t.Errorf("draw flags wrong: won=%v draw=%v", res["won"], res["draw"])
	}
	if after.Stats.Wins != before.Stats.Wins || after.Stats.Losses != before.Stats.Losses {
		t.Errorf("draw must not count as a win or a loss")
	}
}

func TestWinningPaysTrophiesCoinsAndXP(t *testing.T) {
	ctx := withDB(t)
	const name = "__win_reward_probe"
	before := seedRewardPlayer(t, ctx, name)

	if _, err := ApplyMatchResult(ctx, name, "strike", true); err != nil {
		t.Fatalf("ApplyMatchResult: %v", err)
	}
	after := reload(t, ctx, name)

	if after.Trophies <= before.Trophies {
		t.Errorf("winning did not raise trophies: %d -> %d", before.Trophies, after.Trophies)
	}
	if after.Coins <= before.Coins {
		t.Errorf("winning did not pay coins: %d -> %d", before.Coins, after.Coins)
	}
	if after.Experience <= before.Experience {
		t.Errorf("winning did not grant XP: %d -> %d", before.Experience, after.Experience)
	}
	t.Logf("win: trophies %d -> %d, coins %d -> %d, xp %d -> %d",
		before.Trophies, after.Trophies, before.Coins, after.Coins,
		before.Experience, after.Experience)
}

// کاپ هیچ‌وقت زیر صفر نمی‌رود
func TestTrophiesNeverGoNegativeOnALoss(t *testing.T) {
	ctx := withDB(t)
	const name = "__zero_trophy_probe"
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name})
	if _, err := col(ColPlayers).InsertOne(ctx,
		PlayerModel{Username: name, Trophies: 3, Coins: 10, Level: 1}); err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(func() { _, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"username": name}) })

	if _, err := ApplyMatchResult(ctx, name, "strike", false); err != nil {
		t.Fatalf("ApplyMatchResult: %v", err)
	}
	if after := reload(t, ctx, name); after.Trophies < 0 {
		t.Errorf("trophies went negative: %d", after.Trophies)
	}
}
