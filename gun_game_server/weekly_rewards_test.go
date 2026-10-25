package main

import (
	"testing"
	"time"
)

func TestWeekStartIsSaturdayMidnight(t *testing.T) {
	cases := []struct {
		now  time.Time
		want string
	}{
		// شنبه ۱۲ سپتامبر ۲۰۲۶، ۱۰ صبح تهران → همان شنبه
		{time.Date(2026, 9, 12, 10, 0, 0, 0, missionsLocation), "2026-09-12"},
		// جمعه‌ی بعدش، یک دقیقه قبل از نیمه‌شب → هنوز همان هفته
		{time.Date(2026, 9, 18, 23, 59, 0, 0, missionsLocation), "2026-09-12"},
		// شنبه‌ی بعد ۰۰:۰۰ → هفته‌ی جدید
		{time.Date(2026, 9, 19, 0, 0, 0, 0, missionsLocation), "2026-09-19"},
		// جمعه ۲۱:۰۰ به وقت UTC یعنی شنبه ۰۰:۳۰ تهران → هفته‌ی جدید
		{time.Date(2026, 9, 18, 21, 0, 0, 0, time.UTC), "2026-09-19"},
	}
	for _, c := range cases {
		if got := weekKey(c.now); got != c.want {
			t.Errorf("weekKey(%v) = %s, want %s", c.now, got, c.want)
		}
	}
}

func TestWeekSummarySecondsLeft(t *testing.T) {
	now := time.Date(2026, 9, 18, 23, 0, 0, 0, missionsLocation) // جمعه ۲۳:۰۰
	summary := weekSummary(now)
	if got := summary["seconds_left"].(int); got != 3600 {
		t.Fatalf("seconds_left = %d, want 3600", got)
	}
}

func TestWeeklyRewardsOnlyTopThree(t *testing.T) {
	for pos := 1; pos <= 3; pos++ {
		r, ok := weeklyRewardFor(pos)
		if !ok {
			t.Fatalf("position %d should have a reward", pos)
		}
		if r.Gems <= 0 || r.XP <= 0 || r.Coins <= 0 {
			t.Fatalf("position %d reward must include gems, xp and coins: %+v", pos, r)
		}
	}
	if _, ok := weeklyRewardFor(4); ok {
		t.Fatal("position 4 must not get a weekly reward")
	}
	// رتبه‌ی بالاتر هیچ‌وقت کمتر نمی‌گیرد
	for i := 1; i < len(WeeklyRewards); i++ {
		a, b := WeeklyRewards[i-1], WeeklyRewards[i]
		if a.Coins < b.Coins || a.Gems < b.Gems || a.XP < b.XP {
			t.Fatalf("reward %d is smaller than reward %d", a.Position, b.Position)
		}
	}
}

func TestPersianDigits(t *testing.T) {
	if got := persianDigits(1203); got != "۱۲۰۳" {
		t.Fatalf("persianDigits = %s", got)
	}
}
