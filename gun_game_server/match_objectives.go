package main

import (
	"context"
	"encoding/json"
	"log"
	"time"
)

// «اهداف» سمتِ چپِ زمینِ بازی: ماموریت‌های روزانه و چالش‌های فصل (رنک) که
// هنوز تمام نشده‌اند.
//
// مسیر:
//  1. ورود به آرنا → loadObjectivesAsync ماموریت‌های باز را از دیتابیس
//     می‌خواند (گوروتینِ جدا، چون حلقه‌ی Hub نباید منتظرِ دیتابیس بماند) و
//     نتیجه را با اکشنِ درونیِ objectives_loaded به همان حلقه برمی‌گرداند.
//  2. کلاینت پیامِ objectives می‌گیرد و هرکدام را با انیمیشن از کنار وارد
//     می‌کند.
//  3. کیل، کیل با نارنجک و درمانِ هم‌تیمی همان لحظه پیشرفت را جلو می‌برند
//     (objective_update)؛ برد، تعدادِ بازی، بدون مرگ و مدتِ بازی آخرِ راند.
//  4. آخرِ راند کلِ پیشرفت در daily_missions و آمارِ فصل ذخیره می‌شود — همان
//     جایی که صفحه‌ی ماموریت‌ها از آن می‌خواند.
//
// کلاینت هیچ عددی نمی‌فرستد؛ هرچه نشان می‌دهد همین‌جا ساخته شده.

// MaxLiveObjectives بیشتر از این تعداد هدف روی صفحه شلوغ می‌شود
const MaxLiveObjectives = 6

// LiveObjective یک ماموریتِ باز در طولِ مسابقه
type LiveObjective struct {
	ID       string        `json:"id"`   // "daily:kill_10" یا "ranked:season_kills_300"
	Kind     string        `json:"kind"` // daily | ranked
	Title    string        `json:"title"`
	Icon     string        `json:"icon"`
	Metric   MissionMetric `json:"metric"`
	Target   int           `json:"target"`
	Progress int           `json:"progress"`
	Done     bool          `json:"done"`
	// base پیشرفتِ ذخیره‌شده قبل از این مسابقه
	base int
}

// buildObjectives ماموریت‌های نیمه‌کاره را به هدف تبدیل می‌کند.
// گرفته‌شده‌ها و تمام‌شده‌ها کنار می‌روند — آن‌ها دیگر «هدف» نیستند.
func buildObjectives(doc *DailyMissionDoc, pass PlayerSeasonPass) []*LiveObjective {
	out := make([]*LiveObjective, 0, MaxLiveObjectives)
	if doc != nil {
		for _, st := range doc.Missions {
			def, ok := missionDefByID[st.MissionID]
			if !ok || st.Claimed || st.Progress >= def.Target {
				continue
			}
			out = append(out, &LiveObjective{
				ID: "daily:" + def.MissionID, Kind: "daily",
				Title: def.Title, Icon: def.Icon, Metric: def.Metric,
				Target: def.Target, Progress: st.Progress, base: st.Progress,
			})
		}
	}
	claimed := map[string]bool{}
	for _, id := range pass.ClaimedChallenges {
		claimed[id] = true
	}
	for _, c := range SeasonChallenges {
		prog := pass.Stats[string(c.Metric)]
		if claimed[c.ChallengeID] || prog >= c.Target {
			continue
		}
		out = append(out, &LiveObjective{
			ID: "ranked:" + c.ChallengeID, Kind: "ranked",
			Title: c.Title, Icon: c.Icon, Metric: c.Metric,
			Target: c.Target, Progress: prog, base: prog,
		})
	}
	if len(out) > MaxLiveObjectives {
		out = out[:MaxLiveObjectives]
	}
	return out
}

// liveDelta چیزی که همین راند به یک متریک اضافه کرده — فقط متریک‌هایی که
// وسطِ بازی عوض می‌شوند. بقیه (برد، بازی، ...) را finishObjectives حساب می‌کند.
func liveDelta(r *RoundState, username string, metric MissionMetric) int {
	switch metric {
	case MetricKills:
		return r.Kills[username]
	case MetricGrenadeKills:
		return r.GrenadeKills[username]
	case MetricHeals:
		return r.HealsGiven[username]
	case MetricAssists:
		return r.Assists[username]
	}
	return 0
}

// loadObjectivesAsync ماموریت‌های باز را بی‌آنکه حلقه‌ی Hub را نگه دارد می‌خواند.
func (h *Hub) loadObjectivesAsync(username, matchID string) {
	if db == nil || matchID == "" {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		pm, err := getPlayerByUsername(ctx, username)
		if err != nil {
			log.Printf("⚠️ objectives for %s: %v", username, err)
			return
		}
		doc, err := loadOrCreateDailyMissions(ctx, pm.PlayerID, time.Now())
		if err != nil {
			log.Printf("⚠️ daily missions for %s: %v", username, err)
			doc = nil
		}
		list := buildObjectives(doc, currentSeasonPass(pm))
		h.actions <- hubAction{msg: WSMessage{
			Type:     "objectives_loaded",
			Username: username,
			RawData:  map[string]interface{}{"match": matchID, "list": list},
		}}
	}()
}

// onObjectivesLoaded روی حلقه‌ی Hub: هدف‌ها را به راند می‌چسباند و به
// بازیکن می‌فرستد. اگر در همین فاصله کیلی گرفته، همان هم حساب می‌شود.
func (h *Hub) onObjectivesLoaded(msg WSMessage) {
	list, _ := msg.RawData["list"].([]*LiveObjective)
	matchID, _ := msg.RawData["match"].(string)
	r := h.roundOf(msg.Username)
	if r == nil || r.Ended || r.MatchID != matchID {
		return // مسابقه در این فاصله تمام شده
	}
	if r.Objectives == nil {
		r.Objectives = map[string][]*LiveObjective{}
	}
	for _, o := range list {
		o.Progress = minInt(o.base+liveDelta(r, msg.Username, o.Metric), o.Target)
		o.Done = o.Progress >= o.Target
	}
	r.Objectives[msg.Username] = list
	h.sendToUser(msg.Username, map[string]interface{}{"type": "objectives", "list": list})
}

// pushObjectiveProgress هدف‌های زنده‌ی یک بازیکن را با آمارِ راند هماهنگ می‌کند
// و هرکدام که عوض شده را می‌فرستد.
func (h *Hub) pushObjectiveProgress(r *RoundState, username string) {
	for _, o := range r.Objectives[username] {
		if o.Done {
			continue
		}
		d := liveDelta(r, username, o.Metric)
		if d <= 0 {
			continue
		}
		h.setObjectiveProgress(username, o, o.base+d)
	}
}

// setObjectiveProgress پیشرفتِ یک هدف را ست و در صورتِ تغییر ارسال می‌کند
func (h *Hub) setObjectiveProgress(username string, o *LiveObjective, progress int) {
	progress = minInt(progress, o.Target)
	if progress <= o.Progress {
		return
	}
	o.Progress = progress
	o.Done = progress >= o.Target
	h.sendToUser(username, map[string]interface{}{
		"type": "objective_update", "id": o.ID,
		"progress": o.Progress, "target": o.Target, "done": o.Done,
	})
}

// noteGrenadeKill یک کیل با نارنجک برای ماموریت‌ها
func (h *Hub) noteGrenadeKill(username string) {
	r := h.roundOf(username)
	if r == nil || r.Ended {
		return
	}
	if r.GrenadeKills == nil {
		r.GrenadeKills = map[string]int{}
	}
	r.GrenadeKills[username]++
	h.pushObjectiveProgress(r, username)
}

// assistWindow تا چند ثانیه بعد از آسیب زدن، کشته شدنِ همان قربانی به دستِ
// هم‌تیمی «کمک» حساب می‌شود
const assistWindow = 8 * time.Second

// noteDamage آسیبِ attacker به victim را برای حسابِ کمک ثبت می‌کند.
func (h *Hub) noteDamage(attacker, victim string) {
	if attacker == "" || attacker == victim {
		return
	}
	r := h.roundOf(victim)
	if r == nil || r.Ended {
		return
	}
	if r.Damagers == nil {
		r.Damagers = map[string]map[string]time.Time{}
	}
	if r.Damagers[victim] == nil {
		r.Damagers[victim] = map[string]time.Time{}
	}
	r.Damagers[victim][attacker] = time.Now()
}

// creditAssists هم‌تیمی‌های قاتل که در چند ثانیه‌ی اخیر به قربانی آسیب
// زده بودند یک «کمک» می‌گیرند. ردِ آسیب‌های این قربانی بعدش پاک می‌شود تا
// بعد از ریسپاون دوباره حساب نشود.
func (h *Hub) creditAssists(r *RoundState, killer, victim string) {
	dmg := r.Damagers[victim]
	delete(r.Damagers, victim)
	now := time.Now()
	for name, at := range dmg {
		if name == killer || now.Sub(at) > assistWindow {
			continue
		}
		if t, ok := r.Team[name]; !ok || t != r.Team[killer] {
			continue
		}
		if r.Assists == nil {
			r.Assists = map[string]int{}
		}
		r.Assists[name]++
		h.pushObjectiveProgress(r, name)
	}
}

// noteHealsGiven درمانِ هم‌تیمی‌ها (نه خودِ درمان‌کننده) برای ماموریت‌ها
func (h *Hub) noteHealsGiven(username string, n int) {
	r := h.roundOf(username)
	if r == nil || r.Ended || n <= 0 {
		return
	}
	if r.HealsGiven == nil {
		r.HealsGiven = map[string]int{}
	}
	r.HealsGiven[username] += n
	h.pushObjectiveProgress(r, username)
}

// finishObjectives آخرِ راند: هدف‌های آخرِ مسابقه تیک می‌خورند و کلِ پیشرفت
// ذخیره می‌شود. بازیکنی که وسطِ راند رفته حساب نمی‌شود (Player اش دیگر نیست).
func (h *Hub) finishObjectives(r *RoundState, winnerTeam string, draw bool) {
	secs := int64(time.Since(r.StartedAt).Seconds())
	for name := range r.Humans {
		p, ok := h.players[name]
		if !ok {
			continue
		}
		part := MatchParticipant{
			Username:     name,
			Kills:        r.Kills[name],
			Deaths:       p.Deaths,
			GrenadeKills: r.GrenadeKills[name],
			HealsGiven:   r.HealsGiven[name],
			Assists:      r.Assists[name],
			// همان قانونی که پاداشِ سرور با آن حساب می‌شود — از یک جا
			// (match_round.go → WonRound)، تا ماموریتِ «یک بازی ببر» با
			// کاپی که همان لحظه گرفته نخواند
			Won:        r.WonRound(name, winnerTeam, draw),
			WeaponUsed: p.Weapon,
		}
		deltas := missionDeltas(part, secs)
		for _, o := range r.Objectives[name] {
			if !o.Done && deltas[o.Metric] > 0 {
				h.setObjectiveProgress(name, o, o.base+deltas[o.Metric])
			}
		}
		if db != nil {
			go persistMatchMissions(name, r.ModeID, part, secs, draw)
		}
	}
}

// persistMatchMissions پیشرفتِ این مسابقه را در ماموریت‌های روزانه و آمارِ فصل
// می‌نویسد — همان توابعی که /match/result هم استفاده می‌کند.
func persistMatchMissions(username, modeID string, part MatchParticipant, secs int64, draw bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	pm, err := getPlayerByUsername(ctx, username)
	if err != nil {
		log.Printf("⚠️ mission progress for %s: %v", username, err)
		return
	}
	part.PlayerID = pm.PlayerID
	// تجربه‌ی این مسابقه همان چیزی است که ApplyMatchOutcome داد: WinXP در
	// برد، LoseXP در باخت و مساوی (قبلاً فقط برد شمرده می‌شد)
	if mode, err := gameModeByID(ctx, modeID); err == nil {
		if part.Won {
			part.XPGained = mode.WinXP
		} else {
			part.XPGained = mode.LoseXP
		}
	}
	if err := applyMatchToMissions(ctx, pm.PlayerID, part, secs); err != nil {
		log.Printf("⚠️ daily missions update for %s: %v", username, err)
	}
	if err := applyMatchToSeasonStats(ctx, pm.PlayerID, part, secs); err != nil {
		log.Printf("⚠️ season stats update for %s: %v", username, err)
	}
	// آمار پروفایل، «آخرین سلاح»، فرم اخیر و دستاوردها (achievements.go)
	if err := persistProfileStats(ctx, pm.PlayerID, modeID, part, secs, draw); err != nil {
		log.Printf("⚠️ profile stats update for %s: %v", username, err)
	}
}

// sendToUser پیام را فقط برای کلاینتِ یک بازیکن می‌فرستد (روی حلقه‌ی Hub)
func (h *Hub) sendToUser(username string, payload map[string]interface{}) {
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	for c := range h.clients {
		if c.username == username {
			h.sendTo(c, data)
		}
	}
}
