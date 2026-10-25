package main

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// =============================================================================
// صفحه‌ی رنک → «کاپ ها»
//
//   GET  /season/cups?username=...        لیست کاپ‌ها + وضعیت بازیکن
//   POST /season/cups/claim {username, cup_id}   گرفتن جایزه‌ی یک کاپ
//
// ضدتقلب:
//   - لیست کاپ‌ها و جایزه‌شان فقط از کالکشن season_cups خوانده می‌شود
//   - تجربه‌ی فصل از سند بازیکن در دیتابیس می‌آید، نه از بدنه‌ی درخواست
//   - باز/قفل بودن را سرور حساب می‌کند و کلاینت فقط state را نشان می‌دهد
//   - واریز جایزه با آپدیت شرطیِ اتمیک است؛ دوبار زدن دکمه دوبار جایزه نمی‌دهد
// =============================================================================

// SeasonCupClaimBody بدنه‌ی POST /season/cups/claim
type SeasonCupClaimBody struct {
	Username string `json:"username"`
	CupID    string `json:"cup_id"`
}

// getSeasonCupsHandler کاپ‌های فصل و وضعیت بازیکن روی آن‌ها
func getSeasonCupsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "نام کاربری لازم است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	jsonResponse(w, buildSeasonCupsResponse(ctx, player))
}

// buildSeasonCupsResponse پاسخ /season/cups را از روی دیتابیس می‌سازد
func buildSeasonCupsResponse(ctx context.Context, player *PlayerModel) map[string]interface{} {
	defs := seasonCupDefs(ctx)
	state := currentSeasonCups(player)
	seasonXP := seasonXPOf(player)

	claimedSet := map[string]bool{}
	for _, id := range state.Claimed {
		claimedSet[id] = true
	}

	cups := make([]map[string]interface{}, 0, len(defs))
	unlocked, claimed, ready := 0, 0, 0
	claimableID := ""
	var next map[string]interface{}

	for _, def := range defs {
		isUnlocked := seasonXP >= def.XPRequired
		cupState := "locked"
		switch {
		case claimedSet[def.CupID]:
			cupState = "claimed"
			claimed++
		case isUnlocked:
			cupState = "ready"
			ready++
			if claimableID == "" {
				claimableID = def.CupID
			}
		}
		if isUnlocked {
			unlocked++
		}

		cups = append(cups, map[string]interface{}{
			"cup_id":      def.CupID,
			"name":        def.Name,
			"xp_required": def.XPRequired,
			"icon":        def.Icon,
			"sort_order":  def.SortOrder,
			"coins":       def.RewardCoins,
			"gems":        def.RewardGems,
			"state":       cupState,
			"unlocked":    isUnlocked,
		})

		// «کاپ بعدی» = اولین کاپی که هنوز گرفته نشده
		if next == nil && cupState != "claimed" {
			remaining := def.XPRequired - seasonXP
			if remaining < 0 {
				remaining = 0
			}
			next = map[string]interface{}{
				"cup_id":       def.CupID,
				"name":         def.Name,
				"xp_required":  def.XPRequired,
				"icon":         def.Icon,
				"coins":        def.RewardCoins,
				"gems":         def.RewardGems,
				"xp_remaining": remaining,
				"ready":        isUnlocked,
			}
		}
	}

	response := map[string]interface{}{
		"season_id": DefaultSeasonID,
		"season_xp": seasonXP,
		"total":     len(defs),
		"unlocked":  unlocked,
		"claimed":   claimed,
		"ready":     ready,
		"cups":      cups,
		// خالی یعنی الان چیزی برای گرفتن نیست — دکمه‌ی «دریافت» باید خاموش باشد
		"claimable_cup_id": claimableID,
	}
	if next != nil {
		response["next"] = next
	}
	return response
}

// claimSeasonCupHandler جایزه‌ی یک کاپ فصل را واریز می‌کند.
//
// امنیت: کلاینت فقط cup_id می‌فرستد. تجربه‌ی لازم، مقدار جایزه و اینکه این
// کاپ قبلاً گرفته شده یا نه، همه از دیتابیس می‌آید.
func claimSeasonCupHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req SeasonCupClaimBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	if req.Username == "" || req.CupID == "" {
		httpError(w, "درخواست ناقص است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// تعریف کاپ فقط از کاتالوگ دیتابیس — نه از چیزی که کلاینت گفته
	defs := seasonCupDefs(ctx)
	var def *SeasonCupDef
	for i := range defs {
		if defs[i].CupID == req.CupID {
			def = &defs[i]
			break
		}
	}
	if def == nil {
		httpError(w, "این کاپ وجود ندارد", http.StatusNotFound)
		return
	}

	// همان شرطی که /season/cups برای «آماده» بودن استفاده می‌کند
	if seasonXPOf(player) < def.XPRequired {
		httpError(w, "هنوز تجربه‌ی فصلت به این کاپ نرسیده", http.StatusBadRequest)
		return
	}

	now := time.Now()

	// اگر رکورد مال فصل قبل بود، اول وضعیت خالیِ فصل جاری را می‌نشانیم تا
	// $addToSet روی آرایه‌ی درست کار کند.
	if player.SeasonCups.SeasonID != DefaultSeasonID {
		if _, err := col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID},
			bson.M{"$set": bson.M{"season_cups": currentSeasonCups(player)}}); err != nil {
			httpError(w, "خطا در آماده‌سازی کاپ‌های فصل", http.StatusInternalServerError)
			return
		}
	}

	// قفل اتمیک: فقط اگر این کاپ داخل claimed نباشد آپدیت می‌شود
	result, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{
			"player_id":             player.PlayerID,
			"season_cups.season_id": DefaultSeasonID,
			"season_cups.claimed":   bson.M{"$ne": def.CupID},
		},
		bson.M{
			"$addToSet": bson.M{"season_cups.claimed": def.CupID},
			"$inc": bson.M{
				"coins": def.RewardCoins,
				"gems":  def.RewardGems,
			},
			"$set": bson.M{"updated_at": now},
		})
	if err != nil {
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}
	if result.ModifiedCount == 0 {
		httpError(w, "جایزه‌ی این کاپ قبلاً گرفته شده", http.StatusBadRequest)
		return
	}

	fresh, err := getPlayerByID(ctx, player.PlayerID)
	if err != nil {
		fresh = player
	}

	response := buildSeasonCupsResponse(ctx, fresh)
	response["success"] = true
	response["reward"] = map[string]interface{}{
		"cup_id": def.CupID,
		"name":   def.Name,
		"coins":  def.RewardCoins,
		"gems":   def.RewardGems,
	}
	response["coins"] = fresh.Coins
	response["gems"] = fresh.Gems

	jsonResponse(w, response)
}
