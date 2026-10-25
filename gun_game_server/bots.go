package main

import (
	"context"
	"fmt"
	"math/rand"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// جمعیتِ ثابتِ بات‌ها.
//
// بات‌ها اکانتِ واقعی‌اند و در همان کالکشنِ players می‌نشینند — پس در جدولِ
// امتیازات، پروفایل، دوستان و همه‌جای دیگر مثل آدم دیده می‌شوند. تنها فرقشان
// یک پرچمِ is_bot است که هرگز به کلاینت نمی‌رود (`json:"-"`).
//
// عمداً تعدادشان ثابت و کم است (BotCount): اگر برای هر مسابقه بات تازه بسازیم،
// دیتابیس پر از اکانتِ یک‌بارمصرف می‌شود. این‌ها یک جمعیتِ ثابت‌اند که بارها
// بازی می‌کنند، مثل یک سرورِ کم‌جمعیتِ واقعی.
//
// seedBots یک بار اجرا می‌شود و بعد دست نمی‌زند، دقیقاً مثل seedGameModes —
// تا اگر دستی چیزی را در دیتابیس تنظیم کردی با هر ری‌استارت پاک نشود.

// BotCount چند بات در جمعیت باشد. ۳۸ عدد وسطِ بازه‌ای است که کاربر خواست
// (۳۵ تا ۴۰) و برای پر کردنِ چند مسابقه‌ی هم‌زمانِ ۴v۴ کافی است.
const BotCount = 38

// botSeed بذرِ ثابت: با یک بذر همیشه یک جمعیت. یعنی اگر دیتابیس را پاک کنی
// همان بات‌های قبلی با همان مشخصات برمی‌گردند.
const botSeed = 20260907

// سه سطحِ مهارت. هنگام پر کردنِ مسابقه به‌صورت تصادفی انتخاب می‌شوند، پس
// حریف‌ها همیشه یک‌جور نیستند.
const (
	BotSkillEasy   = "easy"
	BotSkillMedium = "medium"
	BotSkillHard   = "hard"
)

var botSkills = []string{BotSkillEasy, BotSkillMedium, BotSkillHard}

// botFirstNames اسم‌های آدم‌وار. عمداً مخلوطِ فارسی و انگلیسی است، چون
// بازیکن‌های واقعیِ این بازی هم همین‌طورند.
var botFirstNames = []string{
	"Ali", "Reza", "Amir", "Mehdi", "Hossein", "Sina", "Parsa", "Milad",
	"Kian", "Arman", "Behnam", "Farid", "Navid", "Omid", "Pouya", "Saeed",
	"Shayan", "Yasin", "Erfan", "Danial", "Sara", "Nazanin", "Mahsa",
	"Elham", "Niloofar", "Setare", "Ghazal", "Hasti",
	"Viper", "Ghost", "Falcon", "Raven", "Wolf", "Titan", "Blaze", "Storm",
}

// botSuffixes دنباله‌ی اسم. بعضی بازیکن‌ها اسمِ خالی می‌گذارند، بعضی عدد
// می‌چسبانند، بعضی زیرخط — همین بی‌نظمی است که طبیعی نشانش می‌دهد.
var botSuffixes = []string{"", "", "", "_", ".", "-", "ii", "x", "_HD", "77"}

// botCharacters کاراکترهایی که بات‌ها می‌توانند تجهیز کنند. باید زیرمجموعه‌ی
// کاتالوگِ واقعی باشد (balance.go → characterRarity)، وگرنه کلاینت آرتش را
// پیدا نمی‌کند و پروفایلِ بات خالی می‌ماند.
var botCharacters = []string{
	"skin_default", "skin_boy", "skin_girl",
	"skin_iraqian", "skin_angle", "skin_engineer", "skin_smoke", "skin_sniper",
	"skin_joker", "skin_devil", "skin_lighting", "skin_fire",
}

// botWeapons اسلحه‌هایی که بات‌ها می‌توانند تجهیز کنند (assets/items)
var botWeapons = []string{
	"ak47", "hk416", "mp5", "f2000", "fnscare", "mg3",
	"awm", "m24sws", "m82", "tac50", "fnmag", "yuzi2026",
}

var botCountries = []string{"IR", "IR", "IR", "IR", "TR", "IQ", "AF", "AE", "DE", "US"}

// botIsSeeded جلوگیری از تکرارِ بی‌مورد در همان اجرا
var botUsernames []string

// makeBotName یک نامِ کاربریِ آدم‌وار می‌سازد.
//
// حدود یک‌سومشان عمداً به شکلِ Player12345 می‌مانند: بازیکن‌های واقعی هم
// اغلب اسمِ پیش‌فرضشان را عوض نمی‌کنند، پس اگر همه‌ی بات‌ها اسمِ قشنگ داشته
// باشند خودش یک نشانه می‌شود.
func makeBotName(rng *rand.Rand, taken map[string]bool) string {
	for attempt := 0; attempt < 200; attempt++ {
		var name string
		if rng.Intn(3) == 0 {
			name = fmt.Sprintf("Player%d", 10000+rng.Intn(89999))
		} else {
			first := botFirstNames[rng.Intn(len(botFirstNames))]
			suffix := botSuffixes[rng.Intn(len(botSuffixes))]
			name = first + suffix
			if rng.Intn(2) == 0 {
				name = fmt.Sprintf("%s%d", name, rng.Intn(1000))
			}
		}
		if !taken[name] {
			taken[name] = true
			return name
		}
	}
	// عملاً نمی‌رسد؛ فقط برای اینکه تابع همیشه چیزی برگرداند
	return fmt.Sprintf("Player%d", 100000+rng.Intn(899999))
}

// makeBot یک اکانتِ بات با پروفایلِ کامل می‌سازد — کاپ، سطح، آیتم‌های
// داشته، آیتمِ تجهیزشده و آمار. همه‌چیزش با هم می‌خواند: باتی که ۱۲۰۰ کاپ
// دارد سطحش هم بالاست و آمارِ برد و کشتنش هم بزرگ است، وگرنه پروفایلش
// جعلی به‌نظر می‌رسد.
func makeBot(rng *rand.Rand, name string) PlayerModel {
	trophies := rng.Intn(1400)
	level := 1 + trophies/45 + rng.Intn(4)
	if level < 1 {
		level = 1
	}
	// تجربه‌ی متناسب با سطح، تا صفحه‌ی پروفایل عدد بی‌ربط نشان ندهد
	experience := level*level*40 + rng.Intn(400)

	character := botCharacters[rng.Intn(len(botCharacters))]
	weapon := botWeapons[rng.Intn(len(botWeapons))]

	// چند آیتمِ داشته‌ی دیگر کنارِ آیتمِ تجهیزشده، تا انبارش خالی نباشد
	ownedChars := map[string]bool{"skin_default": true, character: true}
	for i := 0; i < rng.Intn(4); i++ {
		ownedChars[botCharacters[rng.Intn(len(botCharacters))]] = true
	}
	ownedWeps := map[string]bool{"ak47": true, "pistol_default": true, weapon: true}
	for i := 0; i < rng.Intn(4); i++ {
		ownedWeps[botWeapons[rng.Intn(len(botWeapons))]] = true
	}

	// آمار متناسب با کاپ: هرچه بالاتر، بازیِ بیشتر و بردِ بیشتر
	games := 20 + trophies/8 + rng.Intn(60)
	wins := games/2 + rng.Intn(games/4+1) - games/8
	if wins < 0 {
		wins = 0
	}
	if wins > games {
		wins = games
	}
	kills := games*2 + rng.Intn(games*2+1)
	deaths := games + rng.Intn(games+1)

	rankID, rankName := rankFromTrophies(trophies)
	now := time.Now()

	p := NewDefaultPlayer(name, fmt.Sprintf("%d", 100000+rng.Intn(899999)))
	p.AvatarID = "avatar_default"
	p.CountryCode = botCountries[rng.Intn(len(botCountries))]
	p.Coins = 500 + rng.Intn(20000)
	p.Gems = rng.Intn(300)
	p.Trophies = trophies
	p.Experience = experience
	p.Level = level
	p.OwnedCharacters = keysOf(ownedChars)
	p.OwnedWeapons = keysOf(ownedWeps)
	p.EquippedCharacter = character
	p.EquippedWeapon = weapon
	p.Stats = PlayerStats{
		Kills:          kills,
		Deaths:         deaths,
		Wins:           wins,
		Losses:         games - wins,
		TotalMatches:   games,
		LastUsedWeapon: weapon,
	}
	p.Rank.TierID = rankID
	p.Rank.TierName = rankName
	// بات‌ها آنلاین نیستند مگر داخل مسابقه — وگرنه لیستِ آنلاین‌ها دروغ می‌شود
	p.IsOnline = false
	p.LastSeenAt = now.Add(-time.Duration(rng.Intn(72)) * time.Hour)
	p.CreatedAt = now.Add(-time.Duration(30+rng.Intn(300)) * 24 * time.Hour)
	p.UpdatedAt = now

	p.IsBot = true
	p.BotSkill = botSkills[rng.Intn(len(botSkills))]
	return p
}

func keysOf(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

// seedBots جمعیتِ بات را یک بار می‌سازد. اگر از قبل هست، فقط اسم‌ها را
// می‌خواند و کاری نمی‌کند.
func seedBots(ctx context.Context) error {
	cur, err := col(ColPlayers).Find(ctx, bson.M{"is_bot": true})
	if err != nil {
		return err
	}
	var existing []PlayerModel
	if err := cur.All(ctx, &existing); err != nil {
		return err
	}

	botUsernames = botUsernames[:0]
	taken := map[string]bool{}
	for _, b := range existing {
		botUsernames = append(botUsernames, b.Username)
		taken[b.Username] = true
	}

	if len(existing) >= BotCount {
		fmt.Printf("🤖 Bots: %d already in the roster\n", len(existing))
		return nil
	}

	rng := rand.New(rand.NewSource(botSeed + int64(len(existing))))
	// اسم‌های واقعیِ آدم‌ها هم نباید تکراری شود
	humanCur, err := col(ColPlayers).Find(ctx, bson.M{}, nil)
	if err == nil {
		var all []struct {
			Username string `bson:"username"`
		}
		if humanCur.All(ctx, &all) == nil {
			for _, h := range all {
				taken[h.Username] = true
			}
		}
	}

	made := 0
	for len(botUsernames) < BotCount {
		name := makeBotName(rng, taken)
		bot := makeBot(rng, name)
		if _, err := col(ColPlayers).InsertOne(ctx, bot); err != nil {
			return fmt.Errorf("insert bot %s: %w", name, err)
		}
		botUsernames = append(botUsernames, name)
		made++
	}
	fmt.Printf("🤖 Bots: seeded %d new (roster now %d)\n", made, len(botUsernames))
	return nil
}

// loadBotsNear تا n باتِ آزاد برمی‌گرداند که کاپشان به target نزدیک است.
//
// اول بات‌های داخلِ بازه‌ی TrophyWindow، به‌ترتیبِ تصادفی (تا هر بار همان
// چند نفر حریف نشوند)؛ اگر کم بودند، بقیه نزدیک‌ترین‌ها از بیرونِ بازه.
// باتِ مشغول (در صف یا مسابقه) و باتِ زیرِ حدِ نصابِ حالت کنار می‌روند.
func loadBotsNear(ctx context.Context, busy map[string]bool, n, minTrophies, target int) ([]PlayerModel, error) {
	if n <= 0 {
		return nil, nil
	}
	cur, err := col(ColPlayers).Find(ctx, bson.M{"is_bot": true})
	if err != nil {
		return nil, err
	}
	var all []PlayerModel
	if err := cur.All(ctx, &all); err != nil {
		return nil, err
	}
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	out := pickBotsNear(all, busy, n, minTrophies, target, rng)

	// مهارت هر بار از نو قرعه می‌خورد، ولی وزنِ قرعه به کاپِ بازیکنی بستگی
	// دارد که بات‌ها برایش آمده‌اند: تازه‌کار بیشتر باتِ آسان می‌بیند و
	// کاپ‌بالا بیشتر سخت. قبلاً یک‌سوم یک‌سوم یک‌سوم بود و تازه‌کار به همان
	// اندازه‌ی بازیکنِ ۱۴۰۰ کاپی باتِ سخت می‌دید.
	for i := range out {
		out[i].BotSkill = botSkillFor(target, rng)
	}
	return out, nil
}

// botSkillFor وزنِ آسان/متوسط/سخت بر اساسِ کاپِ بازیکنِ اصلی:
//
//	زیرِ ۳۰۰      ۷۰٪ / ۳۰٪ / ۰
//	۳۰۰ تا ۱۰۰۰   ۲۵٪ / ۵۵٪ / ۲۰٪
//	بالای ۱۰۰۰    ۱۰٪ / ۴۰٪ / ۵۰٪
func botSkillFor(trophies int, rng *rand.Rand) string {
	easy, medium := 70, 100
	switch {
	case trophies > 1000:
		easy, medium = 10, 50
	case trophies >= 300:
		easy, medium = 25, 80
	}
	r := rng.Intn(100)
	switch {
	case r < easy:
		return BotSkillEasy
	case r < medium:
		return BotSkillMedium
	}
	return BotSkillHard
}

// botSniperWeapons تک‌تیرانداز‌ها — باتِ آسان این‌ها را دست نمی‌گیرد
var botSniperWeapons = map[string]bool{"awm": true, "m24sws": true, "m82": true, "tac50": true}

// gentleBotLoadout باتِ آسان (یعنی حریفِ تازه‌کارها) با تک‌تیرانداز یا
// کاراکترِ افسانه‌ای ظاهر نمی‌شود: اولین مسابقه‌های یک بازیکن نباید با
// یک‌تیرِ AWM تمام شود. بقیه‌ی سطح‌ها همان تجهیزاتِ خودِ بات را دارند.
func gentleBotLoadout(skill, charID, weaponID string, charLevel int, charSkin, weaponSkin string) (string, string, int, string, string) {
	if skill != BotSkillEasy {
		return charID, weaponID, charLevel, charSkin, weaponSkin
	}
	if characterRarity[charID] == "legend" {
		charID, charLevel, charSkin = defaultCharacterID, 1, ""
	}
	if botSniperWeapons[weaponID] {
		weaponID, weaponSkin = defaultWeaponID, ""
	}
	return charID, weaponID, charLevel, charSkin, weaponSkin
}

// pickBotsNear بخشِ بی‌دیتابیسِ loadBotsNear — جدا تا تست شود.
func pickBotsNear(all []PlayerModel, busy map[string]bool, n, minTrophies, target int, rng *rand.Rand) []PlayerModel {
	var near, far []PlayerModel
	for _, b := range all {
		if busy[b.Username] || b.Trophies < minTrophies {
			continue
		}
		if withinWindow(b.Trophies, target) {
			near = append(near, b)
		} else {
			far = append(far, b)
		}
	}
	rng.Shuffle(len(near), func(i, j int) { near[i], near[j] = near[j], near[i] })
	gap := func(b PlayerModel) int {
		d := b.Trophies - target
		if d < 0 {
			return -d
		}
		return d
	}
	sort.SliceStable(far, func(i, j int) bool { return gap(far[i]) < gap(far[j]) })

	out := append(near, far...)
	if n > len(out) {
		n = len(out)
	}
	return append([]PlayerModel(nil), out[:n]...)
}
