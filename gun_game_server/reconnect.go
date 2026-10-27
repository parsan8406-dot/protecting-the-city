package main

import (
	"encoding/json"
	"fmt"
	"time"
)

// اتصالِ دوباره وسطِ مسابقه (auto-reconnect).
//
// اینترنتِ موبایل مدام چند ثانیه‌ای قطع می‌شود: عوض شدنِ وای‌فای/دیتا،
// آسانسور، تماسِ تلفنی، رفتنِ اپ به پس‌زمینه. قبلاً هر قطعی‌ای همان لحظه
// یعنی «حذف از راند، آزاد شدنِ صندلی، باخت» — بازیکنی که دو ثانیه بعد
// برمی‌گشت دیگر هیچ راهی به همان مسابقه نداشت.
//
// حالا وقتی سوکتِ یک آدمِ داخلِ مسابقه‌ی در جریان بسته می‌شود، بازیکنش
// reconnectGrace ثانیه «غایب» (Away) می‌ماند: سر جایش یخ می‌زند و آسیب
// نمی‌بیند (نه تیر، نه ترکش، نه لیزر، نه نفرین؛ بات‌ها هم نشانه‌اش نمی‌گیرند)
// و بقیه در update_players پرچمِ away را می‌بینند. اگر در این مدت با همان
// نام (و همان توکنِ دستگاه — wsJoinAllowed در readPump) برگردد، سوکتِ تازه
// به همان Player می‌چسبد و همه‌چیزِ لازم برای ادامه دوباره فرستاده می‌شود.
// اگر برنگردد، دقیقاً همان کارِ قدیمیِ قطعِ اتصال انجام می‌شود.
//
// چرا «یخ‌زده و آسیب‌ناپذیر» و نه «ایستاده و قابلِ کشتن»: کسی که نتش رفته
// هیچ کاری از دستش برنمی‌آید؛ کشتنِ او کشتنِ یک مجسمه است و برگشتنش را
// بی‌معنی می‌کند (E13). سوءاستفاده («قطع کن تا نمیری») با دو چیز بسته است:
// غایب هم نمی‌تواند شلیک کند/حرکت کند، و سقفِ غیبت برای هر نفر در هر
// مسابقه جمعاً reconnectGrace است (awayUsed) — قطع و وصلِ پشتِ‌سرِهم
// بودجه‌ی تازه نمی‌سازد.

const (
	// reconnectGrace مدتی که جای بازیکنِ قطع‌شده در مسابقه نگه داشته می‌شود.
	//
	// ۲۵ ثانیه: کلاینت قطعی را حداکثر ~۵ ثانیه بعد می‌فهمد و با فاصله‌های
	// ۱، ۲، ۳، ۴ ثانیه دوباره وصل می‌شود — یعنی حدودِ شش تلاش در این بازه.
	// جابه‌جاییِ وای‌فای↔دیتا و قطعی‌های کوتاهِ موبایل معمولاً زیرِ ده ثانیه‌اند.
	// بیشتر از این، در مسابقه‌ی ۳-۵ دقیقه‌ای تیمش زیادی ناقص می‌ماند و یک
	// مجسمه‌ی آسیب‌ناپذیر جلوی بقیه می‌ایستد.
	reconnectGrace = 25 * time.Second

	// staleLinkAfter سوکتی که بازیکنش داخلِ مسابقه‌ی در جریان است و این‌قدر
	// هیچ پیامی نفرستاده مرده حساب می‌شود و سرور خودش می‌بندد.
	//
	// HUDِ کلاینت هر ۲ ثانیه پینگ می‌فرستد (و حرکت ۲۰ بار در ثانیه)، پس ۱۰
	// ثانیه سکوت یعنی پنج پینگِ پشتِ‌سرِهم گم شده — یا اپ رفته پس‌زمینه. بدونِ
	// این، سوکتِ نیمه‌باز تا pongWait (۶۰ ثانیه) زنده می‌ماند و بازیکنِ قطع‌شده
	// تمام آن مدت قابلِ کشتن بود.
	staleLinkAfter = 10 * time.Second

	// inboxTTL پیام‌های پایانِ مسابقه (match_over / match_reward) که به غایب
	// نرسیده‌اند تا این مدت نگه داشته می‌شوند تا با برگشتنش تحویلش شوند.
	inboxTTL = 3 * time.Minute

	// minGraceLeft کمتر از این بودجه یعنی غیبتِ تازه معنی ندارد — همان
	// حذفِ فوریِ قدیمی.
	minGraceLeft = 2 * time.Second
)

// awayState بازیکنی که سوکتش افتاده و جایش نگه داشته شده.
type awayState struct {
	since    time.Time
	deadline time.Time
	matchID  string
	// menu یعنی داخلِ زمین نبود: در صفِ جستجو بود یا مسابقه‌اش جور شده بود و
	// هنوز داشت زمین را بار می‌کرد. آن‌جا فقط آزاد کردنِ صف/صندلی عقب می‌افتد.
	menu bool
}

// inboxItem پیامی که برای غایب نگه داشته شده
type inboxItem struct {
	data []byte
	kind string
	at   time.Time
}

// awayKey کلیدِ بودجه‌ی غیبتِ یک نفر در یک مسابقه
func awayKey(matchID, username string) string { return matchID + ":" + username }

// liveRoundOf راندِ در جریانِ یک مسابقه (nil یعنی تمام شده یا اصلاً نیست)
func (h *Hub) liveRoundOf(matchID string) *RoundState {
	if matchID == "" {
		return nil
	}
	if r := h.rounds[matchID]; r != nil && !r.Ended {
		return r
	}
	return nil
}

// canResume آیا این Player هنوز جایی برای برگشتن دارد؟
//
// یا راندِ مسابقه‌اش در جریان است، یا (رفتارِ قدیمیِ joinِ تکراری) راندی
// ساخته نشده ولی صندلی‌اش در mmMatches هنوز همان مسابقه است.
func (h *Hub) canResume(p *Player) bool {
	if p == nil || !p.InArena || p.MatchID == "" {
		return false
	}
	if h.liveRoundOf(p.MatchID) != nil {
		return true
	}
	if r := h.rounds[p.MatchID]; r != nil {
		return false // راند تمام شده — دیگر جایی برای برگشتن نیست
	}
	m := MatchOf(p.Username)
	return m != nil && m.MatchID == p.MatchID
}

// graceBudgetOf مهلتِ برگشتی که این بازیکن در مسابقه‌ی فعلی‌اش هنوز دارد
func (h *Hub) graceBudgetOf(username string) time.Duration {
	left := reconnectGrace
	if p := h.players[username]; p != nil && p.MatchID != "" {
		left -= h.awayUsed[awayKey(p.MatchID, username)]
	}
	if left < 0 {
		left = 0
	}
	return left
}

// inMatchmaking در صفِ جستجوست یا مسابقه‌اش جور شده (ولی هنوز در زمین نیست)
func inMatchmaking(username string) bool {
	mmMu.Lock()
	defer mmMu.Unlock()
	if mmMatches[username] != nil {
		return true
	}
	for _, q := range mmQueues {
		for _, qp := range q {
			if qp.Username == username {
				return true
			}
		}
	}
	return false
}

// beginGrace به‌جای حذفِ فوری، جای بازیکن را نگه می‌دارد. true یعنی
// پاک‌سازیِ معمول نباید انجام شود.
func (h *Hub) beginGrace(username string) bool {
	if _, isBot := h.bots[username]; isBot {
		return false
	}
	now := time.Now()
	if aw := h.away[username]; aw != nil {
		return true // همین حالا غایب است (سوکتِ موقتیِ دیگری افتاد) — مهلت عوض نمی‌شود
	}
	p := h.players[username]

	// داخلِ زمینِ یک مسابقه‌ی در جریان
	if p != nil && p.InArena && h.liveRoundOf(p.MatchID) != nil {
		left := reconnectGrace - h.awayUsed[awayKey(p.MatchID, username)]
		if left < minGraceLeft {
			return false // بودجه‌ی غیبتِ این مسابقه تمام شده
		}
		h.away[username] = &awayState{since: now, deadline: now.Add(left), matchID: p.MatchID}
		p.Away = true
		// هر کاری که داشت نیمه‌کاره می‌ماند: لیزر و دویدن نباید بی‌صاحب ادامه دهند
		p.LaserUntil = time.Time{}
		p.SprintUntil = time.Time{}
		fmt.Printf("📶 Player away (grace %v): %s in %s\n", left.Round(time.Second), username, p.MatchID)
		h.broadcastPlayerUpdate()
		return true
	}

	// توی منو، ولی در صف یا مسابقه‌ی جورشده: آزاد کردنِ صف عقب می‌افتد تا
	// یک قطعیِ کوتاه بازیکن را از صف بیرون نیندازد
	if (p == nil || !p.InArena) && inMatchmaking(username) {
		delete(h.players, username)
		delete(h.playerRound, username)
		h.away[username] = &awayState{since: now, deadline: now.Add(reconnectGrace), menu: true}
		fmt.Printf("📶 Queued player away (grace %v): %s\n", reconnectGrace, username)
		return true
	}
	return false
}

// forgetAway غیبت را بی‌سروصدا فراموش می‌کند (خروجِ عمدی، عوض شدنِ حساب)
func (h *Hub) forgetAway(username string) {
	aw := h.away[username]
	if aw == nil {
		return
	}
	delete(h.away, username)
	if p := h.players[username]; p != nil {
		p.Away = false
	}
}

// endAway بازیکن برگشت: پرچم برداشته و زمانِ غیبت از بودجه کم می‌شود.
func (h *Hub) endAway(username string) {
	aw := h.away[username]
	if aw == nil {
		return
	}
	delete(h.away, username)
	if !aw.menu && aw.matchID != "" {
		h.awayUsed[awayKey(aw.matchID, username)] += time.Since(aw.since)
	}
	if p := h.players[username]; p != nil {
		p.Away = false
		// یخ‌زده بود: حرکتِ بعدی از همین‌جا حساب شود، نه یک جهشِ ذخیره‌شده
		p.LastMoveTime = time.Now()
		p.MoveBudget = 0
		p.RotAt = time.Now()
	}
	fmt.Printf("✅ Player back after %v: %s\n", time.Since(aw.since).Round(100*time.Millisecond), username)
}

// expireAway مهلت تمام شد (یا مسابقه بی او تمام شد): دقیقاً همان کارِ قدیمیِ
// قطعِ اتصال، یک بار.
func (h *Hub) expireAway(username, why string) {
	aw := h.away[username]
	if aw == nil {
		return
	}
	delete(h.away, username)
	if aw.menu {
		mid := ""
		if m := MatchOf(username); m != nil {
			mid = m.MatchID
		}
		h.releaseAfterLeaving(username, mid)
	} else {
		if p := h.players[username]; p != nil {
			p.Away = false
		}
		h.onPlayerEliminated(username)
		delete(h.players, username)
		if h.playerRound[username] == aw.matchID {
			delete(h.playerRound, username)
		}
		h.releaseAfterLeaving(username, aw.matchID)
		h.broadcastPlayerUpdate()
	}
	if h.sessions[username] == nil {
		go SetPlayerOnline(username, false)
	}
	fmt.Printf("🔌 Player gone (%s): %s\n", why, username)
}

// tickAway مهلت‌ها، سوکت‌های بی‌صدا و صندوقِ پیام‌ها. روی گوروتینِ هاب
// (همان تیکِ بات‌ها) اجرا می‌شود.
func (h *Hub) tickAway(now time.Time) {
	for name, aw := range h.away {
		if now.After(aw.deadline) {
			h.expireAway(name, "grace expired")
			continue
		}
		// مسابقه بی او تمام شد: نتیجه‌اش (match_over/match_reward) در صندوق
		// منتظرش می‌ماند و خودش دیگر لازم نیست در زمین بماند
		if !aw.menu && h.liveRoundOf(aw.matchID) == nil {
			h.expireAway(name, "round over while away")
		}
	}
	if now.Sub(h.lastAwayScan) < time.Second {
		return
	}
	h.lastAwayScan = now
	h.closeSilentLinks(now)
	for name, items := range h.inbox {
		kept := items[:0]
		for _, it := range items {
			if now.Sub(it.at) < inboxTTL {
				kept = append(kept, it)
			}
		}
		if len(kept) == 0 {
			delete(h.inbox, name)
		} else {
			h.inbox[name] = kept
		}
	}
}

// closeSilentLinks سوکتِ بازیکنِ داخلِ مسابقه که staleLinkAfter هیچ پیامی
// نفرستاده بسته می‌شود؛ readPump خطا می‌گیرد و همان مسیرِ غیبت اجرا می‌شود.
func (h *Hub) closeSilentLinks(now time.Time) {
	for c := range h.clients {
		if c.conn == nil || c.idleClosed || c.username == "" || h.sessions[c.username] != c {
			continue
		}
		p := h.players[c.username]
		if p == nil || !p.InArena || p.Away || h.liveRoundOf(p.MatchID) == nil {
			continue
		}
		last := c.lastRx.Load()
		if last == 0 || now.Sub(time.Unix(0, last)) <= staleLinkAfter {
			continue
		}
		c.idleClosed = true
		fmt.Printf("📵 Silent link closed: %s (no message for %v)\n", c.username, now.Sub(time.Unix(0, last)).Round(time.Second))
		_ = c.conn.Close()
	}
}

// stashFor پیام را برای غایب (یا کسی که پیامِ پایانِ مسابقه‌اش در صندوق
// است) نگه می‌دارد. true یعنی نگه داشته شد.
func (h *Hub) stashFor(username, kind string, data []byte) bool {
	if username == "" || (h.away[username] == nil && len(h.inbox[username]) == 0) {
		return false
	}
	h.inbox[username] = append(h.inbox[username], inboxItem{data: data, kind: kind, at: time.Now()})
	return true
}

// inboxHas آیا پیامی از این نوع در صندوقِ این نفر هست؟
func (h *Hub) inboxHas(username, kind string) bool {
	for _, it := range h.inbox[username] {
		if it.kind == kind {
			return true
		}
	}
	return false
}

// flushInbox پیام‌های جامانده را به سوکتِ تازه می‌فرستد (به همان ترتیب)
func (h *Hub) flushInbox(client *Client) {
	items := h.inbox[client.username]
	if len(items) == 0 {
		return
	}
	delete(h.inbox, client.username)
	for _, it := range items {
		h.sendTo(client, it.data)
	}
}

// sendRejoin جوابِ صریح به کلاینتی که می‌خواهد به مسابقه‌اش برگردد.
// reason وقتی ok نیست: match_over (در نبودت تمام شد؛ نتیجه پشتِ این پیام
// می‌آید) یا expired (مهلت تمام شد و جایت آزاد شد).
func (h *Hub) sendRejoin(client *Client, ok bool, reason, matchID string) {
	payload := map[string]interface{}{"type": "rejoin", "ok": ok}
	if reason != "" {
		payload["reason"] = reason
	}
	if matchID != "" {
		payload["match_id"] = matchID
	}
	data, _ := json.Marshal(payload)
	h.sendTo(client, data)
}

// resyncPlayer هرچه یک تازه‌واردِ وسطِ مسابقه لازم دارد، فقط برای همین سوکت:
// جا و نقشه و محافظ، وضعیتِ راند، جانِ خودش، هدف‌ها و شیطان. لیستِ
// بازیکن‌ها (تیم، کشته، بمب، سپرها، غایب‌ها) هم بعدش پخش می‌شود.
func (h *Hub) resyncPlayer(client *Client, p *Player) {
	shield := time.Until(p.InvulnerableUntil)
	if shield < 0 {
		shield = 0
	}
	mode := ModeOfMatch(p.MatchID)
	if r := h.rounds[p.MatchID]; r != nil && r.ModeID != "" {
		mode = r.ModeID
	}
	h.sendSpawn(client, p.X, p.Y, MapNameForMode(mode), ThemeOfMatch(p.Username), shield)
	hp, _ := json.Marshal(map[string]interface{}{"type": "health_update", "username": p.Username, "health": p.Health})
	h.sendTo(client, hp)
	if r := h.rounds[p.MatchID]; r != nil {
		h.broadcastRoundState(r)
		if r.Demon != nil {
			h.broadcastDemonState(r)
		}
		if list := r.Objectives[p.Username]; len(list) > 0 {
			data, _ := json.Marshal(map[string]interface{}{"type": "objectives", "list": list})
			h.sendTo(client, data)
		}
	}
}

// handleRejoin بخشِ «برگشت» از caseِ join. نشست (h.sessions) از قبل به این
// سوکت داده شده. handled یعنی join همین‌جا تمام شد؛ quiet یعنی ادامه‌ی join
// به‌صورتِ joinِ منو و بدونِ پیامِ spawn (کلاینت در حالِ رفتن به صفحه‌ی
// نتیجه/منوست و نباید زیرش نقشه عوض شود).
func (h *Hub) handleRejoin(client *Client, msg *WSMessage) (handled, quiet bool) {
	name := msg.Username
	rejoin, _ := msg.RawData["rejoin"].(bool)
	aw := h.away[name]
	p := h.players[name]

	if p != nil && h.canResume(p) {
		// joinِ منو در حالِ غیبت (دستگاهِ دیگر یا کلاینتِ قدیمی که بعد از
		// اتصالِ دوباره joinِ آرنا نمی‌فرستد): فقط نشست وصل می‌شود؛ غیبت
		// ادامه دارد تا یا joinِ آرنا برسد یا اولین حرکت (move) نشان دهد که
		// همین سوکت واقعاً در زمین است.
		if aw != nil && !msg.Arena && !rejoin {
			h.flushInbox(client)
			return true, false
		}
		wasAway := aw != nil
		h.endAway(name)
		if rejoin || wasAway {
			h.sendRejoin(client, true, "", p.MatchID)
		}
		if msg.Arena || rejoin {
			h.resyncPlayer(client, p)
		}
		h.flushInbox(client)
		h.broadcastPlayerUpdate()
		return true, false
	}

	// جایی برای برگشتن نمانده
	if aw != nil {
		if aw.menu {
			delete(h.away, name) // برگشت به منو/صف — صندلیِ صف آزاد نمی‌شود
		} else {
			h.expireAway(name, "round over while away")
		}
	}
	if rejoin && msg.Arena {
		if m := MatchOf(name); m != nil {
			return false, false // مسابقه‌ی جورشده‌ای که هنوز واردش نشده — ورودِ معمولی
		}
		reason := "expired"
		if h.inboxHas(name, "match_over") {
			reason = "match_over"
		}
		h.sendRejoin(client, false, reason, "")
		msg.Arena = false
		return false, true
	}
	return false, false
}

// resumeByMove کلاینتِ قدیمی بعد از اتصالِ دوباره فقط joinِ منو می‌فرستد ولی
// هنوز در زمین است و حرکت می‌فرستد: همین حرکت یعنی برگشته.
func (h *Hub) resumeByMove(client *Client, p *Player) bool {
	if h.away[client.username] == nil || h.sessions[client.username] != client || !h.canResume(p) {
		return false
	}
	h.endAway(client.username)
	h.resyncPlayer(client, p)
	h.broadcastPlayerUpdate()
	return true
}
