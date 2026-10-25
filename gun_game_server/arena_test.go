package main

import (
	"math"
	"testing"
)

func mustArena(t *testing.T) *Arena {
	t.Helper()
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	return arena
}

// نقشه باید سالم بالا بیاید و اندازه‌هایش با تصویر بک‌گراند بخواند
func TestArenaLoads(t *testing.T) {
	a := mustArena(t)
	if a.W != 2000 || a.H != 1120 {
		t.Errorf("world size = %vx%v, want 2000x1120", a.W, a.H)
	}
	if a.cols != 250 || a.rows != 140 {
		t.Errorf("grid = %dx%d, want 250x140", a.cols, a.rows)
	}
	if len(a.Spawns) == 0 {
		t.Fatal("no spawn points")
	}
}

// زمین اتاق‌بندی شده است: باید دیوارِ داخلی داشته باشد، ولی نه آن‌قدر که
// جا برای بازی نماند. (تا قبل از اضافه شدنِ اتاق‌ها این تست عکسِ این را
// چک می‌کرد — زمین آن موقع کاملاً باز بود.)
func TestArenaHasInteriorWalls(t *testing.T) {
	a := mustArena(t)
	blocked := 0
	for _, c := range a.cells {
		if c {
			blocked++
		}
	}
	if blocked == 0 {
		t.Fatal("no interior walls — the room layout is missing from arena_map.json")
	}
	ratio := 100 * float64(blocked) / float64(len(a.cells))
	if ratio > 20 {
		t.Errorf("%.1f%% of the arena is wall — too little room to play", ratio)
	}
	t.Logf("interior walls cover %.1f%% of the grid", ratio)
}

// هیچ نقطه‌ی شروعی نباید بیرون یا چسبیده به مرز باشد
func TestSpawnsAreFree(t *testing.T) {
	a := mustArena(t)
	for i, s := range a.Spawns {
		if a.CircleBlocked(s[0], s[1], playerRadius) {
			t.Errorf("spawn %d (%.0f,%.0f) is blocked for radius %.0f", i, s[0], s[1], playerRadius)
		}
	}
}

// بیرون کادر زمین باید بسته باشد — همین مرز است که کاراکترها را نگه می‌دارد
func TestOutsideIsBlocked(t *testing.T) {
	a := mustArena(t)
	outside := [][2]float64{
		{-5, 600},       // چپِ زمین
		{a.W + 5, 600},  // راستِ زمین
		{1000, -5},      // بالای زمین
		{1000, a.H + 5}, // پایین زمین
		{-50, -50},      // گوشه‌ی بیرونی
		{a.W + 50, a.H + 50},
	}
	for _, p := range outside {
		if !a.PointBlocked(p[0], p[1]) {
			t.Errorf("point (%.0f,%.0f) is outside the world but reads as free", p[0], p[1])
		}
	}
}

// بیشترِ زمین باید قابل راه رفتن بماند. حالا که دیوار داریم، نقطه‌ی بسته
// طبیعی است — چیزی که نباید اتفاق بیفتد این است که زمین آن‌قدر پر از دیوار
// شود که بازی نشود کرد.
func TestMostOfTheArenaIsWalkable(t *testing.T) {
	a := mustArena(t)
	free, total := 0, 0
	for x := playerRadius; x <= a.W-playerRadius; x += 37 {
		for y := playerRadius; y <= a.H-playerRadius; y += 31 {
			total++
			if !a.CircleBlocked(x, y, playerRadius) {
				free++
			}
		}
	}
	if total == 0 {
		t.Fatal("no sample points")
	}
	ratio := float64(free) / float64(total)
	// ۷۵٪ بود؛ با ۴ تا ۵ مانع در هر اتاق (خواسته‌ی طراحی) زمینِ پیش‌فرض از
	// ~۸۲٪ به ~۷۱٪ رسید. کف ۶۸٪ است تا اگر روزی موانع یا دیوارها بی‌حساب
	// زیاد شدند، این تست باز هم بگیردش. اینکه موانع جیبِ بسته نسازند را
	// build_arena.py و TestPathFromPointHuggingAWall می‌سنجند.
	if ratio < 0.68 {
		t.Errorf("only %.0f%% of the arena is walkable — too cramped", ratio*100)
	}
	t.Logf("walkable: %.0f%% of sampled points", ratio*100)
}

// حرکت نباید بتواند از لبه‌ی زمین بیرون بزند
func TestResolveMoveKeepsPlayerInside(t *testing.T) {
	a := mustArena(t)
	start := a.Spawns[0]
	for _, target := range [][2]float64{
		{-500, -500}, {5000, 5000}, {0, 600}, {a.W, 600}, {1000, -800}, {1000, a.H + 800},
	} {
		x, y := a.ResolveMove(start[0], start[1], target[0], target[1], playerRadius, 10.0)
		if a.CircleBlocked(x, y, playerRadius) {
			t.Errorf("move to (%.0f,%.0f) resolved to blocked (%.1f,%.1f)", target[0], target[1], x, y)
		}
		if x < playerRadius || y < playerRadius || x > a.W-playerRadius || y > a.H-playerRadius {
			t.Errorf("resolved position (%.1f,%.1f) escaped the world %vx%v", x, y, a.W, a.H)
		}
	}
}

// سقف سرعت: یک پرش بزرگ در زمان کوتاه باید کوتاه شود
func TestSpeedCap(t *testing.T) {
	a := mustArena(t)
	s := a.Spawns[0]
	dt := 0.05 // ۵۰ میلی‌ثانیه => حداکثر ۱۷ واحد
	x, y := a.ResolveMove(s[0], s[1], s[0]+900, s[1], playerRadius, dt)
	moved := math.Hypot(x-s[0], y-s[1])
	if moved > maxMoveSpeed*dt+1 {
		t.Errorf("moved %.1f in %.2fs, cap is %.1f", moved, dt, maxMoveSpeed*dt)
	}
}

// خط دید در زمین باز همه‌جا برقرار است، ولی از بیرونِ زمین رد نمی‌شود
func TestLineOfSight(t *testing.T) {
	a := mustArena(t)
	if !a.HasLineOfSight(1000, 600, 1000, 600) {
		t.Error("LOS to self should be true")
	}
	// حالا که دیوار داریم، «همه‌جا دید باز است» دیگر درست نیست. چیزی که
	// باید همیشه درست بماند تقارنِ دید است: اگر A حریفش را می‌بیند، حریف هم
	// باید او را ببیند — وگرنه یکی می‌تواند از پشتِ دیوار بزند.
	blockedPairs := 0
	for _, p := range [][4]float64{
		{300, 200, 1700, 200},
		{1000, 100, 1000, 1000},
		{200, 900, 1800, 200},
		{50, 50, a.W - 50, a.H - 50},
		{100, 100, 400, 300},
	} {
		if a.HasLineOfSight(p[0], p[1], p[2], p[3]) != a.HasLineOfSight(p[2], p[3], p[0], p[1]) {
			t.Errorf("LOS not symmetric for (%.0f,%.0f)-(%.0f,%.0f)", p[0], p[1], p[2], p[3])
		}
		if !a.HasLineOfSight(p[0], p[1], p[2], p[3]) {
			blockedPairs++
		}
	}
	// دستِ‌کم یکی از این خط‌های بلندِ سرتاسری باید به دیوار بخورد، وگرنه
	// دیوارها اصلاً جلوی تیر را نمی‌گیرند
	if blockedPairs == 0 {
		t.Error("no long sight-line is blocked — walls are not stopping bullets")
	}
	// هدفی بیرون زمین دیده نمی‌شود
	if a.HasLineOfSight(1000, 600, -200, -200) {
		t.Error("LOS to a point outside the world should be blocked")
	}
}

// بمب باید در زمین باز کامل برود و روی مرز بایستد
func TestRayHitPointStopsAtBorder(t *testing.T) {
	a := mustArena(t)
	// پرتاب به سمت بیرون: باید داخل زمین بماند
	x, y := a.RayHitPoint(1000, 600, -300, 600)
	if a.PointBlocked(x, y) {
		t.Errorf("bomb landed outside the world at (%.1f,%.1f)", x, y)
	}
	if x < 0 {
		t.Errorf("bomb crossed the left border, landed at x=%.1f", x)
	}
	// در فضای باز باید کامل برود. مقصد از روی نقشه انتخاب می‌شود تا با
	// اضافه شدنِ دیوار این تست به‌هم نریزد: یک پرتابِ کوتاه از یک نقطه‌ی
	// شروع، در جهتی که خطِ دید باز است.
	s := a.Spawns[0]
	for _, d := range [][2]float64{{120, 0}, {-120, 0}, {0, 120}, {0, -120}} {
		tx, ty := s[0]+d[0], s[1]+d[1]
		if !a.HasLineOfSight(s[0], s[1], tx, ty) {
			continue
		}
		x2, y2 := a.RayHitPoint(s[0], s[1], tx, ty)
		if math.Hypot(x2-tx, y2-ty) > 9 {
			t.Errorf("bomb with clear line of sight stopped early: wanted (%.0f,%.0f), got (%.1f,%.1f)",
				tx, ty, x2, y2)
		}
	}
}

// اگر بازیکن یک‌جوری بیرون زمین افتاد، باید به داخل کشیده شود
func TestNearestFreeEscapesOutside(t *testing.T) {
	a := mustArena(t)
	x, y, ok := a.NearestFree(-60, -60, playerRadius)
	if !ok {
		t.Fatal("NearestFree found nothing")
	}
	if a.CircleBlocked(x, y, playerRadius) {
		t.Errorf("NearestFree returned blocked point (%.1f,%.1f)", x, y)
	}
}
