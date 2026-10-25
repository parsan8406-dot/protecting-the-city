package main

import (
	"context"
	"math"
	"net/http"
	"strconv"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// رتبه‌بندی (صفحه «رتبه بندی» — منوی کناری: رنک · رتبه بندی · شهر)
// =============================================================================
//
// سه حالت جدول:
//   global   همه‌ی بازیکن‌ها بر اساس کاپ
//   friends  من و دوستانم بر اساس کاپ
//   cities   شهرها بر اساس مجموع کاپ اعضایشان
//
// امتیاز جدول همان کاپ (trophies) است — همان عددی که رنک از رویش حساب می‌شود
// (matchmaking.go → trophyTiers)، تا صفحه‌ی رنک و جدول یک عدد را نشان بدهند.
//
// همه‌ی اعداد این صفحه سمت سرور حساب می‌شوند. کلاینت هیچ عددی نمی‌فرستد و
// هیچ چیزی را خودش محاسبه نمی‌کند — فقط `username` بیننده، `scope` و `page`.
// دلیلش امنیت است: رتبه، امتیاز و پاداش‌ها همه از دیتابیس خوانده می‌شوند،
// پس دستکاری کلاینت روی آن‌ها اثری ندارد.
//
// چیزهایی که عمداً برنمی‌گردند (نشتی اطلاعات): سکه، جم، ایمیل/اکانت، لیست
// دوستان بقیه، آیتم‌های خریداری‌شده. فقط فیلدهای عمومیِ لازم برای جدول.
//
// پاداش هفتگی سه نفر اول جدول کلی در weekly_rewards.go است.

// LeaderboardMaxLimit سقف ردیف‌های هر صفحه — جلوی کشیدنِ کل کالکشن را می‌گیرد
const LeaderboardMaxLimit = 50

// LeaderboardDefaultLimit تعداد پیش‌فرض ردیف‌های هر صفحه‌ی جدول
const LeaderboardDefaultLimit = 10

// LeaderboardFriendsCap سقف دوستانی که در حالت «دوستان» بررسی می‌شوند
const LeaderboardFriendsCap = 200

// SeasonRewardTier یک ردیف از «پاداش پایان فصل» (صفحه‌ی پاداش فصل)
type SeasonRewardTier struct {
	FromPosition int    `json:"from_position"`
	ToPosition   int    `json:"to_position"` // صفر یعنی «تا آخر جدول»
	Title        string `json:"title"`
	Reward       string `json:"reward"`
	Coins        int    `json:"coins"`
	Cups         int    `json:"cups"`
	CupRarity    string `json:"cup_rarity"`
}

// SeasonRewards پاداش پایان فصل بر اساس رتبه‌ی نهایی (end_rewards در /season/pass).
// سمت سرور تعریف شده تا کلاینت نتواند برای خودش پاداش تعریف کند.
var SeasonRewards = []SeasonRewardTier{
	{FromPosition: 1, ToPosition: 10, Title: "رتبه ۱ تا ۱۰",
		Reward: "۳ کاپ افسانه‌ای + ۵٬۰۰۰ سکه", Coins: 5000, Cups: 3, CupRarity: "legendary"},
	{FromPosition: 11, ToPosition: 100, Title: "رتبه ۱۱ تا ۱۰۰",
		Reward: "۲ کاپ حماسی + ۲٬۵۰۰ سکه", Coins: 2500, Cups: 2, CupRarity: "epic"},
	{FromPosition: 101, ToPosition: 1000, Title: "رتبه ۱۰۱ تا ۱۰۰۰",
		Reward: "۱ کاپ نادر + ۱٬۰۰۰ سکه", Coins: 1000, Cups: 1, CupRarity: "rare"},
	{FromPosition: 1001, ToPosition: 0, Title: "سایر بازیکنان",
		Reward: "۲۵۰ سکه", Coins: 250, Cups: 0, CupRarity: ""},
}

// seasonCupCount تعداد کاپ‌های باز شده‌ی یک بازیکن را از روی تجربه‌ی فصلش می‌دهد.
// آستانه‌ها از کاتالوگ season_cups در دیتابیس می‌آیند (season_cups.go).
func seasonCupCount(seasonXP int) int {
	count := 0
	for _, threshold := range seasonCupThresholds() {
		if seasonXP >= threshold {
			count++
		}
	}
	return count
}

// seasonXPOf تجربه‌ی فصلِ بازیکن.
// TODO: وقتی تجربه‌ی فصلی جدا از تجربه‌ی کل ذخیره شد، همین‌جا عوض شود.
func seasonXPOf(p *PlayerModel) int {
	return p.Experience
}

// leaderboardSort ترتیب ثابت جدول بازیکن‌ها: کاپ بیشتر بالاتر، و در تساوی
// player_id کوچکتر بالاتر (تا رتبه‌ها بین دو درخواست جابه‌جا نشوند)
var leaderboardSort = bson.D{
	{Key: "trophies", Value: -1},
	{Key: "player_id", Value: 1},
}

// leaderboardProjection فقط فیلدهای عمومیِ لازم برای جدول
var leaderboardProjection = bson.M{
	"player_id": 1, "username": 1, "avatar_id": 1, "level": 1,
	"clan_id": 1, "trophies": 1, "rank": 1, "is_online": 1,
}

// getLeaderboardHandler جدول رتبه‌بندی
//
//	GET /leaderboard?username=<me>&scope=global|friends|cities&page=0&limit=10
//
// پاسخ:
//
//	{ scope, page, page_size, total, entries, me, my_rank,
//	  season, week, weekly_rewards, no_city? }
//
// entries برای global/friends ردیف بازیکن است و برای cities ردیف شهر.
// me جایگاه بیننده در همین حالت است (در cities یعنی شهر خودش).
// my_rank کارت «رتبه فعلی شما»: رنک و کاپ بیننده، مستقل از حالت جدول.
func getLeaderboardHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	query := r.URL.Query()
	limit := LeaderboardDefaultLimit
	if n, err := strconv.Atoi(query.Get("limit")); err == nil && n > 0 {
		limit = min(n, LeaderboardMaxLimit)
	}
	page := 0
	if n, err := strconv.Atoi(query.Get("page")); err == nil && n > 0 {
		page = n
	}

	// بیننده اختیاری است — بدون آن فقط جدول جهانی برمی‌گردد و بخش «جایگاه شما» خالی است
	var me *PlayerModel
	if username := query.Get("username"); username != "" {
		if p, err := getPlayerByUsername(ctx, username); err == nil {
			me = p
		}
	}

	scope := query.Get("scope")
	switch scope {
	case "friends":
		if me == nil {
			// بدون بیننده «دوستان» معنی ندارد
			scope = "global"
		}
	case "cities":
	default:
		scope = "global"
	}

	response := map[string]interface{}{
		"scope":          scope,
		"page":           page,
		"page_size":      limit,
		"total":          0,
		"entries":        []interface{}{},
		"me":             nil,
		"my_rank":        nil,
		"season":         seasonSummary(ctx),
		"week":           weekSummary(time.Now()),
		"weekly_rewards": WeeklyRewards,
	}
	if me != nil {
		response["my_rank"] = myRankCard(me)
	}

	var ok bool
	if scope == "cities" {
		ok = fillCityLeaderboard(ctx, response, me, page, limit)
	} else {
		ok = fillPlayerLeaderboard(ctx, response, scope, me, page, limit)
	}
	if !ok {
		httpError(w, "خطا در خواندن رتبه‌بندی", http.StatusInternalServerError)
		return
	}

	jsonResponse(w, response)
}

// ============== جدول بازیکن‌ها (global / friends) ==============

// playerLeaderboardFilter فیلتر مونگو برای جدول بازیکن‌ها
func playerLeaderboardFilter(scope string, me *PlayerModel) bson.M {
	filter := bson.M{"is_banned": bson.M{"$ne": true}}
	if scope == "friends" && me != nil {
		ids := []string{me.PlayerID}
		for i, friendID := range me.Friends {
			if i >= LeaderboardFriendsCap {
				break
			}
			ids = append(ids, friendID)
		}
		filter["player_id"] = bson.M{"$in": ids}
	}
	return filter
}

func fillPlayerLeaderboard(
	ctx context.Context, response map[string]interface{}, scope string, me *PlayerModel, page, limit int,
) bool {
	filter := playerLeaderboardFilter(scope, me)

	total, err := col(ColPlayers).CountDocuments(ctx, filter)
	if err != nil {
		return false
	}

	skip := int64(page * limit)
	cursor, err := col(ColPlayers).Find(ctx, filter,
		options.Find().
			SetSort(leaderboardSort).
			SetSkip(skip).
			SetLimit(int64(limit)).
			SetProjection(leaderboardProjection))
	if err != nil {
		return false
	}
	players := []PlayerModel{}
	if err := cursor.All(ctx, &players); err != nil {
		return false
	}

	clanIDs := []string{}
	for _, p := range players {
		if p.ClanID != "" {
			clanIDs = append(clanIDs, p.ClanID)
		}
	}
	clans := clansByID(ctx, clanIDs)

	myID := ""
	if me != nil {
		myID = me.PlayerID
	}

	entries := make([]map[string]interface{}, 0, len(players))
	for i := range players {
		entries = append(entries, playerLeaderboardEntry(&players[i], int(skip)+i+1, myID, clans))
	}

	response["total"] = total
	response["entries"] = entries
	if me != nil {
		standing := playerLeaderboardEntry(me, playerPosition(ctx, me, filter), myID, clansByID(ctx, []string{me.ClanID}))
		pos := standing["position"].(int)
		standing["in_page"] = pos > int(skip) && pos <= int(skip)+len(players)
		response["me"] = standing
	}
	return true
}

// playerLeaderboardEntry یک ردیف جدول بازیکن‌ها — فقط فیلدهای عمومی.
// رنک از روی کاپ فعلی حساب می‌شود، نه rank.tier_id ذخیره‌شده، تا با صفحه‌ی رنک یکی باشد.
func playerLeaderboardEntry(p *PlayerModel, position int, myID string, clans map[string]*ClanModel) map[string]interface{} {
	tierID, tierName := rankFromTrophies(p.Trophies)
	entry := map[string]interface{}{
		"position":  position,
		"player_id": p.PlayerID,
		"username":  p.Username,
		"avatar_id": p.AvatarID,
		"level":     p.Level,
		"tier_id":   tierID,
		"tier_name": tierName,
		"points":    p.Trophies,
		"is_online": p.IsOnline,
		"is_me":     p.PlayerID == myID,
		"clan_id":   p.ClanID,
		"clan_name": "",
		"clan_icon": "",
	}
	if c, ok := clans[p.ClanID]; ok {
		entry["clan_name"] = c.Name
		entry["clan_icon"] = c.IconPath
	}
	return entry
}

// playerPosition رتبه‌ی بازیکن را با همان ترتیبِ جدول حساب می‌کند:
// تعداد کسانی که کاپ بیشتری دارند، به‌علاوه‌ی هم‌کاپ‌هایی که
// player_id کوچکتری دارند، به‌علاوه‌ی یک.
func playerPosition(ctx context.Context, me *PlayerModel, filter bson.M) int {
	ahead := bson.M{}
	for key, value := range filter {
		ahead[key] = value
	}
	ahead["$or"] = []bson.M{
		{"trophies": bson.M{"$gt": me.Trophies}},
		{"trophies": me.Trophies, "player_id": bson.M{"$lt": me.PlayerID}},
	}

	count, err := col(ColPlayers).CountDocuments(ctx, ahead)
	if err != nil {
		return 0
	}
	return int(count) + 1
}

// myRankCard کارت «رتبه فعلی شما»: رنک، کاپ و فاصله تا رنک بعدی
func myRankCard(p *PlayerModel) map[string]interface{} {
	tierID, tierName := rankFromTrophies(p.Trophies)
	index := tierIndexOf(tierID)
	card := map[string]interface{}{
		"tier_id":   tierID,
		"tier_name": tierName,
		"trophies":  p.Trophies,
		"tier_min":  trophyTiers[index].Min,
	}
	if index+1 < len(trophyTiers) {
		next := trophyTiers[index+1]
		card["next_tier_id"] = next.ID
		card["next_tier_name"] = next.Name
		card["next_min"] = next.Min
		card["to_next"] = max(next.Min-p.Trophies, 0)
	}
	return card
}

// clansByID اطلاعات نمایشی چند شهر با یک کوئری
func clansByID(ctx context.Context, clanIDs []string) map[string]*ClanModel {
	out := map[string]*ClanModel{}
	ids := []string{}
	for _, id := range clanIDs {
		if id != "" {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 {
		return out
	}
	cursor, err := col(ColClans).Find(ctx, bson.M{"clan_id": bson.M{"$in": ids}},
		options.Find().SetProjection(bson.M{
			"clan_id": 1, "name": 1, "tag": 1, "icon_path": 1, "members": 1, "max_members": 1,
		}))
	if err != nil {
		return out
	}
	defer cursor.Close(ctx)
	for cursor.Next(ctx) {
		var c ClanModel
		if cursor.Decode(&c) == nil {
			out[c.ClanID] = &c
		}
	}
	return out
}

// ============== جدول شهرها (cities) ==============

// امتیاز شهر = مجموع کاپ اعضایش. همین ترتیب «رتبه جهانی» صفحه‌ی شهر هم هست
// (clanWorldRank)، تا دو صفحه یک عدد نشان بدهند.

// cityPointsRow خروجی گروه‌بندی بازیکن‌ها بر اساس شهر
type cityPointsRow struct {
	ClanID  string `bson:"_id"`
	Points  int64  `bson:"points"`
	Members int    `bson:"members"`
}

// cityPointsStages بازیکن‌های عضو شهر را بر اساس clan_id گروه می‌کند
func cityPointsStages() []interface{} {
	return []interface{}{
		bson.M{"$match": bson.M{
			"clan_id":   bson.M{"$nin": bson.A{"", nil}},
			"is_banned": bson.M{"$ne": true},
		}},
		bson.M{"$group": bson.M{
			"_id":     "$clan_id",
			"points":  bson.M{"$sum": "$trophies"},
			"members": bson.M{"$sum": 1},
		}},
	}
}

func fillCityLeaderboard(
	ctx context.Context, response map[string]interface{}, me *PlayerModel, page, limit int,
) bool {
	skip := int64(page * limit)
	pipeline := append(cityPointsStages(),
		bson.M{"$sort": bson.D{{Key: "points", Value: -1}, {Key: "_id", Value: 1}}},
		bson.M{"$facet": bson.M{
			"total": bson.A{bson.M{"$count": "n"}},
			"rows":  bson.A{bson.M{"$skip": skip}, bson.M{"$limit": int64(limit)}},
		}},
	)

	cursor, err := col(ColPlayers).Aggregate(ctx, pipeline)
	if err != nil {
		return false
	}
	var out []struct {
		Total []struct {
			N int64 `bson:"n"`
		} `bson:"total"`
		Rows []cityPointsRow `bson:"rows"`
	}
	if err := cursor.All(ctx, &out); err != nil {
		return false
	}

	var total int64
	rows := []cityPointsRow{}
	if len(out) > 0 {
		if len(out[0].Total) > 0 {
			total = out[0].Total[0].N
		}
		rows = out[0].Rows
	}

	ids := make([]string, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.ClanID)
	}
	clans := clansByID(ctx, ids)

	myClan := ""
	if me != nil {
		myClan = me.ClanID
	}

	entries := make([]map[string]interface{}, 0, len(rows))
	for i, row := range rows {
		c, ok := clans[row.ClanID]
		if !ok {
			// شهر منحل شده ولی clan_id عضو هنوز پاک نشده — نشانش نمی‌دهیم
			continue
		}
		entries = append(entries, cityLeaderboardEntry(c, int(skip)+i+1, row.Points, myClan))
	}

	response["total"] = total
	response["entries"] = entries

	if myClan == "" {
		response["no_city"] = true
		return true
	}
	if c, err := getClanByID(ctx, myClan); err == nil {
		pos, points := cityStanding(ctx, myClan)
		standing := cityLeaderboardEntry(c, pos, points, myClan)
		standing["in_page"] = pos > int(skip) && pos <= int(skip)+len(rows)
		response["me"] = standing
	}
	return true
}

// cityLeaderboardEntry یک ردیف جدول شهرها
func cityLeaderboardEntry(c *ClanModel, position int, points int64, myClan string) map[string]interface{} {
	leader, _ := clanLeaderInfo(c)
	return map[string]interface{}{
		"position":     position,
		"clan_id":      c.ClanID,
		"name":         c.Name,
		"tag":          c.Tag,
		"icon_path":    c.IconPath,
		"member_count": c.MemberCount(),
		"max_members":  c.MaxMembers,
		"leader_name":  leader,
		"points":       points,
		"is_mine":      c.ClanID == myClan,
	}
}

// cityStanding جایگاه و امتیاز یک شهر در جدول شهرها
func cityStanding(ctx context.Context, clanID string) (int, int64) {
	var points int64
	cursor, err := col(ColPlayers).Aggregate(ctx, []interface{}{
		bson.M{"$match": bson.M{"clan_id": clanID, "is_banned": bson.M{"$ne": true}}},
		bson.M{"$group": bson.M{"_id": "$clan_id", "points": bson.M{"$sum": "$trophies"}}},
	})
	if err != nil {
		return 0, 0
	}
	var mine []cityPointsRow
	if cursor.All(ctx, &mine) == nil && len(mine) > 0 {
		points = mine[0].Points
	}

	pipeline := append(cityPointsStages(),
		bson.M{"$match": bson.M{"$or": bson.A{
			bson.M{"points": bson.M{"$gt": points}},
			bson.M{"points": points, "_id": bson.M{"$lt": clanID}},
		}}},
		bson.M{"$count": "n"},
	)
	cursor, err = col(ColPlayers).Aggregate(ctx, pipeline)
	if err != nil {
		return 0, points
	}
	var ahead []struct {
		N int64 `bson:"n"`
	}
	if cursor.All(ctx, &ahead) != nil {
		return 0, points
	}
	if len(ahead) == 0 {
		return 1, points
	}
	return int(ahead[0].N) + 1, points
}

// ============== فصل ==============

// seasonSummary خلاصه‌ی فصل جاری: اسم، شماره و روزهای باقی‌مانده
func seasonSummary(ctx context.Context) map[string]interface{} {
	summary := map[string]interface{}{
		"season_id": DefaultSeasonID,
		"name":      "",
		"number":    0,
		"days_left": 0,
	}

	var season SeasonModel
	err := col(ColSeasons).FindOne(ctx, bson.M{"is_active": true}).Decode(&season)
	if err != nil {
		if col(ColSeasons).FindOne(ctx, bson.M{"season_id": DefaultSeasonID}).Decode(&season) != nil {
			return summary
		}
	}

	summary["season_id"] = season.SeasonID
	summary["name"] = season.Name
	summary["number"] = seasonNumber(season.SeasonID)

	if !season.EndsAt.IsZero() {
		summary["ends_at"] = season.EndsAt.UTC().Format(time.RFC3339)
		remaining := time.Until(season.EndsAt)
		if remaining > 0 {
			summary["days_left"] = int(math.Ceil(remaining.Hours() / 24.0))
		}
	}

	return summary
}

// seasonNumber شماره‌ی فصل را از شناسه‌اش درمی‌آورد ("season_3" → ۳)
func seasonNumber(seasonID string) int {
	for i := len(seasonID) - 1; i >= 0; i-- {
		if seasonID[i] == '_' {
			if n, err := strconv.Atoi(seasonID[i+1:]); err == nil {
				return n
			}
			return 0
		}
	}
	return 0
}
