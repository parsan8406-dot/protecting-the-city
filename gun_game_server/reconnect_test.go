package main

import (
	"context"
	"encoding/json"
	"testing"
	"time"
)

// اتصالِ دوباره وسطِ مسابقه (reconnect.go). همه‌چیز مستقیم روی هاب و بدونِ
// سوکت و دیتابیس ساخته می‌شود — مثلِ بقیه‌ی تست‌های هاب.

// connectFake یک سوکتِ ساختگیِ وصل‌شده برای username
func connectFake(h *Hub, username string) *Client {
	c := &Client{hub: h, username: username, send: make(chan []byte, 512)}
	h.clients[c] = true
	if username != "" {
		h.sessions[username] = c
	}
	return c
}

// dropFake همان کاری که caseِ unregister با سوکتِ افتاده می‌کند
func dropFake(h *Hub, c *Client) {
	if _, ok := h.clients[c]; ok {
		h.closeClient(c)
		h.cleanupClient(c)
	}
}

// rejoinFake سوکتِ تازه + joinِ آرنا با پرچمِ rejoin (کلاینتِ جدید)
func rejoinFake(h *Hub, username string, rejoin bool) *Client {
	c := connectFake(h, "")
	raw := map[string]interface{}{}
	if rejoin {
		raw["rejoin"] = true
	}
	h.handleAction(c, WSMessage{Type: "join", Username: username, Arena: true, RawData: raw,
		loadout: &loadoutInfo{charID: "skin_default", weaponID: "ak47", charLevel: 1}})
	return c
}

// drain همه‌ی پیام‌های صفِ ارسالِ یک سوکت، به ترتیب
func drain(c *Client) []map[string]interface{} {
	var out []map[string]interface{}
	for {
		select {
		case data, ok := <-c.send:
			if !ok {
				return out
			}
			var m map[string]interface{}
			if json.Unmarshal(data, &m) == nil {
				out = append(out, m)
			}
		default:
			return out
		}
	}
}

func typesOf(msgs []map[string]interface{}) []string {
	var t []string
	for _, m := range msgs {
		t = append(t, m["type"].(string))
	}
	return t
}

func firstOf(msgs []map[string]interface{}, typ string) map[string]interface{} {
	for _, m := range msgs {
		if m["type"] == typ {
			return m
		}
	}
	return nil
}

// arenaPlayer بازیکنِ داخلِ زمینِ یک مسابقه
func arenaPlayer(h *Hub, name, team, match string, x, y float64) *Player {
	p := addPlayer(h, name, team, match, x, y)
	p.InArena = true
	return p
}

// ۱. برگشت در مهلت: همان Player، همان مسابقه و تیم و جان و کشته، و resync کامل.
func TestReconnectWithinGraceRestoresSamePlayer(t *testing.T) {
	h := NewHub()
	r := newRound(h, "rc1", map[string]string{"alice": "0", "bob": "1"}, nil)
	alice := arenaPlayer(h, "alice", "0", "rc1", 300, 400)
	bob := arenaPlayer(h, "bob", "1", "rc1", 320, 400)
	alice.Health, alice.Kills = 57, 2
	c1 := connectFake(h, "alice")
	connectFake(h, "bob")

	dropFake(h, c1)

	if h.players["alice"] != alice || !alice.Away || h.away["alice"] == nil {
		t.Fatalf("disconnect in a live round must keep the player as away (away=%v rec=%v)", alice.Away, h.away["alice"])
	}
	if !r.Alive["alice"] || h.playerRound["alice"] != "rc1" {
		t.Fatal("away player must stay in the round")
	}
	if h.validateHit(bob, "alice") || canBeHurt(alice, time.Now().Add(time.Hour)) {
		t.Fatal("away player must be invulnerable")
	}
	if got := h.pickTarget(bob); got != nil && got.Username == "alice" {
		t.Fatal("bots must not target an away player")
	}
	// بقیه پرچمِ away را در لیستِ بازیکن‌ها می‌بینند
	h.broadcastPlayerUpdate()
	if alice.AwayLeft <= 0 || alice.AwayLeft > reconnectGrace.Seconds() {
		t.Fatalf("away_left not published: %v", alice.AwayLeft)
	}

	c2 := rejoinFake(h, "alice", true)

	if h.players["alice"] != alice || alice.Health != 57 || alice.Kills != 2 ||
		alice.Team != "0" || alice.MatchID != "rc1" || alice.X != 300 || alice.Y != 400 {
		t.Fatalf("rejoin rebuilt/changed the player: same=%v hp=%d kills=%d team=%s match=%s",
			h.players["alice"] == alice, alice.Health, alice.Kills, alice.Team, alice.MatchID)
	}
	if alice.Away || h.away["alice"] != nil || h.sessions["alice"] != c2 {
		t.Fatal("rejoin must clear away state and move the session")
	}
	msgs := drain(c2)
	if len(msgs) == 0 || msgs[0]["type"] != "rejoin" || msgs[0]["ok"] != true {
		t.Fatalf("first message must be rejoin ok, got %v", typesOf(msgs))
	}
	sp := firstOf(msgs, "spawn")
	if sp == nil || sp["x"].(float64) != 300 || sp["y"].(float64) != 400 || sp["reconnect_grace"].(float64) <= 0 {
		t.Fatalf("resync spawn missing/wrong: %v", sp)
	}
	if hu := firstOf(msgs, "health_update"); hu == nil || hu["health"].(float64) != 57 {
		t.Fatalf("resync health missing/wrong: %v", hu)
	}
	for _, want := range []string{"round_state", "update_players"} {
		if firstOf(msgs, want) == nil {
			t.Fatalf("resync is missing %s: %v", want, typesOf(msgs))
		}
	}
	if !h.validateHit(bob, "alice") {
		t.Fatal("back player must be hittable again")
	}
}

// ۲. مهلت تمام شد: دقیقاً یک بار حذف و آزاد می‌شود، مثلِ قطعِ قدیمی.
func TestGraceExpiryEliminatesExactlyOnce(t *testing.T) {
	h := NewHub()
	r := newRound(h, "rc2", map[string]string{"alice": "0", "carl": "0", "bob": "1"}, nil)
	arenaPlayer(h, "alice", "0", "rc2", 100, 100)
	arenaPlayer(h, "carl", "0", "rc2", 120, 100)
	arenaPlayer(h, "bob", "1", "rc2", 900, 100)
	c1 := connectFake(h, "alice")
	connectFake(h, "carl")
	connectFake(h, "bob")

	dropFake(h, c1)
	h.away["alice"].deadline = time.Now().Add(-time.Millisecond)

	h.tickAway(time.Now())
	if _, ok := h.players["alice"]; ok {
		t.Fatal("expired away player must be removed")
	}
	if r.Alive["alice"] || r.Ended {
		t.Fatalf("expiry must eliminate alice only (alive=%v ended=%v)", r.Alive["alice"], r.Ended)
	}
	if h.away["alice"] != nil {
		t.Fatal("away record must be gone")
	}
	// تیک‌های بعدی و فراخوانیِ دوباره کاری نمی‌کنند
	h.tickAway(time.Now())
	h.expireAway("alice", "again")
	if r.Ended || !r.Alive["carl"] || !r.Alive["bob"] {
		t.Fatal("second expiry touched the round")
	}
	// برگشتِ دیرهنگام: جواب صادقانه، و نه زمینِ تمرینِ خالی
	c2 := rejoinFake(h, "alice", true)
	msgs := drain(c2)
	rj := firstOf(msgs, "rejoin")
	if rj == nil || rj["ok"] != false || rj["reason"] != "expired" {
		t.Fatalf("late rejoin must be refused as expired: %v", msgs)
	}
	if firstOf(msgs, "spawn") != nil {
		t.Fatal("refused rejoin must not spawn the player into an arena")
	}
	if p := h.players["alice"]; p == nil || p.InArena || p.MatchID != "" {
		t.Fatal("refused rejoin continues as a menu join")
	}
}

// ۲ب. آخرین آدمِ یک تیم که برنمی‌گردد: راندِ حذفی بعد از مهلت تمام می‌شود.
func TestGraceExpiryCanEndEliminationRound(t *testing.T) {
	h := NewHub()
	r := newRound(h, "rc2b", map[string]string{"alice": "0", "bob": "1"}, nil)
	arenaPlayer(h, "alice", "0", "rc2b", 100, 100)
	arenaPlayer(h, "bob", "1", "rc2b", 900, 100)
	c1 := connectFake(h, "alice")
	connectFake(h, "bob")
	dropFake(h, c1)
	if r.Ended {
		t.Fatal("round must not end while alice is away")
	}
	h.away["alice"].deadline = time.Now().Add(-time.Millisecond)
	h.tickAway(time.Now())
	if !r.Ended || r.WinnerTeam != "1" {
		t.Fatalf("round should end for team 1 after expiry (ended=%v winner=%q)", r.Ended, r.WinnerTeam)
	}
}

// ۳. مسابقه در نبودش تمام شد: پاداش ثبت می‌شود و match_over + match_reward
// با برگشتنش تحویل داده می‌شوند.
func TestRoundEndingDuringGraceDeliversResultOnReturn(t *testing.T) {
	h := NewHub()
	prevHub, prevFn := globalHub, applyMatchOutcomeFn
	globalHub = h
	granted := make(chan MatchOutcome, 4)
	applyMatchOutcomeFn = func(_ context.Context, username, _ string, outcome MatchOutcome, kills int) (map[string]interface{}, error) {
		granted <- outcome
		return map[string]interface{}{"coins_gained": 40, "kills": kills}, nil
	}
	defer func() { globalHub, applyMatchOutcomeFn = prevHub, prevFn }()

	r := newRound(h, "rc3", map[string]string{"alice": "0", "bob": "1"}, []string{"alice"})
	arenaPlayer(h, "alice", "0", "rc3", 100, 100)
	arenaPlayer(h, "bob", "1", "rc3", 900, 100)
	r.Kills["alice"] = 3
	c1 := connectFake(h, "alice")
	connectFake(h, "bob")
	dropFake(h, c1)

	h.endRound(r, "0", false)

	select {
	case o := <-granted:
		if o != OutcomeWin {
			t.Fatalf("away winner must still get a win, got %v", o)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("reward was never granted for the away player")
	}
	// پیامِ match_reward از گوروتین به صفِ notify می‌رسد؛ مثلِ حلقه‌ی هاب پردازشش کن
	deadline := time.Now().Add(2 * time.Second)
	for len(h.notify) == 0 && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	last := time.Now()
	h.runOnce(&last)
	h.tickAway(time.Now())
	if _, ok := h.players["alice"]; ok || h.away["alice"] != nil {
		t.Fatal("away player of a finished round must be released")
	}
	if !h.inboxHas("alice", "match_over") || !h.inboxHas("alice", "match_reward") {
		t.Fatalf("result must wait in the inbox: %+v", h.inbox["alice"])
	}

	c2 := rejoinFake(h, "alice", true)
	msgs := drain(c2)
	got := typesOf(msgs)
	if len(got) < 3 || got[0] != "rejoin" || msgs[0]["ok"] != false || msgs[0]["reason"] != "match_over" {
		t.Fatalf("expected rejoin(match_over) first, got %v", got)
	}
	if firstOf(msgs, "match_over") == nil || firstOf(msgs, "match_reward") == nil {
		t.Fatalf("result not delivered on return: %v", got)
	}
	if firstOf(msgs, "spawn") != nil {
		t.Fatal("no arena spawn after the match is over")
	}
	if len(h.inbox["alice"]) != 0 {
		t.Fatal("inbox must be emptied after delivery")
	}
}

// ۴. نشستِ تکراری: سوکتِ دوم جای اولی را می‌گیرد، بسته شدنِ سوکتِ قدیمی
// نه غیبت می‌سازد نه حذف؛ دو برگشتِ پشتِ‌سرِهم هم یک Player می‌مانند.
func TestDuplicateSessionsKeepOnePlayer(t *testing.T) {
	h := NewHub()
	newRound(h, "rc4", map[string]string{"alice": "0", "bob": "1"}, nil)
	alice := arenaPlayer(h, "alice", "0", "rc4", 200, 200)
	arenaPlayer(h, "bob", "1", "rc4", 900, 100)
	alice.Health = 80
	c1 := connectFake(h, "alice")

	c2 := rejoinFake(h, "alice", false)
	if !c1.closed || h.sessions["alice"] != c2 {
		t.Fatal("second socket must replace the first")
	}
	h.cleanupClient(c1) // unregisterِ دیرهنگامِ سوکتِ قدیمی
	if alice.Away || h.away["alice"] != nil || h.players["alice"] != alice {
		t.Fatal("closing the replaced socket must not mark the player away")
	}

	// قطع، بعد دو سوکتِ تازه با هم برمی‌گردند (دو تلاشِ هم‌زمانِ کلاینت)
	dropFake(h, c2)
	c3 := rejoinFake(h, "alice", true)
	c4 := rejoinFake(h, "alice", true)
	if !c3.closed || h.sessions["alice"] != c4 || h.players["alice"] != alice || alice.Health != 80 || alice.Away {
		t.Fatal("racing rejoins must end with one live session on the same player")
	}
	if rj := firstOf(drain(c4), "rejoin"); rj == nil || rj["ok"] != true {
		t.Fatal("second rejoin must still be told ok")
	}
	dropFake(h, c3) // سوکتِ کنارگذاشته‌شده دیگر در h.clients نیست
	if alice.Away {
		t.Fatal("stale socket made the player away")
	}
}

// ۵. کلاینتِ قدیمی: بعد از اتصالِ دوباره فقط joinِ منو می‌فرستد. غیبت تا
// اولین حرکتِ همان سوکت ادامه دارد، بعد برمی‌گردد.
func TestLegacyClientResumesOnFirstMove(t *testing.T) {
	h := NewHub()
	newRound(h, "rc5", map[string]string{"alice": "0", "bob": "1"}, nil)
	alice := arenaPlayer(h, "alice", "0", "rc5", 200, 200)
	arenaPlayer(h, "bob", "1", "rc5", 900, 100)
	c1 := connectFake(h, "alice")
	dropFake(h, c1)

	c2 := connectFake(h, "")
	h.handleAction(c2, WSMessage{Type: "join", Username: "alice", RawData: map[string]interface{}{},
		loadout: &loadoutInfo{charID: "skin_default", weaponID: "ak47", charLevel: 1}})
	if !alice.Away || h.players["alice"] != alice {
		t.Fatal("a plain menu join must not resume the match")
	}
	h.handleAction(c2, WSMessage{Type: "shoot", RawData: map[string]interface{}{}})
	h.handleAction(c2, WSMessage{Type: "move", X: 205, Y: 200, RawData: map[string]interface{}{}})
	if alice.Away || h.away["alice"] != nil {
		t.Fatal("first move from the new socket must resume")
	}
}

// ۶. بودجه‌ی غیبت: قطع و وصلِ پشتِ‌سرِهم مهلتِ تازه نمی‌سازد.
func TestAwayBudgetIsPerMatch(t *testing.T) {
	h := NewHub()
	r := newRound(h, "rc6", map[string]string{"alice": "0", "carl": "0", "bob": "1"}, nil)
	arenaPlayer(h, "alice", "0", "rc6", 200, 200)
	arenaPlayer(h, "carl", "0", "rc6", 220, 200)
	arenaPlayer(h, "bob", "1", "rc6", 900, 100)

	c := connectFake(h, "alice")
	dropFake(h, c)
	h.away["alice"].since = time.Now().Add(-(reconnectGrace - time.Second)) // ~۲۴ ثانیه غایب بود
	c = rejoinFake(h, "alice", true)
	dropFake(h, c)
	if h.away["alice"] != nil {
		t.Fatal("exhausted away budget must not grant another grace")
	}
	if _, ok := h.players["alice"]; ok || r.Alive["alice"] {
		t.Fatal("without budget the disconnect is the old immediate elimination")
	}
}

// ۷. قطعِ کوتاه توی صفِ جستجو بازیکن را از صف بیرون نمی‌اندازد.
func TestShortDisconnectKeepsMatchmakingQueue(t *testing.T) {
	resetMM()
	defer resetMM()
	h := NewHub()
	mmMu.Lock()
	mmQueues["strike"] = append(mmQueues["strike"], &QueuedPlayer{Username: "q1", joinedAt: time.Now()})
	mmMu.Unlock()
	addPlayer(h, "q1", "", "", 0, 0)
	c := connectFake(h, "q1")

	dropFake(h, c)
	if !inMatchmaking("q1") || h.away["q1"] == nil {
		t.Fatal("a queued player must survive a short disconnect")
	}
	// برگشت: صف همان می‌ماند و غیبت پاک می‌شود
	c2 := connectFake(h, "")
	h.handleAction(c2, WSMessage{Type: "join", Username: "q1", RawData: map[string]interface{}{},
		loadout: &loadoutInfo{charID: "skin_default", weaponID: "ak47", charLevel: 1}})
	if h.away["q1"] != nil || !inMatchmaking("q1") {
		t.Fatal("rejoin must cancel the deferred release")
	}
	// این بار برنمی‌گردد: بعد از مهلت از صف بیرون می‌رود
	dropFake(h, c2)
	h.away["q1"].deadline = time.Now().Add(-time.Millisecond)
	h.tickAway(time.Now())
	deadline := time.Now().Add(time.Second)
	for inMatchmaking("q1") && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond) // ReleasePlayer در گوروتین است
	}
	if inMatchmaking("q1") {
		t.Fatal("expired queued player must leave the queue")
	}
}

// ۸. بیرون انداختن از پنلِ مدیریت مهلتِ برگشت ندارد.
func TestKickedClientGetsNoGrace(t *testing.T) {
	h := NewHub()
	r := newRound(h, "rc8", map[string]string{"alice": "0", "carl": "0", "bob": "1"}, nil)
	arenaPlayer(h, "alice", "0", "rc8", 200, 200)
	arenaPlayer(h, "carl", "0", "rc8", 220, 200)
	arenaPlayer(h, "bob", "1", "rc8", 900, 100)
	c := connectFake(h, "alice")
	c.noGrace = true
	dropFake(h, c)
	if h.away["alice"] != nil || r.Alive["alice"] {
		t.Fatal("kicked player must be eliminated immediately")
	}
}
