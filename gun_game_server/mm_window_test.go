package main

import (
	"math/rand"
	"testing"
	"time"
)

// صفِ تمیز برای هر تست — صف و مسابقه‌ها متغیرِ سراسری‌اند
func resetQueues(t *testing.T) {
	t.Helper()
	mmMu.Lock()
	mmQueues = map[string][]*QueuedPlayer{}
	mmMatches = map[string]*PendingMatch{}
	mmMu.Unlock()
}

// بازیکن‌ها به ترتیبِ آرگومان وارد صف می‌شوند (اولی قدیمی‌ترین)
func enqueue(mode string, trophies ...int) []*QueuedPlayer {
	mmMu.Lock()
	defer mmMu.Unlock()
	var out []*QueuedPlayer
	// همه تازه‌وارد (کمتر از HumanSearchFor) تا بازه‌ی هم‌سطح بسته بماند؛
	// تست‌های بازه‌ی بازشده خودشان joinedAt را عقب می‌برند
	base := time.Now().Add(-5 * time.Second)
	for i, tr := range trophies {
		rankID, rankName := rankFromTrophies(tr)
		p := &QueuedPlayer{
			Username: "p" + string(rune('a'+len(mmQueues[mode]))),
			Trophies: tr, RankID: rankID, RankName: rankName,
			Team: -1, joinedAt: base.Add(time.Duration(i) * time.Second),
		}
		mmQueues[mode] = append(mmQueues[mode], p)
		out = append(out, p)
	}
	return out
}

func formNow(mode string, teamSize int) *PendingMatch {
	mmMu.Lock()
	defer mmMu.Unlock()
	return tryFormMatchLocked(mode, teamSize)
}

func trophiesOf(m *PendingMatch) map[int]bool {
	out := map[int]bool{}
	for _, p := range m.Players {
		out[p.Trophies] = true
	}
	return out
}

// اختلافِ بیش از ۲۰۰ کاپ هرگز حریف نمی‌شود
func TestMatchRespectsTrophyWindow(t *testing.T) {
	resetQueues(t)
	enqueue("revenge", 1000, 1300)
	if m := formNow("revenge", 1); m != nil {
		t.Fatalf("1000 vs 1300 (gap 300) must not match, got %v", trophiesOf(m))
	}
	enqueue("revenge", 1150)
	m := formNow("revenge", 1)
	if m == nil {
		t.Fatal("1000 and 1150 (gap 150) should match")
	}
	if got := trophiesOf(m); !got[1000] || !got[1150] {
		t.Fatalf("expected 1000+1150, got %v", got)
	}
	if left := mmQueues["revenge"]; len(left) != 1 || left[0].Trophies != 1300 {
		t.Fatalf("1300 should still be waiting, queue=%v", left)
	}
}

// درست ۲۰۰ کاپ فاصله هنوز قبول است
func TestWindowEdgeIsInclusive(t *testing.T) {
	resetQueues(t)
	enqueue("revenge", 800, 1000)
	if formNow("revenge", 1) == nil {
		t.Fatal("gap of exactly 200 should match")
	}
}

// بازیکنی که هم‌سطح ندارد صف را پشتِ خودش قفل نمی‌کند
func TestLonelyAnchorDoesNotBlockOthers(t *testing.T) {
	resetQueues(t)
	enqueue("revenge", 3000, 500, 600)
	m := formNow("revenge", 1)
	if m == nil {
		t.Fatal("500 and 600 should match even though 3000 came first")
	}
	if got := trophiesOf(m); !got[500] || !got[600] {
		t.Fatalf("expected 500+600, got %v", got)
	}
}

// از بینِ هم‌سطح‌ها نزدیک‌ترین‌ها انتخاب می‌شوند
func TestClosestPeersAreChosen(t *testing.T) {
	resetQueues(t)
	// لنگر ۱۰۰۰؛ ۱۱۹۰ داخلِ بازه است ولی از همه دورتر
	enqueue("banish", 1000, 1190, 1010, 1100, 950)
	m := formNow("banish", 2)
	if m == nil {
		t.Fatal("expected a 2v2 match")
	}
	if got := trophiesOf(m); got[1190] {
		t.Fatalf("1190 is the farthest peer and should wait, got %v", got)
	}
}

// تیم‌بندیِ ماری: جمعِ کاپِ دو تیم نزدیک می‌ماند
func TestSnakeDraftBalancesTeams(t *testing.T) {
	resetQueues(t)
	enqueue("banish", 1000, 1050, 1100, 1150)
	m := formNow("banish", 2)
	if m == nil {
		t.Fatal("expected a match")
	}
	sum := [2]int{}
	for _, p := range m.Players {
		sum[p.Team] += p.Trophies
	}
	if sum[0] != sum[1] {
		t.Fatalf("teams unbalanced: %v", sum)
	}
}

// تمِ زمین از بالاترین رنکِ مسابقه می‌آید
func TestThemeFollowsHighestRank(t *testing.T) {
	resetQueues(t)
	enqueue("revenge", 1590, 1700) // نقره و طلا
	m := formNow("revenge", 1)
	if m == nil {
		t.Fatal("expected a match")
	}
	if m.Theme != "ocean" {
		t.Fatalf("gold is the highest rank, theme should be ocean, got %q", m.Theme)
	}
}

// هر رنک به تمِ خودش؛ لجندری تصادفی بینِ جادویی و سرزمینِ مردگان
func TestRankThemeTable(t *testing.T) {
	want := map[string]string{
		"bronze": "hell", "silver": "heaven", "gold": "ocean",
		"platinum": "ice", "diamond": "pirate_ship",
	}
	for rank, theme := range want {
		if got := themeForRank(rank); got != theme {
			t.Errorf("%s -> %s, expected %s", rank, got, theme)
		}
	}
	seen := map[string]bool{}
	for i := 0; i < 200; i++ {
		seen[themeForRank("legend")] = true
	}
	if !seen["magic"] || !seen["underworld"] || len(seen) != 2 {
		t.Errorf("legend should pick magic or underworld, saw %v", seen)
	}
	if got := themeForRank("nope"); got != DefaultTheme {
		t.Errorf("unknown rank -> %s, expected %s", got, DefaultTheme)
	}
}

// بات‌ها: اول داخلِ بازه‌ی ۲۰۰، بعد نزدیک‌ترین‌ها
func TestBotsNearestTrophiesFirst(t *testing.T) {
	pool := []PlayerModel{}
	for _, tr := range []int{100, 900, 1000, 1150, 1400, 2500} {
		b := PlayerModel{Username: "bot" + string(rune('0'+tr/100)), Trophies: tr}
		pool = append(pool, b)
	}
	rng := rand.New(rand.NewSource(1))

	two := pickBotsNear(pool, nil, 2, 0, 1050, rng)
	for _, b := range two {
		if !withinWindow(b.Trophies, 1050) {
			t.Fatalf("with 3 bots inside the window, got %d outside it", b.Trophies)
		}
	}

	four := pickBotsNear(pool, nil, 4, 0, 1050, rng)
	if four[3].Trophies != 1400 {
		t.Fatalf("4th bot should be the nearest outside the window (1400), got %d", four[3].Trophies)
	}

	// مشغول و زیرِ حدِ نصاب کنار می‌روند
	busy := map[string]bool{pool[2].Username: true} // 1000
	got := pickBotsNear(pool, busy, 6, 950, 1050, rng)
	for _, b := range got {
		if b.Trophies == 1000 || b.Trophies < 950 {
			t.Fatalf("busy/under-minimum bot %d was picked", b.Trophies)
		}
	}
}

// بعد از HumanSearchFor بازه باز می‌شود: آدمِ دور از بات بهتر است
func TestWindowOpensAfterHumanSearch(t *testing.T) {
	resetQueues(t)
	ps := enqueue("revenge", 3000, 300)
	if formNow("revenge", 1) != nil {
		t.Fatal("fresh 3000 vs 300 must still wait for a closer opponent")
	}
	mmMu.Lock()
	ps[0].joinedAt = time.Now().Add(-HumanSearchFor - time.Second)
	mmMu.Unlock()
	m := formNow("revenge", 1)
	if m == nil {
		t.Fatal("after HumanSearchFor the two waiting humans should be matched together")
	}
	if got := trophiesOf(m); !got[3000] || !got[300] {
		t.Fatalf("expected 3000+300, got %v", got)
	}
}

// حتی با بازه‌ی باز، نزدیک‌ترین آدم‌ها اول انتخاب می‌شوند
func TestOpenWindowStillPrefersClosest(t *testing.T) {
	resetQueues(t)
	ps := enqueue("revenge", 1000, 2500, 1400)
	mmMu.Lock()
	ps[0].joinedAt = time.Now().Add(-HumanSearchFor - time.Second)
	mmMu.Unlock()
	m := formNow("revenge", 1)
	if m == nil {
		t.Fatal("expected a match")
	}
	if got := trophiesOf(m); !got[1000] || !got[1400] {
		t.Fatalf("expected 1000+1400 (closest), got %v", got)
	}
}
