package main

import (
	"testing"
	"time"
)

// استخرِ بات نباید با هر مسابقه آب برود.
//
// باگی که این تست جلویش را می‌گیرد: ورودی‌های mmMatches بعد از تمام شدنِ
// راند پاک نمی‌شدند، پس busyNamesLocked بات‌های مسابقه‌های قدیمی را هنوز
// «مشغول» می‌دید. بعد از چند مسابقه دیگر بات آزادی نمی‌ماند، صف نیمه‌پر
// می‌ماند و بازی عملاً از کار می‌افتاد.

func resetMM() {
	mmMu.Lock()
	mmQueues = map[string][]*QueuedPlayer{}
	mmMatches = map[string]*PendingMatch{}
	mmMu.Unlock()
}

func seedMatch(matchID string, names ...string) {
	mmMu.Lock()
	defer mmMu.Unlock()
	m := &PendingMatch{MatchID: matchID, ModeID: "strike", MadeAt: time.Now()}
	for i, n := range names {
		m.Players = append(m.Players, QueuedPlayer{Username: n, Team: i % 2})
	}
	for _, p := range m.Players {
		mmMatches[p.Username] = m
	}
}

func TestFinishedMatchesStopHoldingBotsHostage(t *testing.T) {
	resetMM()
	defer resetMM()

	seedMatch("m1", "human1", "botA", "botB")
	seedMatch("m2", "human2", "botC", "botD")

	mmMu.Lock()
	busy := busyNamesLocked()
	mmMu.Unlock()
	for _, n := range []string{"botA", "botB", "botC", "botD"} {
		if !busy[n] {
			t.Fatalf("%s should be busy while its match is live", n)
		}
	}

	// مسابقه‌ی اول تمام شد
	ReleaseMatch("m1")

	mmMu.Lock()
	busy = busyNamesLocked()
	mmMu.Unlock()
	for _, n := range []string{"botA", "botB"} {
		if busy[n] {
			t.Errorf("%s is still marked busy after its match ended — the bot pool leaks", n)
		}
	}
	// مسابقه‌ی دوم هنوز زنده است و نباید دست بخورد
	for _, n := range []string{"botC", "botD"} {
		if !busy[n] {
			t.Errorf("%s from the still-running match m2 was released by mistake", n)
		}
	}
}

// قطعِ اتصال هم باید اسم را آزاد کند، وگرنه بازیکن تا ابد «در مسابقه» می‌ماند
// و دفعه‌ی بعد که سرچ می‌کند جا نمی‌گیرد.
func TestDisconnectFreesTheNameForNextTime(t *testing.T) {
	resetMM()
	defer resetMM()

	seedMatch("m9", "quitter", "botX")
	mmMu.Lock()
	mmQueues["strike"] = append(mmQueues["strike"], &QueuedPlayer{
		Username: "quitter", joinedAt: time.Now()})
	mmMu.Unlock()

	ReleasePlayer("quitter")

	mmMu.Lock()
	busy := busyNamesLocked()
	stillQueued := false
	for _, p := range mmQueues["strike"] {
		if p.Username == "quitter" {
			stillQueued = true
		}
	}
	mmMu.Unlock()

	if stillQueued {
		t.Error("a disconnected player is still sitting in the queue")
	}
	if busy["quitter"] {
		t.Error("a disconnected player is still marked as being in a match")
	}
}

// شبیه‌سازیِ چند مسابقه‌ی پشتِ‌سرِ هم: اگر آزادسازی کار نکند، تعدادِ
// اسم‌های مشغول یک‌نواخت بالا می‌رود تا استخر تمام شود.
func TestBotPoolDoesNotShrinkOverManyMatches(t *testing.T) {
	resetMM()
	defer resetMM()

	for i := 0; i < 20; i++ {
		id := "m" + string(rune('a'+i%26)) + string(rune('0'+i/26))
		seedMatch(id, "human", "bot1", "bot2", "bot3", "bot4", "bot5", "bot6", "bot7")
		ReleaseMatch(id)
	}

	mmMu.Lock()
	busy := busyNamesLocked()
	mmMu.Unlock()
	if len(busy) != 0 {
		t.Errorf("after 20 finished matches, %d names are still held: %v", len(busy), busy)
	}
}
