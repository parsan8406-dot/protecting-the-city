package main

import (
	"math/rand"
	"time"
)

// تمِ ظاهریِ زمینِ هر مسابقه — بک‌گراند، سه بافتِ دیوار و سه بافتِ مانع.
//
// تم فقط ظاهر است: چیدمانِ دیوارها و برخورد از نقشه (arena.go) می‌آید و به
// تم ربطی ندارد. سرور تم را انتخاب می‌کند و در مسابقه (PendingMatch.Theme) و
// پیامِ spawn می‌فرستد تا همه‌ی بازیکن‌های یک مسابقه یک زمین ببینند.
//
// هر رنک یک یا چند تم دارد؛ اگر بیش از یکی باشد به‌تصادف انتخاب می‌شود.
// شناسه‌ها با پوشه‌های assets/themes/ در کلاینت یکی‌اند (scripts/ThemeArt.gd
// — آن جدول باید با این یکی بماند).
var rankThemes = map[string][]string{
	"bronze":   {"hell"},
	"silver":   {"heaven"},
	"gold":     {"ocean"},
	"platinum": {"ice"},
	"diamond":  {"pirate_ship"},
	"legend":   {"magic", "underworld"},
}

// DefaultTheme وقتی رنک ناشناخته است
const DefaultTheme = "hell"

var themeRng = rand.New(rand.NewSource(time.Now().UnixNano()))

// themeForRank یکی از تم‌های این رنک، به‌تصادف.
// با mmMu گرفته‌شده صدا زده می‌شود، پس themeRng نیازی به قفلِ جدا ندارد.
func themeForRank(rankID string) string {
	opts := rankThemes[rankID]
	if len(opts) == 0 {
		return DefaultTheme
	}
	return opts[themeRng.Intn(len(opts))]
}

// themeForPlayers تمِ مسابقه از روی بالاترین رنکِ بینِ شرکت‌کننده‌ها.
//
// بات‌ها هم حساب می‌شوند: برای بازیکن هیچ فرقی بینِ بات و آدم پیدا نیست و
// اگر بات‌ها کنار گذاشته شوند، زمین با رنکی جور درمی‌آید که در لابی دیده
// نمی‌شود.
func themeForPlayers(players []QueuedPlayer) string {
	best := -1
	bestID := ""
	for _, p := range players {
		if i := tierIndexOf(p.RankID); i > best {
			best, bestID = i, p.RankID
		}
	}
	return themeForRank(bestID)
}

// ThemeOfMatch تمِ مسابقه‌ی جاری‌ِ یک بازیکن. خالی یعنی مسابقه‌ای نیست
// (تمرین) — آن‌وقت کلاینت از رنکِ خودِ بازیکن تم می‌گیرد.
func ThemeOfMatch(username string) string {
	mmMu.Lock()
	defer mmMu.Unlock()
	if m := mmMatches[username]; m != nil {
		return m.Theme
	}
	return ""
}
