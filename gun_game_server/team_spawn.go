package main

import (
	"math"
	"math/rand"
)

// نقطه‌ی شروعِ تیمی: هر تیم کنارِ هم، دو تیم دور از هم.
//
// قبلاً هر بازیکن «دورترین نقطه از بقیه» را می‌گرفت، یعنی هشت نفر در هشت
// گوشه‌ی نقشه پخش می‌شدند و هم‌تیمی‌ها هیچ‌وقت همدیگر را نمی‌دیدند. حالا
// دو اتاقِ دور از هم انتخاب می‌شود و هر تیم داخلِ اتاقِ خودش می‌نشیند.
//
// اتاق‌ها از همان arena_map.json می‌آیند که tools/build_arena.py می‌سازد، پس
// اگر چیدمانِ نقشه عوض شود این هم خودش عوض می‌شود.

// Room یک اتاقِ نقشه (x, y, w, h در واحدِ جهانی)
type Room struct {
	X, Y, W, H float64
}

// Center مرکزِ اتاق
func (r Room) Center() (float64, float64) {
	return r.X + r.W*0.5, r.Y + r.H*0.5
}

// teamRoomsFor دو اتاقِ دور از هم برای دو تیم برمی‌گرداند.
//
// انتخاب بر اساسِ matchID قطعی است: همه‌ی بازیکن‌های یک مسابقه باید به یک
// جفت اتاق برسند، وگرنه هر کس در جای دیگری ظاهر می‌شود.
func (a *Arena) teamRoomsFor(matchID string) (Room, Room, bool) {
	if len(a.Rooms) < 2 {
		return Room{}, Room{}, false
	}
	// جفتِ اتاق‌هایی که از هم دورترند
	bestI, bestJ, bestD := 0, 1, -1.0
	for i := 0; i < len(a.Rooms); i++ {
		for j := i + 1; j < len(a.Rooms); j++ {
			x1, y1 := a.Rooms[i].Center()
			x2, y2 := a.Rooms[j].Center()
			d := math.Hypot(x2-x1, y2-y1)
			if d > bestD {
				bestI, bestJ, bestD = i, j, d
			}
		}
	}
	// کدام تیم کدام سر — از روی matchID، تا هر مسابقه یک‌جور نباشد ولی
	// داخلِ یک مسابقه ثابت بماند
	if hashString(matchID)%2 == 1 {
		bestI, bestJ = bestJ, bestI
	}
	return a.Rooms[bestI], a.Rooms[bestJ], true
}

// hashString هشِ ساده و قطعی (FNV-1a)
func hashString(s string) uint32 {
	var h uint32 = 2166136261
	for i := 0; i < len(s); i++ {
		h ^= uint32(s[i])
		h *= 16777619
	}
	return h
}

// TeamSpawn نقطه‌ی شروعِ یک بازیکن داخلِ اتاقِ تیمش.
//
// index شماره‌ی نفر در تیم است، تا هم‌تیمی‌ها روی هم نیفتند ولی نزدیکِ هم
// بمانند. اگر جای آزادی پیدا نشد به نقطه‌های شروعِ معمولی برمی‌گردد.
func (a *Arena) TeamSpawn(matchID string, team int, index, teamSize int, occupied [][2]float64) (float64, float64) {
	roomA, roomB, ok := a.teamRoomsFor(matchID)
	if !ok {
		return a.RandomSpawn(occupied)
	}
	room := roomA
	if team%2 == 1 {
		room = roomB
	}

	cx, cy := room.Center()
	// نفرها را روی یک دایره‌ی کوچک دورِ مرکزِ اتاق می‌چینیم: نزدیکِ هم،
	// ولی نه روی هم.
	if teamSize < 1 {
		teamSize = 1
	}
	radius := math.Min(room.W, room.H) * 0.25
	if radius < 60 {
		radius = 60
	}

	// چند حلقه امتحان می‌کنیم تا جای آزاد پیدا شود
	for _, r := range []float64{radius, radius * 0.6, radius * 1.4, 0} {
		for k := 0; k < teamSize*3; k++ {
			ang := 2 * math.Pi * float64(index*3+k) / float64(teamSize*3)
			x := cx + math.Cos(ang)*r
			y := cy + math.Sin(ang)*r
			if a.spawnUsable(x, y, occupied) {
				return x, y
			}
		}
	}
	// اتاق جا نداشت — هر جای آزادی داخلِ همان اتاق
	for i := 0; i < 200; i++ {
		x := room.X + rand.Float64()*room.W
		y := room.Y + rand.Float64()*room.H
		if a.spawnUsable(x, y, occupied) {
			return x, y
		}
	}
	return a.RandomSpawn(occupied)
}

// spawnUsable آیا این نقطه برای ظاهر شدن مناسب است؟
func (a *Arena) spawnUsable(x, y float64, occupied [][2]float64) bool {
	if a.CircleBlocked(x, y, playerRadius+6) {
		return false
	}
	// روی سرِ کسی ظاهر نشو
	for _, o := range occupied {
		if math.Hypot(x-o[0], y-o[1]) < 70 {
			return false
		}
	}
	return true
}
