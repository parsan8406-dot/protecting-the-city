package main

import (
	"math"
	"testing"
)

// مسیریابی روی نقشه‌ی واقعیِ embed‌شده تست می‌شود، نه یک نقشه‌ی ساختگی —
// چیزی که باید کار کند همین زمینِ اتاق‌بندی‌شده است.

func pathArena(t *testing.T) *Arena {
	t.Helper()
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	return arena
}

// هر مسیر باید واقعاً قابل پیمودن باشد: هیچ پاره‌خطی نباید از دیوار رد شود.
func assertWalkable(t *testing.T, a *Arena, sx, sy float64, path []PathPoint) {
	t.Helper()
	cx, cy := sx, sy
	for i, p := range path {
		if !a.walkableLine(cx, cy, p.X, p.Y) {
			t.Fatalf("leg %d (%.0f,%.0f)->(%.0f,%.0f) crosses a wall", i, cx, cy, p.X, p.Y)
		}
		cx, cy = p.X, p.Y
	}
}

func TestPathBetweenEverySpawnPair(t *testing.T) {
	a := pathArena(t)
	if len(a.Spawns) < 2 {
		t.Fatalf("need at least 2 spawns, got %d", len(a.Spawns))
	}
	for i, s := range a.Spawns {
		for j, g := range a.Spawns {
			if i == j {
				continue
			}
			path := a.FindPath(s[0], s[1], g[0], g[1])
			if path == nil {
				t.Fatalf("no path from spawn %d (%.0f,%.0f) to spawn %d (%.0f,%.0f) — "+
					"a bot spawning there could never reach its target", i, s[0], s[1], j, g[0], g[1])
			}
			assertWalkable(t, a, s[0], s[1], path)

			// آخرین نقطه باید همان مقصد باشد
			last := path[len(path)-1]
			if math.Hypot(last.X-g[0], last.Y-g[1]) > 1.0 {
				t.Fatalf("path %d->%d ends at (%.0f,%.0f), not the goal (%.0f,%.0f)",
					i, j, last.X, last.Y, g[0], g[1])
			}
		}
	}
}

// مسیر نباید بی‌هدف کلِ نقشه را بگردد.
//
// عمداً با «چند برابرِ خطِ مستقیم» سنجیده نمی‌شود: در نقشه‌ی اتاق‌بندی‌شده
// دو نقطه می‌توانند ۴۷۲ واحد از هم فاصله داشته باشند ولی دیوارِ بینشان
// اصلاً در نداشته باشد، و راهِ درست ۱۷۲۰ واحد دور زدن باشد. آن مسیرِ
// طولانی درست است، نه باگ. چیزی که واقعاً باید بگیریم پرسه زدن است، پس
// سقف را مطلق می‌گیریم: چند برابرِ قطرِ خودِ زمین.
func TestPathDoesNotWanderTheWholeMap(t *testing.T) {
	a := pathArena(t)
	diag := math.Hypot(a.W, a.H)
	worst, worstI, worstJ := 0.0, -1, -1
	for i, s := range a.Spawns {
		for j, g := range a.Spawns {
			if i == j {
				continue
			}
			path := a.FindPath(s[0], s[1], g[0], g[1])
			if path == nil {
				continue
			}
			total := 0.0
			cx, cy := s[0], s[1]
			for _, p := range path {
				total += math.Hypot(p.X-cx, p.Y-cy)
				cx, cy = p.X, p.Y
			}
			if total > worst {
				worst, worstI, worstJ = total, i, j
			}
			if total > diag*2.5 {
				t.Errorf("path %d->%d is %.0f long (map diagonal %.0f) — the bot is wandering",
					i, j, total, diag)
			}
		}
	}
	t.Logf("longest route %d->%d = %.0f (map diagonal %.0f)", worstI, worstJ, worst, diag)
}

// صاف‌سازی باید تعداد نقاط را کم کند: مسیرِ خامِ A* خانه‌به‌خانه است.
func TestPathIsSmoothed(t *testing.T) {
	a := pathArena(t)
	worst := 0
	for i, s := range a.Spawns {
		for j, g := range a.Spawns {
			if i == j {
				continue
			}
			if path := a.FindPath(s[0], s[1], g[0], g[1]); path != nil && len(path) > worst {
				worst = len(path)
			}
		}
	}
	// بدونِ صاف‌سازی، عبور از کلِ زمین ده‌ها نقطه می‌شد (گرید ۲۵۰×۱۴۰).
	if worst > 12 {
		t.Errorf("longest smoothed path has %d waypoints — smoothing is not working", worst)
	}
	t.Logf("longest smoothed path: %d waypoints", worst)
}

// نقطه‌ی چسبیده به دیوار نباید مسیریابی را بشکند — بات‌ها مدام کنارِ دیوار
// می‌ایستند و اگر این‌جا nil برگردد بات خشک می‌شود.
func TestPathFromPointHuggingAWall(t *testing.T) {
	a := pathArena(t)
	stuck := 0
	for _, g := range a.Spawns {
		for cy := 0; cy < a.rows; cy += 7 {
			for cx := 0; cx < a.cols; cx += 7 {
				x := (float64(cx) + 0.5) * a.cell
				y := (float64(cy) + 0.5) * a.cell
				// فقط نقاطی که خودشان داخلِ دیوار نیستند ولی حاشیه ندارند
				if a.PointBlocked(x, y) || a.cellFree(cx, cy) {
					continue
				}
				if a.FindPath(x, y, g[0], g[1]) == nil {
					stuck++
				}
			}
		}
	}
	if stuck > 0 {
		t.Errorf("%d wall-hugging positions produced no path", stuck)
	}
}
