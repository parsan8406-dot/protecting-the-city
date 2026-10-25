package main

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// لایه دیتابیس: نام کالکشن‌ها، ساخت ایندکس‌ها، مقداردهی اولیه و مایگریشن
// این فایل موقع بالا آمدن سرور اجرا می‌شود و ساختار دیتابیس را تضمین می‌کند.
// =============================================================================

// نام کالکشن‌ها — همیشه از این ثابت‌ها استفاده کنید، نه رشته خام
const (
	ColPlayers        = "players"          // اطلاعات دائمی بازیکن
	ColShopItems      = "shop_items"       // کاتالوگ فروشگاه
	ColMessages       = "messages"         // صندوق پیام
	ColSupportMsgs    = "support_messages" // پیام‌های کاربران به سازنده
	ColFriendRequests = "friend_requests"  // درخواست‌های دوستی
	ColClans          = "clans"            // شهرها
	ColClanRequests   = "clan_requests"    // درخواست‌های عضویت در شهر
	ColAchievements   = "achievements"     // کاتالوگ دستاوردها
	ColSeasons        = "seasons"          // فصل‌های رقابتی
	ColSeasonCups     = "season_cups"      // کاتالوگ کاپ‌های هر فصل
	ColMatches        = "matches"          // تاریخچه مسابقات
	ColChatMessages   = "chat_messages"    // پیام‌های چت (خصوصی/شهر/جهانی)
	ColChatReads      = "chat_reads"       // آخرین بازدید هر بازیکن از هر اتاق چت
	ColDailyMissions  = "daily_missions"   // ماموریت‌های روزانه‌ی هر بازیکن
	ColWeeklyRewards  = "weekly_rewards"   // پرداخت پاداش هفتگی سه نفر اول رتبه‌بندی
)

// DefaultSeasonID شناسه فصل پیش‌فرض
const DefaultSeasonID = "season_1"

// col دسترسی کوتاه به کالکشن
func col(name string) *mongo.Collection {
	return db.Collection(name)
}

// newID یک شناسه یکتای رشته‌ای می‌سازد (برای message_id، request_id و ...)
func newID(prefix string) string {
	return prefix + "_" + primitive.NewObjectID().Hex()
}

// randomDigits یک عدد تصادفی امن با تعداد رقم مشخص برمی‌گرداند
func randomDigits(digits int) (int64, error) {
	min := int64(1)
	for i := 1; i < digits; i++ {
		min *= 10
	}
	max := min * 9 // بازه: [min, min*10)
	n, err := rand.Int(rand.Reader, big.NewInt(max))
	if err != nil {
		return 0, err
	}
	return min + n.Int64(), nil
}

// GenerateUniquePlayerID یک آیدی عددی عمومی و یکتا برای بازیکن می‌سازد
// این همان آیدی‌ای است که در صفحه «دوستان» نمایش داده و برای افزودن دوست استفاده می‌شود
func GenerateUniquePlayerID(ctx context.Context) (string, error) {
	for attempt := 0; attempt < 20; attempt++ {
		digits := 5
		if attempt > 10 {
			digits = 8 // اگر فضای ۵ رقمی شلوغ بود، بلندتر برو
		}
		n, err := randomDigits(digits)
		if err != nil {
			return "", err
		}
		candidate := fmt.Sprintf("%d", n)

		count, err := col(ColPlayers).CountDocuments(ctx, bson.M{"player_id": candidate})
		if err != nil {
			return "", err
		}
		if count == 0 {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("امکان ساخت player_id یکتا نبود")
}

// ============== ساخت کالکشن‌ها ==============

// EnsureCollections کالکشن‌های خالی را می‌سازد تا در Compass قابل مشاهده باشند
func EnsureCollections(ctx context.Context) {
	names := []string{
		ColPlayers, ColShopItems, ColMessages, ColSupportMsgs, ColFriendRequests,
		ColClans, ColClanRequests, ColAchievements, ColSeasons, ColMatches,
		ColChatMessages, ColChatReads, ColDailyMissions, ColSeasonCups, ColWeeklyRewards,
		ColGoogleAuth, ColGiftCodes, ColGiftRedemptions, ColIAPPurchases, ColAdRewards,
	}
	for _, name := range names {
		err := db.CreateCollection(ctx, name)
		if err != nil {
			// خطای 48 یعنی کالکشن از قبل وجود دارد — طبیعی است
			if cmdErr, ok := err.(mongo.CommandError); ok && cmdErr.Code == 48 {
				continue
			}
		}
	}
}

// ============== ایندکس‌ها ==============

// EnsureIndexes تمام ایندکس‌های لازم را می‌سازد (idempotent — تکرارش مشکلی ندارد)
func EnsureIndexes(ctx context.Context) error {
	type colIndexes struct {
		collection string
		models     []mongo.IndexModel
	}

	all := []colIndexes{
		{
			collection: ColSeasonCups,
			models: []mongo.IndexModel{
				{
					// هر کاپ در هر فصل فقط یک تعریف دارد
					Keys:    bson.D{{Key: "season_id", Value: 1}, {Key: "cup_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_season_cup"),
				},
			},
		},
		{
			collection: ColPlayers,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "username", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_username"),
				},
				{
					// یکتا فقط روی داکیومنت‌هایی که player_id رشته‌ای دارند
					Keys: bson.D{{Key: "player_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_player_id").
						SetPartialFilterExpression(bson.M{"player_id": bson.M{"$type": "string"}}),
				},
				{
					Keys: bson.D{{Key: "auth.email", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_email").
						SetPartialFilterExpression(bson.M{"auth.email": bson.M{"$type": "string"}}),
				},
				{
					Keys: bson.D{{Key: "auth.google_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_google_id").
						SetPartialFilterExpression(bson.M{"auth.google_id": bson.M{"$type": "string"}}),
				},
				{
					Keys:    bson.D{{Key: "clan_id", Value: 1}},
					Options: options.Index().SetName("idx_clan"),
				},
				// ایندکس‌های رتبه‌بندی (صفحه «رتبه بندی»)
				{
					Keys:    bson.D{{Key: "rank.points", Value: -1}},
					Options: options.Index().SetName("idx_rank_points"),
				},
				{
					// ترتیب جدول رتبه‌بندی: کاپ بیشتر، بعد player_id کوچکتر
					Keys:    bson.D{{Key: "trophies", Value: -1}, {Key: "player_id", Value: 1}},
					Options: options.Index().SetName("idx_trophies"),
				},
				{
					Keys:    bson.D{{Key: "stats.kills", Value: -1}},
					Options: options.Index().SetName("idx_kills"),
				},
				{
					Keys:    bson.D{{Key: "stats.wins", Value: -1}},
					Options: options.Index().SetName("idx_wins"),
				},
				{
					Keys:    bson.D{{Key: "level", Value: -1}, {Key: "experience", Value: -1}},
					Options: options.Index().SetName("idx_level"),
				},
			},
		},
		{
			collection: ColShopItems,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "item_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_item_id"),
				},
				{
					Keys:    bson.D{{Key: "category", Value: 1}, {Key: "section", Value: 1}},
					Options: options.Index().SetName("idx_category_section"),
				},
			},
		},
		{
			collection: ColMessages,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "message_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_message_id"),
				},
				{
					// پرکاربردترین کوئری: پیام‌های یک بازیکن، جدیدترین اول
					Keys:    bson.D{{Key: "recipient_id", Value: 1}, {Key: "created_at", Value: -1}},
					Options: options.Index().SetName("idx_inbox"),
				},
				{
					Keys:    bson.D{{Key: "recipient_id", Value: 1}, {Key: "is_read", Value: 1}},
					Options: options.Index().SetName("idx_unread"),
				},
				{
					// حذف خودکار پیام‌های منقضی‌شده توسط خود MongoDB
					Keys:    bson.D{{Key: "expires_at", Value: 1}},
					Options: options.Index().SetName("ttl_expires_at").SetExpireAfterSeconds(0),
				},
			},
		},
		{
			collection: ColSupportMsgs,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "ticket_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_ticket_id"),
				},
				{
					// نمای سازنده: جدیدترین پیام‌ها اول
					Keys:    bson.D{{Key: "created_at", Value: -1}},
					Options: options.Index().SetName("idx_support_recent"),
				},
				{
					Keys:    bson.D{{Key: "username", Value: 1}, {Key: "created_at", Value: -1}},
					Options: options.Index().SetName("idx_support_by_user"),
				},
				{
					Keys:    bson.D{{Key: "status", Value: 1}, {Key: "created_at", Value: -1}},
					Options: options.Index().SetName("idx_support_status"),
				},
			},
		},
		{
			collection: ColFriendRequests,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "request_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_request_id"),
				},
				{
					// جلوگیری از ارسال چند درخواست هم‌زمانِ در انتظار بین دو نفر
					Keys: bson.D{{Key: "from_id", Value: 1}, {Key: "to_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_pending_pair").
						SetPartialFilterExpression(bson.M{"status": FriendReqPending}),
				},
				{
					Keys:    bson.D{{Key: "to_id", Value: 1}, {Key: "status", Value: 1}},
					Options: options.Index().SetName("idx_incoming"),
				},
			},
		},
		{
			collection: ColClans,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "clan_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_clan_id"),
				},
				{
					Keys:    bson.D{{Key: "name", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_clan_name"),
				},
				{
					Keys:    bson.D{{Key: "members.player_id", Value: 1}},
					Options: options.Index().SetName("idx_clan_members"),
				},
				{
					Keys:    bson.D{{Key: "level", Value: -1}},
					Options: options.Index().SetName("idx_clan_level"),
				},
			},
		},
		{
			collection: ColClanRequests,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "request_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_clan_request_id"),
				},
				{
					// یک بازیکن نمی‌تواند به یک شهر دو درخواست باز بدهد
					Keys: bson.D{{Key: "clan_id", Value: 1}, {Key: "from_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_clan_request_pending").
						SetPartialFilterExpression(bson.M{"status": ClanReqPending}),
				},
				{
					// صف درخواست‌های هر شهر برای رهبر
					Keys:    bson.D{{Key: "clan_id", Value: 1}, {Key: "status", Value: 1}},
					Options: options.Index().SetName("idx_clan_request_queue"),
				},
			},
		},
		{
			collection: ColAchievements,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "achievement_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_achievement_id"),
				},
			},
		},
		{
			collection: ColSeasons,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "season_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_season_id"),
				},
				{
					Keys:    bson.D{{Key: "is_active", Value: 1}},
					Options: options.Index().SetName("idx_active_season"),
				},
			},
		},
		{
			collection: ColMatches,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "match_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_match_id"),
				},
				{
					Keys:    bson.D{{Key: "participants.player_id", Value: 1}, {Key: "ended_at", Value: -1}},
					Options: options.Index().SetName("idx_player_history"),
				},
			},
		},
		{
			collection: ColChatMessages,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "message_id", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_chat_message_id"),
				},
				{
					// کوئری اصلی: آخرین پیام‌های یک اتاق
					Keys:    bson.D{{Key: "room", Value: 1}, {Key: "created_at", Value: -1}},
					Options: options.Index().SetName("idx_room_recent"),
				},
				{
					// شمردن پیام‌های خوانده‌نشده (بعد از last_read_at و از طرف مقابل)
					Keys:    bson.D{{Key: "room", Value: 1}, {Key: "sender_id", Value: 1}, {Key: "created_at", Value: -1}},
					Options: options.Index().SetName("idx_room_sender"),
				},
				{
					// فقط پیام‌های جهانی و شهر expires_at دارند؛ خصوصی‌ها می‌مانند
					Keys:    bson.D{{Key: "expires_at", Value: 1}},
					Options: options.Index().SetName("ttl_chat_expires_at").SetExpireAfterSeconds(0),
				},
			},
		},
		{
			collection: ColChatReads,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "player_id", Value: 1}, {Key: "room", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_player_room"),
				},
			},
		},
		{
			collection: ColDailyMissions,
			models:     dailyMissionIndexes(),
		},
		{
			// جریان‌های نیمه‌تمامِ ورود با گوگل (handlers_auth.go)
			collection: ColGoogleAuth,
			models: []mongo.IndexModel{
				{
					Keys:    bson.D{{Key: "state", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_google_state"),
				},
				{
					Keys:    bson.D{{Key: "poll_hash", Value: 1}},
					Options: options.Index().SetUnique(true).SetName("uniq_google_poll"),
				},
				{
					// جریانِ رهاشده خودش بعد از ده دقیقه پاک می‌شود
					Keys:    bson.D{{Key: "expires_at", Value: 1}},
					Options: options.Index().SetName("ttl_google_pending").SetExpireAfterSeconds(0),
				},
			},
		},
	}

	for _, item := range all {
		if _, err := col(item.collection).Indexes().CreateMany(ctx, item.models); err != nil {
			return fmt.Errorf("ایندکس کالکشن %s: %w", item.collection, err)
		}
	}
	return nil
}

// ============== مقداردهی اولیه دیتای استاتیک ==============

// SeedStaticData فصل پیش‌فرض و کاتالوگ دستاوردها را در صورت نبود می‌سازد
func SeedStaticData(ctx context.Context) error {
	if err := seedSeason(ctx); err != nil {
		return err
	}
	// کاپ‌های فصل — کاتالوگی که صفحه‌ی رنک از آن می‌خواند
	if err := seedSeasonCups(ctx); err != nil {
		return err
	}
	if err := seedGameModes(ctx); err != nil {
		return err
	}
	// جمعیتِ ثابتِ بات‌ها. بعد از seedGameModes می‌آید چون به rankFromTrophies
	// و کاتالوگِ آیتم‌ها تکیه دارد.
	if err := seedBots(ctx); err != nil {
		return err
	}
	if err := seedAchievements(ctx); err != nil {
		return err
	}
	// تراز کاراکترها و قیمت‌ها هر بار از روی کد نوشته می‌شوند تا کاتالوگ
	// هیچ‌وقت از منبعِ حقیقت (balance.go) عقب نماند.
	if err := SeedCharacterStats(ctx); err != nil {
		return err
	}
	if err := SeedWeaponStats(ctx); err != nil {
		return err
	}
	if err := SeedCatalogPrices(ctx); err != nil {
		return err
	}
	// اسکین‌ها فروشی نیستند — اگر در کاتالوگ افتاده‌اند پاک شوند
	if err := PurgeSkinsFromShop(ctx); err != nil {
		return err
	}
	return SeedCurrencyPacks(ctx)
}

func seedSeason(ctx context.Context) error {
	count, err := col(ColSeasons).CountDocuments(ctx, bson.M{"season_id": DefaultSeasonID})
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	now := time.Now()
	season := SeasonModel{
		SeasonID: DefaultSeasonID,
		Name:     "فصل اول",
		StartsAt: now,
		EndsAt:   now.AddDate(0, 3, 0), // سه ماه
		IsActive: true,
		Tiers: []RankTier{
			{TierID: "bronze", Name: "برنز", Divisions: 5, PointsPerDivision: 1000, SortOrder: 1},
			{TierID: "silver", Name: "نقره", Divisions: 5, PointsPerDivision: 2000, SortOrder: 2},
			{TierID: "gold", Name: "طلا", Divisions: 5, PointsPerDivision: 4000, SortOrder: 3},
			{TierID: "platinum", Name: "پلاتین", Divisions: 5, PointsPerDivision: 8000, SortOrder: 4},
			{TierID: "diamond", Name: "الماس", Divisions: 5, PointsPerDivision: 16000, SortOrder: 5},
			{TierID: "legend", Name: "لجند", Divisions: 5, PointsPerDivision: 32000, SortOrder: 6},
		},
	}

	_, err = col(ColSeasons).InsertOne(ctx, season)
	return err
}

// ============== مایگریشن داکیومنت‌های قدیمی ==============

// MigratePlayers فیلدهای جدید را به بازیکنان قدیمی (که فقط سکه/جم/سطح داشتند) اضافه می‌کند
func MigratePlayers(ctx context.Context) error {
	players := col(ColPlayers)
	now := time.Now()

	if err := repairPlayerUsernames(ctx); err != nil {
		return err
	}

	// ۱. فیلدهای ساده‌ای که اگر نبودند مقدار پیش‌فرض بگیرند
	defaults := []struct {
		field string
		value interface{}
	}{
		{"avatar_id", "avatar_default"},
		{"frame_id", "frame_default"},
		{"stats", PlayerStats{}},
		{"rank", NewDefaultRank()},
		{"achievements", []UnlockedAchievement{}},
		{"clan_id", ""},
		{"clan_role", ""},
		{"friends", []string{}},
		{"blocked", []string{}},
		{"auth", PlayerAuth{Provider: "guest", IsGuest: true}},
		{"is_banned", false},
		{"is_online", false},
		{"last_seen_at", now},
		{"created_at", now},
		{"updated_at", now},
	}

	for _, d := range defaults {
		filter := bson.M{d.field: bson.M{"$exists": false}}
		update := bson.M{"$set": bson.M{d.field: d.value}}
		if _, err := players.UpdateMany(ctx, filter, update); err != nil {
			return fmt.Errorf("مایگریشن فیلد %s: %w", d.field, err)
		}
	}

	// ۲. اختصاص player_id یکتا به بازیکنانی که ندارند
	filter := bson.M{"$or": []bson.M{
		{"player_id": bson.M{"$exists": false}},
		{"player_id": ""},
	}}

	cursor, err := players.Find(ctx, filter, options.Find().SetProjection(bson.M{"_id": 1}))
	if err != nil {
		return err
	}
	defer cursor.Close(ctx)

	var ids []primitive.ObjectID
	for cursor.Next(ctx) {
		var doc struct {
			ID primitive.ObjectID `bson:"_id"`
		}
		if err := cursor.Decode(&doc); err == nil {
			ids = append(ids, doc.ID)
		}
	}

	for _, oid := range ids {
		playerID, err := GenerateUniquePlayerID(ctx)
		if err != nil {
			return err
		}
		if _, err := players.UpdateByID(ctx, oid, bson.M{"$set": bson.M{"player_id": playerID}}); err != nil {
			return err
		}
	}

	if len(ids) > 0 {
		fmt.Printf("🔧 %d بازیکن قدیمی player_id گرفتند\n", len(ids))
	}
	return nil
}

func repairPlayerUsernames(ctx context.Context) error {
	players := col(ColPlayers)
	cursor, err := players.Find(ctx, bson.M{}, options.Find().
		SetProjection(bson.M{"_id": 1, "username": 1}).
		SetSort(bson.D{{Key: "username", Value: 1}, {Key: "_id", Value: 1}}))
	if err != nil {
		return fmt.Errorf("خواندن نام‌های بازیکنان: %w", err)
	}
	defer cursor.Close(ctx)

	used := make(map[string]struct{})
	duplicateNumber := make(map[string]int)
	for cursor.Next(ctx) {
		var player struct {
			ID       primitive.ObjectID `bson:"_id"`
			Username string             `bson:"username"`
		}
		if err := cursor.Decode(&player); err != nil {
			return fmt.Errorf("خواندن نام بازیکن: %w", err)
		}

		username := player.Username
		if username == "" {
			username = "Player" + player.ID.Hex()[:14]
		}
		if _, exists := used[username]; exists {
			duplicateNumber[player.Username]++
			number := duplicateNumber[player.Username]
			base := player.Username
			if base == "" {
				base = "Player"
			}
			for {
				suffix := fmt.Sprintf("_%d", number)
				maxBaseLength := 20 - len(suffix)
				if len(base) > maxBaseLength {
					base = base[:maxBaseLength]
				}
				username = base + suffix
				if _, collision := used[username]; !collision {
					break
				}
				number++
			}
			duplicateNumber[player.Username] = number
		}

		used[username] = struct{}{}
		if username != player.Username {
			if _, err := players.UpdateByID(ctx, player.ID, bson.M{"$set": bson.M{"username": username}}); err != nil {
				return fmt.Errorf("اصلاح نام بازیکن %s: %w", player.ID.Hex(), err)
			}
		}
	}
	if err := cursor.Err(); err != nil {
		return fmt.Errorf("پیمایش نام‌های بازیکنان: %w", err)
	}
	return nil
}

// promoSections بخش‌هایی که فقط ویترین تبلیغاتی هستند، نه جای اصلی آیتم در کاتالوگ
var promoSections = map[string]bool{
	"weekly":       true,
	"very_special": true,
	"featured":     true,
	"special":      true,
}

// MigrateShopItems ساختار کالکشن فروشگاه را قبل از ساخت ایندکس‌ها سالم می‌کند
//
// ترتیب مهم است: اول نسخه‌های تکراری ادغام می‌شوند (که به section تبلیغاتی نیاز دارد
// تا نسخه مرجع را تشخیص دهد)، بعد آیتم‌هایی که *فقط* در بخش تبلیغاتی هستند نرمال می‌شوند.
func MigrateShopItems(ctx context.Context) error {
	if err := MergeDuplicateShopItems(ctx); err != nil {
		return err
	}
	return NormalizePromoOnlyItems(ctx)
}

// NormalizePromoOnlyItems آیتم‌هایی که هیچ‌وقت نسخه کاتالوگ نداشتند را به مدل جدید می‌برد
//
// این آیتم‌ها (مثل skin_fire یا skin_girl) فقط پیشنهاد ویژه‌اند و در تب اصلی فروشگاه
// نمایش داده نمی‌شوند. در مدل جدید این حالت با featured_section پرشده و section خالی
// بیان می‌شود — یعنی «فقط ویترین، بدون جای ثابت در کاتالوگ».
// اگر بعداً خواستید یکی از این‌ها در تب کاراکترها هم دیده شود، کافی است section آن را
// روی "characters" (یا "weapons") بگذارید.
func NormalizePromoOnlyItems(ctx context.Context) error {
	items := col(ColShopItems)

	promoNames := make([]string, 0, len(promoSections))
	for name := range promoSections {
		promoNames = append(promoNames, name)
	}

	cursor, err := items.Find(ctx, bson.M{"section": bson.M{"$in": promoNames}})
	if err != nil {
		return fmt.Errorf("یافتن آیتم‌های فقط-تبلیغاتی: %w", err)
	}
	defer cursor.Close(ctx)

	var docs []ShopItem
	if err := cursor.All(ctx, &docs); err != nil {
		return fmt.Errorf("خواندن آیتم‌های فقط-تبلیغاتی: %w", err)
	}

	for i := range docs {
		doc := &docs[i]
		doc.FeaturedSection = doc.Section
		doc.Section = "" // بدون جای ثابت در کاتالوگ
		doc.CalculateFinalPrice()

		if _, err := items.UpdateByID(ctx, doc.ID, bson.M{"$set": bson.M{
			"featured_section": doc.FeaturedSection,
			"section":          "",
			"final_price":      doc.FinalPrice,
		}}); err != nil {
			return fmt.Errorf("نرمال‌سازی آیتم %s: %w", doc.ItemID, err)
		}
		fmt.Printf("🎯 آیتم «%s» فقط پیشنهاد ویژه است (بخش ویژه: %q، قیمت نهایی: %d)\n",
			doc.ItemID, doc.FeaturedSection, doc.FinalPrice)
	}
	return nil
}

// MergeDuplicateShopItems آیتم‌های فروشگاه با item_id تکراری را در یک داکیومنت ادغام می‌کند
//
// چرا لازم است: برای نمایش یک آیتم در بخش پیشنهاد ویژه، قبلاً یک کپی دوم از همان آیتم
// با section متفاوت ساخته می‌شد. این کار باعث می‌شد ایندکس یکتای uniq_item_id ساخته نشود
// و کل سرور بالا نیاید. ضمناً buyItemHandler با FindOne یکی از دو نسخه را شانسی برمی‌داشت
// و ممکن بود قیمت اشتباه از بازیکن کم شود.
//
// قانون ادغام: نسخه‌ی کاتالوگ (weapons/characters/currency) مرجع قیمت و استتس است و
// نسخه‌ی تبلیغاتی فقط جای نمایش (featured_section) و درصد تخفیف خود را به آن می‌دهد.
func MergeDuplicateShopItems(ctx context.Context) error {
	items := col(ColShopItems)

	cursor, err := items.Aggregate(ctx, mongo.Pipeline{
		{{Key: "$group", Value: bson.M{
			"_id":  "$item_id",
			"docs": bson.M{"$push": "$$ROOT"},
			"n":    bson.M{"$sum": 1},
		}}},
		{{Key: "$match", Value: bson.M{"n": bson.M{"$gt": 1}}}},
	})
	if err != nil {
		return fmt.Errorf("یافتن آیتم‌های تکراری فروشگاه: %w", err)
	}
	defer cursor.Close(ctx)

	var groups []struct {
		ItemID string     `bson:"_id"`
		Docs   []ShopItem `bson:"docs"`
	}
	if err := cursor.All(ctx, &groups); err != nil {
		return fmt.Errorf("خواندن آیتم‌های تکراری فروشگاه: %w", err)
	}

	merged := 0
	for _, group := range groups {
		// جدیدترین داکیومنت کاتالوگ = مرجع؛ اگر نبود، جدیدترین داکیومنت گروه
		var canonical *ShopItem
		var promo *ShopItem
		for i := range group.Docs {
			doc := &group.Docs[i]
			if promoSections[doc.Section] {
				if promo == nil || doc.ID.Hex() > promo.ID.Hex() {
					promo = doc
				}
				continue
			}
			if canonical == nil || doc.ID.Hex() > canonical.ID.Hex() {
				canonical = doc
			}
		}
		if canonical == nil {
			// همه نسخه‌ها تبلیغاتی بودند — جدیدترین را مرجع بگیر
			canonical = promo
			promo = nil
		}
		if canonical == nil {
			continue
		}

		update := bson.M{}
		if promo != nil {
			// جای نمایش و تخفیف را از نسخه تبلیغاتی بردار، قیمت و استتس را دست نزن
			canonical.FeaturedSection = promo.Section
			canonical.DiscountPercent = promo.DiscountPercent
			update["featured_section"] = promo.Section
			update["discount_percent"] = promo.DiscountPercent
		}
		canonical.CalculateFinalPrice()
		update["final_price"] = canonical.FinalPrice

		if _, err := items.UpdateByID(ctx, canonical.ID, bson.M{"$set": update}); err != nil {
			return fmt.Errorf("ادغام آیتم %s: %w", group.ItemID, err)
		}

		// حذف نسخه‌های اضافی
		res, err := items.DeleteMany(ctx, bson.M{
			"item_id": group.ItemID,
			"_id":     bson.M{"$ne": canonical.ID},
		})
		if err != nil {
			return fmt.Errorf("حذف نسخه تکراری آیتم %s: %w", group.ItemID, err)
		}
		merged += int(res.DeletedCount)
		fmt.Printf("🧹 آیتم «%s» ادغام شد (نسخه اضافی حذف‌شده: %d، بخش ویژه: %q، قیمت نهایی: %d)\n",
			group.ItemID, res.DeletedCount, canonical.FeaturedSection, canonical.FinalPrice)
	}

	if merged > 0 {
		fmt.Printf("🧹 مجموعاً %d نسخه تکراری از فروشگاه حذف شد\n", merged)
	}
	return nil
}

// SetPlayerOnline وضعیت آنلاین/آفلاین بازیکن را ثبت می‌کند
// (نقطه سبز کنار آواتار در لیست دوستان)
func SetPlayerOnline(username string, online bool) {
	if db == nil || username == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	_, _ = col(ColPlayers).UpdateOne(ctx,
		bson.M{"username": username},
		bson.M{"$set": bson.M{"is_online": online, "last_seen_at": time.Now()}})
}

// InitDatabase تمام مراحل آماده‌سازی دیتابیس را به ترتیب اجرا می‌کند
func InitDatabase(ctx context.Context) error {
	EnsureCollections(ctx)

	// مایگریشن‌ها قبل از ایندکس‌های یکتا اجرا می‌شوند تا ساخت ایندکس شکست نخورد
	if err := MigrateGameModes(ctx); err != nil {
		return err
	}
	if err := MigratePlayers(ctx); err != nil {
		return err
	}
	if err := MigrateShopItems(ctx); err != nil {
		return err
	}
	if err := EnsureIndexes(ctx); err != nil {
		return err
	}
	if err := SeedStaticData(ctx); err != nil {
		return err
	}
	return nil
}
