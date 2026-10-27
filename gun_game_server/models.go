package main

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// =============================================================================
// این فایل تمام مدل‌هایی که در MongoDB ذخیره می‌شوند را تعریف می‌کند.
// دسته‌بندی کامل «چه چیزی در دیتابیس / چه چیزی فقط داخل بازی» در فایل
// DATA_MODEL.md توضیح داده شده است.
// =============================================================================

// -----------------------------------------------------------------------------
// ۱. فروشگاه (بدون تغییر نسبت به قبل)
// -----------------------------------------------------------------------------

// ShopItem نمایش یک آیتم در فروشگاه (سلاح، کاراکتر، پکیج)
type ShopItem struct {
	// اطلاعات پایه‌ای
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"` // شناسه MongoDB
	ItemID    string             `bson:"item_id" json:"item_id"`            // شناسه منحصر به‌فرد آیتم
	Name      string             `bson:"name" json:"name"`                  // نام نمایشی
	ImagePath string             `bson:"image_path" json:"image_path"`      // مسیر تصویر

	// دسته‌بندی و رتبه
	Category string `bson:"category" json:"category"` // نوع: "weapon", "character", "coin_pack", "gem_pack"
	Rarity   string `bson:"rarity" json:"rarity"`     // کیفیت: "rare", "epic", "legendary"
	Section  string `bson:"section" json:"section"`   // بخش اصلی کاتالوگ: "weapons", "characters", "currency"

	// FeaturedSection بخش تبلیغاتی اختیاری که آیتم *علاوه بر* Section در آن هم نمایش داده می‌شود
	// (مثلاً "weekly" یا "very_special"). خالی یعنی آیتم پیشنهاد ویژه نیست.
	// قبلاً برای این کار یک کپی دوم از آیتم ساخته می‌شد که باعث تکراری‌شدن item_id می‌شد.
	FeaturedSection string `bson:"featured_section,omitempty" json:"featured_section,omitempty"`

	// سیستم قیمت‌گذاری
	CostType        string `bson:"cost_type" json:"cost_type"`               // نوع پرداخت: "coins", "gems"
	OriginalPrice   int    `bson:"original_price" json:"original_price"`     // قیمت اصلی
	DiscountPercent int    `bson:"discount_percent" json:"discount_percent"` // درصد تخفیف (0-100)
	FinalPrice      int    `bson:"final_price" json:"final_price"`           // قیمت نهایی (محاسبه‌شده)

	// فقط بسته‌های ارز (store_currency.go): چند سکه/قلب می‌دهد و شناسه‌ی
	// محصول در بازار/مایکت (برای بسته‌هایی که با پول واقعی خریده می‌شوند)
	Amount    int    `bson:"amount,omitempty" json:"amount,omitempty"`
	ProductID string `bson:"product_id,omitempty" json:"product_id,omitempty"`
	// BonusAmount قلبِ هدیه که روی Amount اضافه می‌شود (store_currency.go)
	BonusAmount int `bson:"bonus_amount,omitempty" json:"bonus_amount,omitempty"`

	// سطح‌بندی آیتم
	InitialLevel int `bson:"initial_level" json:"initial_level"` // سطح شروع
	MaxLevel     int `bson:"max_level" json:"max_level"`         // سطح بالاترین (سقف ۱۰۰)

	// ویژگی‌های گیم‌پلی: قدرت، دقت، سرعت و غیره (محدوده 0-100)
	Stats map[string]float64 `bson:"stats,omitempty" json:"stats,omitempty"`
}

// CalculateFinalPrice قیمت نهایی آیتم را براساس تخفیف محاسبه می‌کند
func (item *ShopItem) CalculateFinalPrice() {
	if item.DiscountPercent > 0 {
		discountAmount := (item.OriginalPrice * item.DiscountPercent) / 100
		item.FinalPrice = item.OriginalPrice - discountAmount
	} else {
		item.FinalPrice = item.OriginalPrice
	}
}

// -----------------------------------------------------------------------------
// ۲. زیرمدل‌های بازیکن
// -----------------------------------------------------------------------------

// PlayerAuth اطلاعات ورود و اتصال اکانت (صفحه «تنظیمات» → بخش اکانت)
// نکته امنیتی: PasswordHash، GoogleID، ایمیل و توکن‌ها هرگز در JSON خروجی
// نمی‌آیند (json:"-") — نمای امنِ اکانت را فقط /auth/status می‌سازد.
type PlayerAuth struct {
	Provider      string     `bson:"provider" json:"provider"`             // "guest" | "google" | "email"
	IsGuest       bool       `bson:"is_guest" json:"is_guest"`             // اکانت مهمان (وصل نشده)
	Email         string     `bson:"email,omitempty" json:"-"`             // ایمیلِ حساب گوگلِ وصل‌شده
	EmailVerified bool       `bson:"email_verified" json:"email_verified"` // تایید ایمیل
	PasswordHash  string     `bson:"password_hash,omitempty" json:"-"`     // هش رمز (bcrypt) — هرگز plain ذخیره نشود
	GoogleID      string     `bson:"google_id,omitempty" json:"-"`         // شناسه گوگل (sub) — وجودش یعنی حساب محافظت‌شده
	GoogleName    string     `bson:"google_name,omitempty" json:"-"`       // اسم نمایشیِ حساب گوگل
	LinkedAt      *time.Time `bson:"linked_at,omitempty" json:"-"`         // زمان وصل شدن به گوگل
	LastLoginAt   time.Time  `bson:"last_login_at,omitempty" json:"last_login_at,omitempty"`

	// Sessions توکن‌های دستگاه‌هایی که به این حساب دسترسی دارند. فقط هش
	// SHA-256 ذخیره می‌شود؛ خودِ توکن فقط یک بار به دستگاه داده می‌شود.
	Sessions []PlayerSession `bson:"sessions,omitempty" json:"-"`
}

// PlayerSession یک دستگاهِ مجاز (handlers_auth.go)
type PlayerSession struct {
	TokenHash string    `bson:"token_hash"`
	Device    string    `bson:"device,omitempty"`
	CreatedAt time.Time `bson:"created_at"`
}

// RecentMatch خلاصه‌ی یک مسابقه برای «فرم اخیر» پروفایل.
// فقط ۱۰ تای آخر نگه داشته می‌شود ($push با $slice).
type RecentMatch struct {
	ModeID string    `bson:"mode_id" json:"mode_id"`
	Won    bool      `bson:"won" json:"won"`
	Draw   bool      `bson:"draw" json:"draw"`
	Kills  int       `bson:"kills" json:"kills"`
	Deaths int       `bson:"deaths" json:"deaths"`
	Weapon string    `bson:"weapon" json:"weapon"`
	At     time.Time `bson:"at" json:"at"`
}

// PlayerStats تمام آمار تجمعی بازیکن (صفحه «پروفایل» → کارت آمار)
type PlayerStats struct {
	TotalMatches    int    `bson:"total_matches" json:"total_matches"`       // کل بازی‌ها
	Wins            int    `bson:"wins" json:"wins"`                         // بردها
	Losses          int    `bson:"losses" json:"losses"`                     // باخت‌ها
	Kills           int    `bson:"kills" json:"kills"`                       // تعداد قربانیان
	Deaths          int    `bson:"deaths" json:"deaths"`                     // تعداد مرگ
	Assists         int    `bson:"assists" json:"assists"`                   // کمک‌ها
	PlaytimeSeconds int64  `bson:"playtime_seconds" json:"playtime_seconds"` // ساعت بازی (ثانیه ذخیره می‌شود)
	MissionsDone    int    `bson:"missions_done" json:"missions_done"`       // ماموریت‌ها
	GrenadeKills    int    `bson:"grenade_kills" json:"grenade_kills"`       // کشته با نارنجک
	HealsGiven      int    `bson:"heals_given" json:"heals_given"`           // درمانِ هم‌تیمی
	LastUsedWeapon  string `bson:"last_used_weapon" json:"last_used_weapon"` // آخرین سلاح مورد استفاده
}

// WinRate درصد برد را محاسبه می‌کند (فیلد محاسبه‌شده — در دیتابیس ذخیره نمی‌شود)
func (s PlayerStats) WinRate() int {
	if s.TotalMatches <= 0 {
		return 0
	}
	return (s.Wins * 100) / s.TotalMatches
}

// KDRatio نسبت کشتن به مرگ
func (s PlayerStats) KDRatio() float64 {
	if s.Deaths <= 0 {
		return float64(s.Kills)
	}
	return float64(s.Kills) / float64(s.Deaths)
}

// PlayerRank وضعیت رتبه فصلی بازیکن (صفحه «پروفایل» → کارت فصل / لجند / رتبه ۵)
type PlayerRank struct {
	SeasonID   string `bson:"season_id" json:"season_id"`       // شناسه فصل جاری
	TierID     string `bson:"tier_id" json:"tier_id"`           // "bronze","silver","gold","legend" ...
	TierName   string `bson:"tier_name" json:"tier_name"`       // نام نمایشی: "لجند"
	Division   int    `bson:"division" json:"division"`         // رتبه داخل تیر: ۵
	Points     int64  `bson:"points" json:"points"`             // امتیاز فعلی
	PointsMax  int64  `bson:"points_max" json:"points_max"`     // امتیاز لازم برای تیر بعدی
	BestTierID string `bson:"best_tier_id" json:"best_tier_id"` // بالاترین تیر تاریخچه

	// --- جایگاه در جدول رتبه‌بندی (فقط سرور می‌نویسدشان) ---
	// BestPosition بهترین رتبه‌ی جدول در این فصل. صفر یعنی هنوز حساب نشده.
	BestPosition int `bson:"best_position" json:"best_position"`
	// PrevPosition رتبه‌ی ثبت‌شده در اسنپ‌شات هفته‌ی قبل — برای نشان دادن
	// «تغییر هفته». صفر یعنی نامعلوم (اسنپ‌شات هفتگی هنوز اجرا نشده).
	PrevPosition int `bson:"prev_position" json:"prev_position"`
}

// UnlockedAchievement یک دستاورد باز شده توسط بازیکن (صفحه «پروفایل» → تازه‌ترین دستاوردها)
type UnlockedAchievement struct {
	AchievementID string    `bson:"achievement_id" json:"achievement_id"`
	Progress      int       `bson:"progress" json:"progress"`       // پیشرفت فعلی
	UnlockedAt    time.Time `bson:"unlocked_at" json:"unlocked_at"` // زمان باز شدن
}

// -----------------------------------------------------------------------------
// ۲.۵ ماموریت روزانه و پاداش فصل
// -----------------------------------------------------------------------------

// PlayerMissionState وضعیت یک ماموریت روزانه برای یک بازیکن.
// فقط سرور می‌نویسدش — کلاینت هیچ‌وقت progress نمی‌فرستد.
type PlayerMissionState struct {
	MissionID string     `bson:"mission_id" json:"mission_id"`
	Progress  int        `bson:"progress" json:"progress"`
	Claimed   bool       `bson:"claimed" json:"claimed"`
	ClaimedAt *time.Time `bson:"claimed_at,omitempty" json:"claimed_at,omitempty"`
}

// DailyMissionDoc ماموریت‌های یک بازیکن در یک روز (کالکشن daily_missions).
// ریست روزانه یعنی day_key عوض می‌شود و رکورد جدید ساخته می‌شود؛ رکورد
// دیروز دست‌نخورده می‌ماند و بعد از ۳۰ روز با TTL خودش پاک می‌شود.
type DailyMissionDoc struct {
	ID       primitive.ObjectID   `bson:"_id,omitempty" json:"-"`
	PlayerID string               `bson:"player_id" json:"player_id"`
	DayKey   string               `bson:"day_key" json:"day_key"` // "2026-08-30"
	Missions []PlayerMissionState `bson:"missions" json:"missions"`
	// BonusClaimed پله‌های جایزه‌ی روزانه که گرفته شده‌اند (بر اساس Need: ۲، ۴، ۶).
	// جدا از Missions نگه داشته می‌شود چون به یک ماموریت خاص وصل نیست بلکه به
	// «چند تا ماموریت امروز تمام شده» وصل است.
	BonusClaimed []int `bson:"bonus_claimed" json:"bonus_claimed"`
	// PlaySeconds زمانِ بازیِ امروز به ثانیه. ماموریتِ «N دقیقه بازی کن» از
	// همین جمع جلو می‌رود؛ قبلاً هر مسابقه جدا به دقیقه گرد می‌شد و مسابقه‌ی
	// زیرِ یک دقیقه (بردِ سریعِ حذفی) هیچ‌وقت چیزی حساب نمی‌شد.
	PlaySeconds int64     `bson:"play_seconds" json:"-"`
	CreatedAt   time.Time `bson:"created_at" json:"created_at"`
	UpdatedAt   time.Time `bson:"updated_at" json:"updated_at"`
}

// PlayerSeasonPass وضعیت پاداش فصل بازیکن (زیرمجموعه‌ی PlayerModel).
// ClaimedLevels پله‌هایی که جایزه‌شان گرفته شده — تا دو بار گرفته نشود.
type PlayerSeasonPass struct {
	SeasonID      string `bson:"season_id" json:"season_id"`
	XP            int    `bson:"xp" json:"xp"`
	ClaimedLevels []int  `bson:"claimed_levels" json:"claimed_levels"`

	// Premium یعنی بتل‌پس طلایی این فصل خریده شده. با ریست فصل خودبه‌خود
	// false می‌شود چون کل PlayerSeasonPass دور ریخته می‌شود.
	Premium bool `bson:"premium" json:"premium"`
	// ClaimedPremium پله‌هایی که جایزه‌ی طلایی‌شان گرفته شده — جدا از
	// ClaimedLevels، چون هر پله دو جایزه دارد (رایگان و طلایی).
	ClaimedPremium []int `bson:"claimed_premium" json:"claimed_premium"`

	// Stats شمارنده‌ی متریک‌های فصل (kills، wins، ...). چالش‌های فصل
	// پیشرفتشان را از همین می‌خوانند، پس کالکشن جدا لازم نیست.
	Stats map[string]int `bson:"stats" json:"stats"`
	// ClaimedChallenges شناسه‌ی چالش‌هایی که جایزه‌شان گرفته شده
	ClaimedChallenges []string `bson:"claimed_challenges" json:"claimed_challenges"`
}

// SeasonCupDef تعریف یک کاپ فصل (کالکشن season_cups).
//
// این کاتالوگ منبع حقیقتِ صفحه‌ی «کاپ ها» است: کلاینت هیچ لیستی از خودش
// ندارد و فقط چیزی را نشان می‌دهد که سرور از دیتابیس خوانده.
type SeasonCupDef struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"-"`
	CupID       string             `bson:"cup_id" json:"cup_id"`
	SeasonID    string             `bson:"season_id" json:"season_id"`
	Name        string             `bson:"name" json:"name"`
	XPRequired  int                `bson:"xp_required" json:"xp_required"`
	RewardCoins int                `bson:"reward_coins" json:"reward_coins"`
	RewardGems  int                `bson:"reward_gems" json:"reward_gems"`
	Icon        string             `bson:"icon" json:"icon"` // کلید تصویر سمت کلاینت
	SortOrder   int                `bson:"sort_order" json:"sort_order"`
}

// PlayerSeasonCups کاپ‌هایی که بازیکن در فصل جاری جایزه‌شان را گرفته.
// فقط سرور می‌نویسدش — کلاینت هیچ‌وقت این آرایه را نمی‌فرستد.
type PlayerSeasonCups struct {
	SeasonID string   `bson:"season_id" json:"season_id"`
	Claimed  []string `bson:"claimed" json:"claimed"`
}

// -----------------------------------------------------------------------------
// ۳. مدل اصلی بازیکن
// -----------------------------------------------------------------------------

// PlayerModel اطلاعات دائمی بازیکن در کالکشن players
type PlayerModel struct {
	ID primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`

	// --- هویت ---
	PlayerID    string `bson:"player_id" json:"player_id"` // آیدی عددی عمومی (نمایش: "ID : ۴۵۱۳۵")
	Username    string `bson:"username" json:"username"`   // نام کاربری منحصربه‌فرد
	AvatarID    string `bson:"avatar_id" json:"avatar_id"` // شناسه آواتار انتخابی
	FrameID     string `bson:"frame_id" json:"frame_id"`   // قاب/بج کنار اسم (مثلا "لجندری")
	CountryCode string `bson:"country_code,omitempty" json:"country_code,omitempty"`

	// --- اقتصاد و پیشرفت ---
	Coins      int `bson:"coins" json:"coins"`           // سکه داخل‌بازی
	Gems       int `bson:"gems" json:"gems"`             // جواهر
	Trophies   int `bson:"trophies" json:"trophies"`     // کاپ — با برد و باخت در حالت‌های چندنفره کم و زیاد می‌شود
	Experience int `bson:"experience" json:"experience"` // تجربه کل
	Level      int `bson:"level" json:"level"`           // سطح بازیکن

	// --- مالکیت و تجهیزات ---
	OwnedWeapons      []string `bson:"owned_weapons" json:"owned_weapons"`
	OwnedCharacters   []string `bson:"owned_characters" json:"owned_characters"`
	EquippedCharacter string   `bson:"equipped_character" json:"equipped_character"`
	// آخرین حالتِ بازی که انتخاب کرده — منوی اصلی همین را روی دکمه نشان می‌دهد
	SelectedMode   string `bson:"selected_mode,omitempty" json:"selected_mode,omitempty"`
	EquippedWeapon string `bson:"equipped_weapon" json:"equipped_weapon"`
	// آموزشِ بارِ اول تمام شده؟ روی حساب است، نه گوشی، تا با نصبِ دوباره یا
	// گوشیِ تازه دوباره نیاید و حسابِ تازه روی گوشیِ قدیمی هم آن را ببیند.
	TutorialDone bool `bson:"tutorial_done" json:"tutorial_done"`

	// --- اسکین‌ها و ارتقا (skins.go) ---
	// OwnedSkins اسکین‌هایی که بازیکن دارد. فقط از بتل‌پس می‌آیند — فروشگاه
	// هیچ‌وقت اسکین نمی‌فروشد.
	OwnedSkins []string `bson:"owned_skins,omitempty" json:"owned_skins"`
	// EquippedSkins اسکینِ انتخاب‌شده برای هر آیتمِ پایه (base_id → skin_id).
	// آیتمی که اینجا کلید ندارد با ظاهر پیش‌فرض خودش دیده می‌شود.
	EquippedSkins map[string]string `bson:"equipped_skins,omitempty" json:"equipped_skins"`
	// ItemLevels سطح ارتقای هر کاراکتر (character_id → سطح). نبودن کلید یعنی سطح ۱.
	ItemLevels map[string]int `bson:"item_levels,omitempty" json:"item_levels"`

	// --- آمار، رتبه، دستاورد ---
	Stats        PlayerStats           `bson:"stats" json:"stats"`
	Rank         PlayerRank            `bson:"rank" json:"rank"`
	Achievements []UnlockedAchievement `bson:"achievements" json:"achievements"`
	// RecentMatches ده مسابقه‌ی آخر (جدیدترین آخر) — «فرم اخیر» پروفایل
	RecentMatches []RecentMatch `bson:"recent_matches,omitempty" json:"-"`

	// پیام‌های همگانی (recipient_id = "*") یک سند برای همه‌اند؛ خوانده/حذف
	// شدنشان برای هر بازیکن جدا این‌جا ثبت می‌شود، نه روی خودِ پیام.
	ReadBroadcasts   []string `bson:"read_broadcasts,omitempty" json:"-"`
	HiddenBroadcasts []string `bson:"hidden_broadcasts,omitempty" json:"-"`

	// --- پاداش فصل (بتل‌پس) ---
	// بازیکنان قدیمی این فیلد را ندارند؛ خالی بودنش یعنی «هنوز شروع نکرده»
	// و currentSeasonPass خودش وضعیت خالیِ فصل جاری را می‌سازد.
	SeasonPass PlayerSeasonPass `bson:"season_pass" json:"season_pass"`

	// --- کاپ‌های فصل (صفحه‌ی رنک → «کاپ ها») ---
	// خالی بودنش یعنی هنوز هیچ کاپی نگرفته؛ currentSeasonCups وضعیت خالیِ
	// فصل جاری را می‌سازد.
	SeasonCups PlayerSeasonCups `bson:"season_cups" json:"season_cups"`

	// --- شهر (کلن) ---
	ClanID   string `bson:"clan_id" json:"clan_id"`     // خالی یعنی عضو هیچ شهری نیست
	ClanRole string `bson:"clan_role" json:"clan_role"` // "leader" | "officer" | "member"

	// --- اجتماعی ---
	Friends []string `bson:"friends" json:"friends"` // لیست player_id دوستان
	Blocked []string `bson:"blocked" json:"blocked"` // لیست player_id بلاک‌شده‌ها

	// --- اکانت و امنیت ---
	Auth     PlayerAuth `bson:"auth" json:"auth"`
	IsBanned bool       `bson:"is_banned" json:"is_banned"`
	// مسدودیت از پنل مدیریت (admin_players.go). BannedUntil خالی یعنی دائمی.
	BanReason   string     `bson:"ban_reason,omitempty" json:"-"`
	BannedAt    *time.Time `bson:"banned_at,omitempty" json:"-"`
	BannedUntil *time.Time `bson:"banned_until,omitempty" json:"-"`
	// ChatMutedUntil تا این لحظه نمی‌تواند در چت پیام بفرستد (پنل مدیریت)
	ChatMutedUntil *time.Time `bson:"chat_muted_until,omitempty" json:"-"`

	// --- بات ---
	// این دو فیلد عمداً `json:"-"` هستند: کلاینت هرگز نباید بفهمد کدام
	// حریف بات است. اگر روزی به JSON راه پیدا کنند، کل زحمتِ «بات‌ها
	// شبیه آدم باشند» بی‌اثر می‌شود.
	IsBot    bool   `bson:"is_bot,omitempty" json:"-"`
	BotSkill string `bson:"bot_skill,omitempty" json:"-"` // easy | medium | hard

	// --- وضعیت آنلاین ---
	IsOnline   bool      `bson:"is_online" json:"is_online"`
	LastSeenAt time.Time `bson:"last_seen_at" json:"last_seen_at"`

	// --- هدیه به دوستان ---
	// آخرین باری که به کسی هدیه داده — هر ۲۴ ساعت فقط یک بار مجاز است.
	LastGiftAt *time.Time `bson:"last_gift_at,omitempty" json:"last_gift_at,omitempty"`

	// --- متادیتا ---
	CreatedAt time.Time `bson:"created_at" json:"created_at"`
	UpdatedAt time.Time `bson:"updated_at" json:"updated_at"`
}

// NewDefaultPlayer یک بازیکن جدید با مقادیر پیش‌فرض می‌سازد
func NewDefaultPlayer(username, playerID string) PlayerModel {
	now := time.Now()
	return PlayerModel{
		PlayerID: playerID,
		Username: username,
		AvatarID: "avatar_default",
		FrameID:  "frame_default",
		// سرمایه‌ی شروعِ هر حسابِ تازه
		Coins:             200,
		Gems:              10,
		Experience:        0,
		Level:             1,
		OwnedWeapons:      []string{"ak47", "pistol_default"},
		OwnedCharacters:   []string{"skin_default"},
		EquippedCharacter: "skin_default",
		EquippedWeapon:    "ak47",
		Stats:             PlayerStats{LastUsedWeapon: "ak47"},
		Rank:              NewDefaultRank(),
		SeasonCups:        PlayerSeasonCups{SeasonID: DefaultSeasonID, Claimed: []string{}},
		Achievements:      []UnlockedAchievement{},
		ClanID:            "",
		ClanRole:          "",
		Friends:           []string{},
		Blocked:           []string{},
		Auth: PlayerAuth{
			Provider: "guest",
			IsGuest:  true,
		},
		IsOnline:   true,
		LastSeenAt: now,
		CreatedAt:  now,
		UpdatedAt:  now,
	}
}

// NewDefaultRank رتبه پیش‌فرض ابتدای فصل
func NewDefaultRank() PlayerRank {
	return PlayerRank{
		SeasonID:   DefaultSeasonID,
		TierID:     "bronze",
		TierName:   "برنز",
		Division:   1,
		Points:     0,
		PointsMax:  1000,
		BestTierID: "bronze",
	}
}

// PublicProfile نسخه سبک و امن پروفایل برای نمایش به بازیکنان دیگر
// (کارت دوست، لیست رتبه‌بندی، جستجوی آیدی)
type PublicProfile struct {
	PlayerID   string    `json:"player_id"`
	Username   string    `json:"username"`
	AvatarID   string    `json:"avatar_id"`
	FrameID    string    `json:"frame_id"`
	Level      int       `json:"level"`
	IsOnline   bool      `json:"is_online"`
	LastSeenAt time.Time `json:"last_seen_at"`
	ClanID     string    `json:"clan_id"`
	ClanName   string    `json:"clan_name"`
	TierID     string    `json:"tier_id"`
	TierName   string    `json:"tier_name"`
	Trophies   int       `json:"trophies"`
}

// ToPublicProfile اطلاعات عمومی بازیکن را استخراج می‌کند
func (p *PlayerModel) ToPublicProfile() PublicProfile {
	pub := PublicProfile{
		PlayerID:   p.PlayerID,
		Username:   p.Username,
		AvatarID:   p.AvatarID,
		FrameID:    p.FrameID,
		Level:      p.Level,
		IsOnline:   p.IsOnline,
		LastSeenAt: p.LastSeenAt,
		ClanID:     p.ClanID,
		Trophies:   p.Trophies,
	}
	// رنک همیشه از کاپِ فعلی — همان قانونِ پروفایل و جدول رتبه‌بندی
	pub.TierID, pub.TierName = rankFromTrophies(p.Trophies)
	return pub
}

// -----------------------------------------------------------------------------
// ۴. شهر / کلن (صفحه «پروفایل» → شهر عضو شده)
// -----------------------------------------------------------------------------

// ClanMember یک عضو شهر
type ClanMember struct {
	PlayerID string    `bson:"player_id" json:"player_id"`
	Username string    `bson:"username" json:"username"`
	Role     string    `bson:"role" json:"role"` // "leader" | "officer" | "member"
	JoinedAt time.Time `bson:"joined_at" json:"joined_at"`
}

// ClanModel مدل شهر در کالکشن clans
type ClanModel struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	ClanID      string             `bson:"clan_id" json:"clan_id"`
	Name        string             `bson:"name" json:"name"` // "شهر جهان"
	Tag         string             `bson:"tag" json:"tag"`   // تگ کوتاه
	Description string             `bson:"description" json:"description"`
	IconPath    string             `bson:"icon_path" json:"icon_path"`
	Level       int                `bson:"level" json:"level"` // سطح: ۱۰
	Experience  int                `bson:"experience" json:"experience"`
	MaxMembers  int                `bson:"max_members" json:"max_members"` // ظرفیت: ۵۰
	Members     []ClanMember       `bson:"members" json:"members"`
	OwnerID     string             `bson:"owner_id" json:"owner_id"`
	IsPublic    bool               `bson:"is_public" json:"is_public"`
	MinLevel    int                `bson:"min_level" json:"min_level"` // حداقل سطح برای عضویت
	CreatedAt   time.Time          `bson:"created_at" json:"created_at"`
}

// MemberCount تعداد اعضای فعلی
func (c *ClanModel) MemberCount() int { return len(c.Members) }

// -----------------------------------------------------------------------------
// ۵. صندوق پیام (صفحه «پیام ها»)
// -----------------------------------------------------------------------------

// انواع پیام
const (
	MsgTypeSystem        = "system"         // پیام از بازی
	MsgTypeFriendRequest = "friend_request" // درخواست دوستی
	MsgTypeGift          = "gift"           // هدیه از دوست
	MsgTypeReward        = "reward"         // جایزه (لول‌آپ، فصل، ...)
	MsgTypeAdmin         = "admin"          // پیام پشتیبانی
)

// MessageReward پاداش ضمیمه‌شده به پیام
type MessageReward struct {
	Coins int      `bson:"coins" json:"coins"`
	Gems  int      `bson:"gems" json:"gems"`
	XP    int      `bson:"xp,omitempty" json:"xp"` // تجربه (مثلاً پاداش هفتگی رتبه‌بندی)
	Items []string `bson:"items" json:"items"`     // item_id ها
}

// IsEmpty بررسی می‌کند پاداش خالی است یا نه
func (r *MessageReward) IsEmpty() bool {
	return r == nil || (r.Coins == 0 && r.Gems == 0 && r.XP == 0 && len(r.Items) == 0)
}

// MessageModel یک پیام در صندوق بازیکن (کالکشن messages)
type MessageModel struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	MessageID string             `bson:"message_id" json:"message_id"`

	RecipientID string `bson:"recipient_id" json:"recipient_id"` // player_id گیرنده
	SenderID    string `bson:"sender_id" json:"sender_id"`       // "system" یا player_id فرستنده
	SenderName  string `bson:"sender_name" json:"sender_name"`   // نام نمایشی فرستنده

	Type  string `bson:"type" json:"type"`   // یکی از MsgType* بالا
	Title string `bson:"title" json:"title"` // "پیام از بازی"
	Body  string `bson:"body" json:"body"`   // متن کامل پیام

	Reward        *MessageReward `bson:"reward,omitempty" json:"reward,omitempty"`
	RewardClaimed bool           `bson:"reward_claimed" json:"reward_claimed"`

	RefID string `bson:"ref_id,omitempty" json:"ref_id,omitempty"` // مثلا request_id درخواست دوستی

	IsRead    bool       `bson:"is_read" json:"is_read"` // تیک دوتایی
	ReadAt    *time.Time `bson:"read_at,omitempty" json:"read_at,omitempty"`
	CreatedAt time.Time  `bson:"created_at" json:"created_at"`
	ExpiresAt *time.Time `bson:"expires_at,omitempty" json:"expires_at,omitempty"` // TTL — حذف خودکار
}

// -----------------------------------------------------------------------------
// ۵.۱ پیام کاربر به سازنده (کالکشن support_messages)
// کاربر داخل تنظیمات دکمه‌ی «ارسال پیام» را می‌زند، متن را با کیبورد گوشی
// می‌نویسد و ثبت می‌کند. اینجا ذخیره می‌شود تا سازنده در دیتابیس ببیندش.
// -----------------------------------------------------------------------------

// وضعیت رسیدگی به پیام کاربر
const (
	SupportStatusNew      = "new"      // خوانده نشده
	SupportStatusRead     = "read"     // سازنده دیده
	SupportStatusAnswered = "answered" // جواب داده شده
	SupportStatusClosed   = "closed"   // بسته شده (بدون نیاز به کار بیشتر)
)

// SupportReply یک پاسخِ پشتیبانی که از پنل مدیریت به صندوق پیامِ بازیکن رفته
type SupportReply struct {
	By        string    `bson:"by" json:"by"`                 // نام ادمین
	Body      string    `bson:"body" json:"body"`             // متن پاسخ
	MessageID string    `bson:"message_id" json:"message_id"` // پیامِ ساخته‌شده در messages
	At        time.Time `bson:"at" json:"at"`
}

// SupportMessageModel یک پیام از سمت بازیکن به سازنده‌ی بازی
type SupportMessageModel struct {
	ID       primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	TicketID string             `bson:"ticket_id" json:"ticket_id"`

	Username string `bson:"username" json:"username"`   // نام کاربر — همانی که در لیست می‌بینی
	PlayerID string `bson:"player_id" json:"player_id"` // آیدی عمومی بازیکن

	Body string `bson:"body" json:"body"` // متن پیام

	Platform   string `bson:"platform,omitempty" json:"platform,omitempty"`       // Android / Windows / ...
	AppVersion string `bson:"app_version,omitempty" json:"app_version,omitempty"` // نسخه‌ی بازی

	Status    string    `bson:"status" json:"status"` // یکی از SupportStatus* بالا
	CreatedAt time.Time `bson:"created_at" json:"created_at"`

	// رسیدگی از پنل مدیریت (admin_content.go)
	Replies   []SupportReply `bson:"replies,omitempty" json:"replies,omitempty"`
	UpdatedAt *time.Time     `bson:"updated_at,omitempty" json:"updated_at,omitempty"`
}

// SupportMessageBody بدنه‌ی درخواست POST /support/message
type SupportMessageBody struct {
	Username   string `json:"username"`
	PlayerID   string `json:"player_id"`
	Body       string `json:"body"`
	Platform   string `json:"platform"`
	AppVersion string `json:"app_version"`
}

// -----------------------------------------------------------------------------
// ۶. درخواست دوستی (صفحه «دوستان» + «پیام ها»)
// -----------------------------------------------------------------------------

// وضعیت‌های درخواست دوستی
const (
	FriendReqPending   = "pending"
	FriendReqAccepted  = "accepted"
	FriendReqRejected  = "rejected"
	FriendReqCancelled = "cancelled"
)

// FriendRequestModel یک درخواست دوستی (کالکشن friend_requests)
type FriendRequestModel struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	RequestID string             `bson:"request_id" json:"request_id"`

	FromID       string `bson:"from_id" json:"from_id"`
	FromUsername string `bson:"from_username" json:"from_username"`
	ToID         string `bson:"to_id" json:"to_id"`
	ToUsername   string `bson:"to_username" json:"to_username"`

	Status      string     `bson:"status" json:"status"`
	CreatedAt   time.Time  `bson:"created_at" json:"created_at"`
	RespondedAt *time.Time `bson:"responded_at,omitempty" json:"responded_at,omitempty"`
}

// -----------------------------------------------------------------------------
// ۷. کاتالوگ دستاوردها (کالکشن achievements — دیتای استاتیک بازی)
// -----------------------------------------------------------------------------

// AchievementDef تعریف یک دستاورد
type AchievementDef struct {
	ID            primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	AchievementID string             `bson:"achievement_id" json:"achievement_id"`
	Name          string             `bson:"name" json:"name"` // "تیرانداز ماهر"
	Description   string             `bson:"description" json:"description"`
	IconPath      string             `bson:"icon_path" json:"icon_path"`
	Metric        string             `bson:"metric" json:"metric"` // "kills","wins","total_matches","playtime_seconds",...
	Target        int                `bson:"target" json:"target"` // مقدار لازم برای باز شدن
	RewardCoins   int                `bson:"reward_coins" json:"reward_coins"`
	RewardGems    int                `bson:"reward_gems" json:"reward_gems"`
	SortOrder     int                `bson:"sort_order" json:"sort_order"`
}

// -----------------------------------------------------------------------------
// ۸. فصل و رتبه‌بندی (کالکشن seasons)
// -----------------------------------------------------------------------------

// RankTier یک تیر رتبه‌بندی
type RankTier struct {
	TierID            string `bson:"tier_id" json:"tier_id"`
	Name              string `bson:"name" json:"name"`
	Divisions         int    `bson:"divisions" json:"divisions"`
	PointsPerDivision int64  `bson:"points_per_division" json:"points_per_division"`
	SortOrder         int    `bson:"sort_order" json:"sort_order"`
}

// SeasonModel یک فصل رقابتی
type SeasonModel struct {
	ID       primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	SeasonID string             `bson:"season_id" json:"season_id"`
	Name     string             `bson:"name" json:"name"`
	StartsAt time.Time          `bson:"starts_at" json:"starts_at"`
	EndsAt   time.Time          `bson:"ends_at" json:"ends_at"`
	IsActive bool               `bson:"is_active" json:"is_active"`
	Tiers    []RankTier         `bson:"tiers" json:"tiers"`
}

// -----------------------------------------------------------------------------
// ۹. تاریخچه مسابقات (کالکشن matches) — منبع تولید آمار پروفایل
// -----------------------------------------------------------------------------

// MatchParticipant عملکرد یک بازیکن در یک مسابقه
type MatchParticipant struct {
	PlayerID     string `bson:"player_id" json:"player_id"`
	Username     string `bson:"username" json:"username"`
	Kills        int    `bson:"kills" json:"kills"`
	Deaths       int    `bson:"deaths" json:"deaths"`
	Assists      int    `bson:"assists" json:"assists"`
	GrenadeKills int    `bson:"grenade_kills" json:"grenade_kills"`
	HealsGiven   int    `bson:"heals_given" json:"heals_given"`
	Won          bool   `bson:"won" json:"won"`
	XPGained     int    `bson:"xp_gained" json:"xp_gained"`
	CoinsGained  int    `bson:"coins_gained" json:"coins_gained"`
	RankDelta    int64  `bson:"rank_delta" json:"rank_delta"`
	WeaponUsed   string `bson:"weapon_used" json:"weapon_used"`
}

// MatchRecord یک مسابقه تمام‌شده
type MatchRecord struct {
	ID              primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	MatchID         string             `bson:"match_id" json:"match_id"`
	Mode            string             `bson:"mode" json:"mode"`
	MapName         string             `bson:"map_name" json:"map_name"`
	StartedAt       time.Time          `bson:"started_at" json:"started_at"`
	EndedAt         time.Time          `bson:"ended_at" json:"ended_at"`
	DurationSeconds int64              `bson:"duration_seconds" json:"duration_seconds"`
	Participants    []MatchParticipant `bson:"participants" json:"participants"`
}

// -----------------------------------------------------------------------------
// ۱۰. مدل درون‌حافظه‌ای بازیکن (ذخیره نمی‌شود — فقط طول اتصال WebSocket)
// -----------------------------------------------------------------------------

// Player وضعیت لحظه‌ای بازیکن در حین بازی (RAM، نه دیتابیس)
type Player struct {
	Username string `json:"username"`
	PlayerID string `json:"player_id"`
	// Team شناسه‌ی تیم در همین مسابقه. خالی یعنی مسابقه‌ی بی‌تیم (تمرین).
	// بات‌ها از روی همین تصمیم می‌گیرند به چه کسی شلیک نکنند.
	Team string `json:"team"`
	// MatchID مسابقه‌ای که این بازیکن در آن است.
	//
	// همه‌ی پخش‌ها با همین فیلتر می‌شوند. بدون آن، هر اکانتی که سوکتش باز
	// بود در زمینِ بقیه ظاهر می‌شد — حتی اگر اصلاً سرچ نکرده بود.
	MatchID   string  `json:"-"`
	X         float64 `json:"x"`
	Y         float64 `json:"y"`
	Rot       float64 `json:"rot"`
	Character string  `json:"character"`
	// CharacterLevel سطحِ ارتقای کاراکترِ تجهیزشده (از ItemLevels خوانده می‌شود).
	// روی تراز اثر می‌گذارد — balance.go → CharacterStatsAtLevel
	CharacterLevel int `json:"character_level"`
	// Stats ترازِ حل‌شده‌ی همین کاراکتر. برای کلاینت فرستاده می‌شود تا رابط
	// کاربری (مثلاً نشانه‌گیریِ بمب) بداند سقفِ برد چقدر است. مرجعِ گیم‌پلی
	// همچنان سرور است — این فقط برای نمایش است. با applyLoadout ست می‌شود.
	Stats  CharStats `json:"stats"`
	Weapon string    `json:"weapon"`
	// CharacterSkin و WeaponSkin فقط ظاهرند: کلاینت با این‌ها اسپرایت را
	// عوض می‌کند. تراز همیشه از Character/Weapon (آیتم پایه) می‌آید.
	// خالی یعنی ظاهر پیش‌فرض همان آیتم.
	CharacterSkin     string    `json:"character_skin"`
	WeaponSkin        string    `json:"weapon_skin"`
	Health            int       `json:"health"`
	Kills             int       `json:"kills"`   // آمار همین راند — پایان بازی در matches ثبت می‌شود
	Deaths            int       `json:"deaths"`  // آمار همین راند
	Assists           int       `json:"assists"` // آمار همین راند
	JoinedAt          time.Time `json:"-"`
	InvulnerableUntil time.Time `json:"-"`
	// ShieldLeft ثانیه‌های باقی‌مانده‌ی محافظِ تولد. هر بار قبل از فرستادنِ
	// لیستِ بازیکن‌ها از روی InvulnerableUntil پر می‌شود، تا کلاینت گنبدِ
	// محافظ را دقیقاً به‌اندازه‌ی همان چیزی نشان بدهد که سرور اعمال می‌کند
	// — حتی برای بازیکنی که وسطِ محافظ تازه وارد دیدش شده.
	ShieldLeft   float64   `json:"shield_left"`
	LastHealTime time.Time `json:"-"`
	LastBombTime time.Time `json:"-"`
	LastMoveTime time.Time `json:"-"` // برای سقف سرعت در اعتبارسنجی حرکت
	// MoveBudget چند واحد هنوز اجازه‌ی جابه‌جایی دارد (سطلِ توکن). به‌جای
	// «حداقل ۸ واحد در هر پیام» — که با پیام‌های پشتِ‌سرِهم سرعت‌هک می‌داد —
	// با زمانِ واقعی پر می‌شود و بسته‌های به‌هم‌چسبیده‌ی بعد از لگ را هم جذب می‌کند.
	MoveBudget float64 `json:"-"`
	// InArena یعنی با joinِ آرنا آمده، نه فقط سوکتِ منو. بازیکن‌های منو
	// MatchIDِ خالی دارند؛ بدونِ این پرچم هر وصل/قطع شدنی لیستِ کاملِ همه‌ی
	// منویی‌ها را برای همه‌ی منویی‌ها می‌فرستاد (O(N²)) و با ۷۰ نفر آنلاین
	// از بافرِ ۶۴ کیلوباییِ کلاینت رد می‌شد.
	InArena bool `json:"-"`
	// ClaimedRot آخرین جهتی که کلاینت گفته و RotAt لحظه‌ای که p.Rot آخرین بار
	// به سمتش چرخید. قبل از هر چکِ مخروط، p.Rot با سرعتِ مجاز به ClaimedRot
	// می‌رسد؛ وگرنه اگر کلاینت بعد از چرخیدن ساکت می‌ماند، جهتِ سرور جا
	// می‌ماند و تیرهای درست رد می‌شدند.
	ClaimedRot float64   `json:"-"`
	RotAt      time.Time `json:"-"`

	// --- توانایی‌های دکمه‌ای (abilities.go) ---
	// SprintUntil تا این لحظه سقفِ سرعتِ حرکت SprintSpeedMult برابر است
	SprintUntil time.Time `json:"-"`
	// GuardUntil سپرِ دستی: تا این لحظه هیچ تیر و ترکش و لیزری اثر نمی‌کند.
	// مثلِ محافظِ تولد، حمله‌ی خودِ صاحبش (تیر، لیزر، بمب) آن را برمی‌دارد.
	GuardUntil time.Time `json:"-"`
	// LaserUntil / LaserNextTick پرتوِ لیزرِ فعال و زمانِ ضربه‌ی بعدی‌اش
	LaserUntil    time.Time `json:"-"`
	LaserNextTick time.Time `json:"-"`
	// GuardLeft / SprintLeft / LaserLeft ثانیه‌های باقی‌مانده — مثل ShieldLeft
	// قبل از هر پخشِ لیستِ بازیکن‌ها پر می‌شوند تا بازیکنی که وسطِ کار
	// می‌رسد هم سپر و لیزر را درست ببیند.
	GuardLeft  float64 `json:"guard_left"`
	SprintLeft float64 `json:"sprint_left"`
	LaserLeft  float64 `json:"laser_left"`
	// BombsLeft بمب‌های باقی‌مانده در این مسابقه (از BombStock). مرجعش
	// hub.bombsUsed است تا با join دوباره پر نشود؛ این فقط برای نمایش است.
	BombsLeft int `json:"bombs_left"`

	// Away اتصالش افتاده و جایش reconnectGrace نگه داشته شده (reconnect.go):
	// یخ‌زده و آسیب‌ناپذیر. AwayLeft ثانیه‌های مانده تا آزاد شدنِ جایش — مثل
	// ShieldLeft قبل از هر پخش پر می‌شود. هر دو omitempty تا کلاینتِ قدیمی و
	// پیامِ معمولی دست نخورند.
	Away     bool    `json:"away,omitempty"`
	AwayLeft float64 `json:"away_left,omitempty"`

	// Arena زمینی که این بازیکن روی آن بازی می‌کند — لحظه‌ی join از روی حالتِ
	// مسابقه انتخاب می‌شود (arena.go → ArenaForMode). هر اعتبارسنجیِ حرکت،
	// خطِ دید و انفجار باید از همین بخواند، نه از زمینِ سراسری.
	Arena *Arena `json:"-"`
}

// -----------------------------------------------------------------------------
// ۱۱. DTO های درخواست (بدنه‌ی HTTP)
// -----------------------------------------------------------------------------

// EquipRequest درخواست تجهیز کردن یک آیتم
type EquipRequest struct {
	Username string `json:"username"`
	ItemID   string `json:"item_id"`
	Category string `json:"category"` // "weapon" یا "character"
}

// BuyRequest درخواست خرید یک آیتم
type BuyRequest struct {
	Username string `json:"username"`
	ItemID   string `json:"item_id"`
	Category string `json:"category"` // "weapon","character","coin_pack","gem_pack"
}

// UpdateProfileRequest تغییر نام کاربری / آواتار
type UpdateProfileRequest struct {
	Username    string `json:"username"`
	NewUsername string `json:"new_username,omitempty"`
	AvatarID    string `json:"avatar_id,omitempty"`
	FrameID     string `json:"frame_id,omitempty"`
}

// FriendRequestBody ارسال درخواست دوستی با آیدی
type FriendRequestBody struct {
	Username string `json:"username"`  // فرستنده
	TargetID string `json:"target_id"` // player_id مقصد
}

// FriendRespondBody پاسخ به درخواست دوستی (پذیرفتن / رد)
type FriendRespondBody struct {
	Username  string `json:"username"`
	RequestID string `json:"request_id"`
	Accept    bool   `json:"accept"`
}

// FriendRemoveBody حذف دوست
type FriendRemoveBody struct {
	Username string `json:"username"`
	FriendID string `json:"friend_id"`
}

// SendGiftBody ارسال هدیه به دوست
type SendGiftBody struct {
	Username string `json:"username"`
	FriendID string `json:"friend_id"`
	Coins    int    `json:"coins"`
	Gems     int    `json:"gems"`
	Note     string `json:"note,omitempty"`
}

// MessageActionBody عملیات روی پیام (خواندن / دریافت جایزه / حذف)
type MessageActionBody struct {
	Username  string `json:"username"`
	MessageID string `json:"message_id"`
}

// MatchResultBody ثبت نتیجه یک مسابقه از سمت سرور بازی
type MatchResultBody struct {
	MatchID         string             `json:"match_id"`
	Mode            string             `json:"mode"`
	MapName         string             `json:"map_name"`
	DurationSeconds int64              `json:"duration_seconds"`
	Participants    []MatchParticipant `json:"participants"`
}

// -----------------------------------------------------------------------------
// ۹. شهر (کلن) — منوی «شهر» در منوی اصلی
// -----------------------------------------------------------------------------

// نقش‌های عضو شهر. ترتیب اهمیت: leader > officer > member
const (
	ClanRoleLeader  = "leader"  // بنیان‌گذار شهر — همه‌ی اختیارات
	ClanRoleOfficer = "officer" // معاون — می‌تواند عضو بپذیرد و اخراج کند
	ClanRoleMember  = "member"  // عضو عادی
)

// وضعیت درخواست عضویت در شهر (هم‌شکل با وضعیت‌های درخواست دوستی)
const (
	ClanReqPending  = "pending"
	ClanReqAccepted = "accepted"
	ClanReqRejected = "rejected"
)

// قوانین ساخت و عضویت شهر
const (
	ClanCreateCost     = 5000 // هزینه‌ی ساخت شهر (سکه)
	ClanDefaultMaxMem  = 50   // ظرفیت پیش‌فرض شهر تازه‌ساخته
	ClanMinNameLen     = 3
	ClanMaxNameLen     = 18
	ClanMinTagLen      = 2
	ClanMaxTagLen      = 5
	ClanMaxDescLen     = 120
	ClanBrowsePageSize = 30   // تعداد شهرهای هر صفحه‌ی لیست
	ClanRenameCost     = 1000 // هزینه‌ی تغییر نام یا تگ شهر (سکه)
	ClanMaxMinLevel    = 99   // سقف «حداقل سطح عضویت» که رهبر می‌تواند بگذارد
)

// clanRoleRank وزن نقش را برای مقایسه‌ی اختیارات برمی‌گرداند.
// هر جا لازم شد «آیا A از B بالاتر است؟» با همین مقایسه می‌شود.
func clanRoleRank(role string) int {
	switch role {
	case ClanRoleLeader:
		return 3
	case ClanRoleOfficer:
		return 2
	case ClanRoleMember:
		return 1
	}
	return 0
}

// ClanJoinRequestModel یک درخواست عضویت در شهر (کالکشن clan_requests).
// فقط شهرهای خصوصی (is_public=false) درخواست می‌سازند؛ شهر عمومی
// بازیکن را بدون واسطه عضو می‌کند.
type ClanJoinRequestModel struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	RequestID string             `bson:"request_id" json:"request_id"`

	ClanID   string `bson:"clan_id" json:"clan_id"`
	ClanName string `bson:"clan_name" json:"clan_name"`

	FromID       string `bson:"from_id" json:"from_id"`
	FromUsername string `bson:"from_username" json:"from_username"`
	FromLevel    int    `bson:"from_level" json:"from_level"`
	FromAvatarID string `bson:"from_avatar_id" json:"from_avatar_id"`

	Status      string     `bson:"status" json:"status"`
	CreatedAt   time.Time  `bson:"created_at" json:"created_at"`
	RespondedAt *time.Time `bson:"responded_at,omitempty" json:"responded_at,omitempty"`
}

// --- بادی درخواست‌های HTTP منوی شهر ---

// ClanCreateBody ساخت شهر جدید
type ClanCreateBody struct {
	Username    string `json:"username"`
	Name        string `json:"name"`
	Tag         string `json:"tag"`
	Description string `json:"description,omitempty"`
	IconPath    string `json:"icon_path,omitempty"`
	IsPublic    bool   `json:"is_public"`
	MinLevel    int    `json:"min_level,omitempty"`
}

// ClanUpdateBody ویرایش پروفایل شهر (فقط رهبر).
// هر فیلدی که nil باشد دست نمی‌خورد — کلاینت فقط چیزی را که عوض شده می‌فرستد.
type ClanUpdateBody struct {
	Username    string  `json:"username"`
	Name        *string `json:"name,omitempty"`
	Tag         *string `json:"tag,omitempty"`
	Description *string `json:"description,omitempty"`
	IconPath    *string `json:"icon_path,omitempty"` // "emblem:<نماد>:<رنگ>"
	IsPublic    *bool   `json:"is_public,omitempty"`
	MinLevel    *int    `json:"min_level,omitempty"`
}

// ClanJoinBody درخواست عضویت / ترک شهر
type ClanJoinBody struct {
	Username string `json:"username"`
	ClanID   string `json:"clan_id,omitempty"`
}

// ClanMemberActionBody اخراج عضو یا تغییر نقش او
type ClanMemberActionBody struct {
	Username string `json:"username"`       // انجام‌دهنده (باید leader یا officer باشد)
	TargetID string `json:"target_id"`      // player_id عضو هدف
	Role     string `json:"role,omitempty"` // فقط برای تغییر نقش
}

// ClanRespondBody پاسخ رهبر/معاون به درخواست عضویت
type ClanRespondBody struct {
	Username  string `json:"username"`
	RequestID string `json:"request_id"`
	Accept    bool   `json:"accept"`
}

// -----------------------------------------------------------------------------
// ۱۲. چت زنده (صفحه «چت» — خصوصی / شهر / جهانی)
// -----------------------------------------------------------------------------

// کانال‌های چت
const (
	ChatChannelPrivate = "private" // چت دو نفره — فقط بین دوستان
	ChatChannelCity    = "city"    // چت اعضای یک شهر (کلن)
	ChatChannelGlobal  = "global"  // چت عمومی همه‌ی بازیکن‌ها
)

// محدودیت‌های چت
const (
	ChatMaxTextLength   = 300      // بیشترین طول یک پیام
	ChatHistoryLimit    = 60       // تعداد پیام‌های هر بار گرفتن تاریخچه
	ChatMaxHistoryLimit = 120      // سقف مجاز برای پارامتر limit
	ChatSendCooldown    = 700      // میلی‌ثانیه فاصله‌ی لازم بین دو پیام یک نفر
	ChatRoomGlobal      = "global" // کلید ثابت اتاق جهانی
	ChatPublicTTLDays   = 7        // پیام‌های جهانی/شهر بعد از این مدت پاک می‌شوند
)

// ChatMessageModel یک پیام چت در کالکشن chat_messages
//
// اطلاعات فرستنده (نام، آواتار، سطح) عمداً کنار خود پیام ذخیره می‌شود
// تا نمایش تاریخچه فقط یک کوئری باشد؛ وضعیت آنلاین بودن اما همیشه
// لحظه‌ای از کالکشن players خوانده می‌شود چون مدام عوض می‌شود.
type ChatMessageModel struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"-"`
	MessageID string             `bson:"message_id" json:"message_id"`

	Room    string `bson:"room" json:"room"`       // global | city:<clan_id> | dm:<id1>_<id2>
	Channel string `bson:"channel" json:"channel"` // یکی از ChatChannel* بالا

	SenderID     string `bson:"sender_id" json:"sender_id"`
	SenderName   string `bson:"sender_name" json:"sender_name"`
	SenderAvatar string `bson:"sender_avatar" json:"sender_avatar"`
	SenderLevel  int    `bson:"sender_level" json:"sender_level"`
	SenderClan   string `bson:"sender_clan,omitempty" json:"sender_clan,omitempty"` // نام شهر، برای نشان کنار اسم
	SenderTier   string `bson:"sender_tier,omitempty" json:"sender_tier,omitempty"` // نام رده‌ی رتبه‌بندی

	Text      string    `bson:"text" json:"text"`
	CreatedAt time.Time `bson:"created_at" json:"created_at"`

	// فقط برای پیام‌های جهانی و شهر پر می‌شود — ایندکس TTL با همین فیلد
	// آن‌ها را خودکار پاک می‌کند. پیام‌های خصوصی این فیلد را ندارند و می‌مانند.
	ExpiresAt *time.Time `bson:"expires_at,omitempty" json:"-"`
}

// ChatReadModel آخرین باری که یک بازیکن یک اتاق را باز کرده
// (کالکشن chat_reads) — تعداد پیام‌های خوانده‌نشده از روی همین حساب می‌شود.
type ChatReadModel struct {
	ID         primitive.ObjectID `bson:"_id,omitempty" json:"-"`
	PlayerID   string             `bson:"player_id" json:"player_id"`
	Room       string             `bson:"room" json:"room"`
	LastReadAt time.Time          `bson:"last_read_at" json:"last_read_at"`
}

// ChatSendBody بدنه‌ی POST /chat/send
type ChatSendBody struct {
	Username string `json:"username"`
	Channel  string `json:"channel"`           // private | city | global
	PeerID   string `json:"peer_id,omitempty"` // فقط برای private — player_id طرف مقابل
	Text     string `json:"text"`
}

// ChatReadBody بدنه‌ی POST /chat/read
type ChatReadBody struct {
	Username string `json:"username"`
	Channel  string `json:"channel"`
	PeerID   string `json:"peer_id,omitempty"`
}
