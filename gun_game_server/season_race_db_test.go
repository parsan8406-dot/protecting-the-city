package main

import (
	"sync"
	"testing"

	"go.mongodb.org/mongo-driver/bson"
)

// آخرِ هر مسابقه دو نویسنده هم‌زمان بتل‌پس را عوض می‌کنند (تجربه و آمارِ
// چالش‌ها). هیچ‌کدام نباید کارِ دیگری را پاک کند — حتی وقتی رکورد مالِ
// فصلِ قبل است و باید از نو ساخته شود.
func TestSeasonPassWritersDoNotEraseEachOther(t *testing.T) {
	ctx := withDB(t)
	const name, pid = "__season_race_probe", "pid_season_race_probe"
	_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"player_id": pid})
	defer col(ColPlayers).DeleteOne(ctx, bson.M{"player_id": pid})
	if _, err := col(ColPlayers).InsertOne(ctx, bson.M{
		"username": name, "player_id": pid,
		"season_pass": bson.M{"season_id": "old_season", "xp": 999, "stats": nil},
	}); err != nil {
		t.Skipf("cannot seed: %v", err)
	}

	part := MatchParticipant{Username: name, Kills: 3, Won: true}
	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(2)
		go func() { defer wg.Done(); _ = addSeasonPassXP(ctx, pid, 10) }()
		go func() { defer wg.Done(); _ = applyMatchToSeasonStats(ctx, pid, part, 70) }()
	}
	wg.Wait()

	p, err := getPlayerByID(ctx, pid)
	if err != nil {
		t.Fatal(err)
	}
	sp := p.SeasonPass
	if sp.SeasonID != DefaultSeasonID {
		t.Fatalf("season not rolled over: %q", sp.SeasonID)
	}
	if sp.XP != 50 {
		t.Errorf("season XP = %d, want 50 (old season's 999 dropped, 5×10 kept)", sp.XP)
	}
	if sp.Stats["kills"] != 15 || sp.Stats["wins"] != 5 || sp.Stats["matches"] != 5 {
		t.Errorf("stats lost: %v", sp.Stats)
	}
	if sp.Stats["playtime_seconds"] != 350 {
		t.Errorf("playtime seconds = %d, want 350", sp.Stats["playtime_seconds"])
	}
}
