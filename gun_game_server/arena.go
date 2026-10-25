package main

import (
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math"
	"math/rand"
)

// نقشه‌ها توسط tools/build_arena.py ساخته می‌شوند. همان فایل‌ها در resources/
// برای گودوت هم نوشته می‌شوند، پس کلاینت و سرور دقیقاً یک نقشه دارند. اینجا
// داخل باینری embed می‌شوند تا سرور به فایلِ کنار خودش وابسته نباشد.
//
// arena_map.json     زمینِ پیش‌فرض — همه‌ی حالت‌های تیمی
// arena_revenge.json زمینِ «عملیات انتقام» — بازتر، با ستون‌های پناه‌گیری
// arena_banish.json  زمینِ «عملیات حذف شیطان» — راهروهایی که به میدانِ
//
//	وسط (جای شیطان) می‌رسند، بدونِ اتاقِ بسته
//
//go:embed arena_map.json
var arenaJSON []byte

//go:embed arena_revenge.json
var arenaRevengeJSON []byte

//go:embed arena_banish.json
var arenaBanishJSON []byte

// DefaultMapName نقشه‌ای که هر حالتِ بدونِ زمینِ اختصاصی روی آن بازی می‌شود
const DefaultMapName = "map"

// mapForMode کدام حالت روی کدام نقشه بازی می‌کند.
//
// عمداً نگاشتِ صریح است و نه «هر حالت یک نقشه»: ساختنِ زمین کار دارد و تا
// وقتی زمینِ اختصاصی نساخته‌ایم، حالتِ تازه باید روی زمینِ پیش‌فرض بیفتد،
// نه اینکه سرور بالا نیاید.
var mapForMode = map[string]string{
	"revenge": "revenge",
	"banish":  "banish",
}

// ثابت‌های برخورد (Collision Constants)
const (
	// شعاع برخورد بازیکن روی سرور. کلاینت 29.3 است (CircleShape2D 58.55 × scale 0.5).
	// سرور کمی سخاوتمندتر گرفته شده تا حرکتِ درستِ کلاینت بی‌خود رد نشود.
	playerRadius = 25.0

	// بیشترین سرعتی که سرور قبول می‌کند (واحد بر ثانیه). کلاینت SPEED=200 است؛
	// حاشیه برای لگ و پرش‌های شبکه.
	maxMoveSpeed = 340.0

	// خطای مجاز بین موقعیت درخواستی و موقعیت اصلاح‌شده، قبل از اینکه تصحیح بفرستیم.
	correctionEpsilon = 6.0
)

type arenaFile struct {
	Version int `json:"version"`
	World   struct {
		Width  float64 `json:"width"`
		Height float64 `json:"height"`
	} `json:"world"`
	Grid struct {
		Cell int    `json:"cell"`
		Cols int    `json:"cols"`
		Rows int    `json:"rows"`
		Bits string `json:"bits"`
	} `json:"grid"`
	Spawns [][]float64 `json:"spawns"`
	// اتاق‌ها فقط برای نقطه‌ی شروعِ تیمی لازم‌اند (team_spawn.go) — هر تیم
	// داخلِ یک اتاق ظاهر می‌شود، نه پخش در کلِ نقشه.
	Rooms [][]float64 `json:"rooms"`
}

// Arena نقشه‌ی برخورد زمین بازی — مرجعِ نهایی و تنها مرجع معتبر.
// کلاینت فقط برای پیش‌بینی محلی کپی دارد؛ هر چیزی که اینجا رد شود، رد است.
type Arena struct {
	// Name کلیدِ نقشه ("map" یا "revenge"). کلاینت با همین می‌فهمد کدام
	// فایل را بکشد، پس هیچ‌وقت زمینی غیر از زمینِ سرور نشان نمی‌دهد.
	Name  string
	W, H  float64
	cell  float64
	cols  int
	rows  int
	cells []bool // row-major, len = cols*rows
	// free گریدِ «اینجا برای یک بازیکن جا هست؟» — یک بار در LoadArena ساخته
	// می‌شود و مسیریابیِ بات‌ها (pathfind.go) روی همین کار می‌کند.
	free   []bool
	Spawns [][2]float64
	Rooms  []Room
}

// arena زمینِ پیش‌فرض. کدهایی که هنوز بازیکنِ مشخصی در دست ندارند
// (تست‌ها، تمرینِ بی‌مسابقه) از همین استفاده می‌کنند.
var arena *Arena

// arenas همه‌ی زمین‌های بارگذاری‌شده: نامِ نقشه -> زمین
var arenas = map[string]*Arena{}

// LoadArena همه‌ی نقشه‌های embed شده را باز می‌کند. اگر هرکدام خراب باشد سرور
// نباید بالا بیاید، چون بدون نقشه هیچ اعتبارسنجی‌ای در کار نیست و بازی قابل
// تقلب می‌شود.
func LoadArena() error {
	for name, raw := range map[string][]byte{
		DefaultMapName: arenaJSON,
		"revenge":      arenaRevengeJSON,
		"banish":       arenaBanishJSON,
	} {
		a, err := parseArena(name, raw)
		if err != nil {
			return err
		}
		arenas[name] = a
	}
	arena = arenas[DefaultMapName]
	return nil
}

// ArenaForMode زمینِ یک حالتِ بازی. حالتِ ناشناخته روی زمینِ پیش‌فرض می‌افتد.
func ArenaForMode(modeID string) *Arena {
	if a, ok := arenas[mapForMode[modeID]]; ok && a != nil {
		return a
	}
	return arena
}

// MapNameForMode نامِ نقشه‌ی یک حالت — همان چیزی که برای کلاینت فرستاده می‌شود
func MapNameForMode(modeID string) string {
	if name, ok := mapForMode[modeID]; ok {
		if _, loaded := arenas[name]; loaded {
			return name
		}
	}
	return DefaultMapName
}

// arenaOf زمینِ همان مسابقه‌ای که این بازیکن در آن است.
//
// زمین لحظه‌ی join روی خودِ بازیکن می‌نشیند و نه از روی جدولِ ماچ‌میکینگ
// خوانده می‌شود: مسابقه بعد از پایانِ راند آزاد می‌شود، ولی بازیکن ممکن است
// هنوز چند ثانیه توی همان زمین بماند — با خواندن از جدول، همان لحظه زمینش
// عوض می‌شد و سرور شروع می‌کرد به «اصلاح» کردنِ موقعیتش به سمتِ نقشه‌ی دیگر.
func arenaOf(p *Player) *Arena {
	if p != nil && p.Arena != nil {
		return p.Arena
	}
	return arena
}

// parseArena یک فایلِ نقشه را به Arena تبدیل می‌کند
func parseArena(name string, raw []byte) (*Arena, error) {
	var f arenaFile
	if err := json.Unmarshal(raw, &f); err != nil {
		return nil, fmt.Errorf("arena %s parse: %w", name, err)
	}
	bits, err := base64.StdEncoding.DecodeString(f.Grid.Bits)
	if err != nil {
		return nil, fmt.Errorf("arena %s grid base64: %w", name, err)
	}
	n := f.Grid.Cols * f.Grid.Rows
	if n <= 0 || len(bits)*8 < n {
		return nil, fmt.Errorf("arena %s grid too small: %d cells, %d bytes", name, n, len(bits))
	}
	cells := make([]bool, n)
	for i := 0; i < n; i++ {
		cells[i] = bits[i/8]&(1<<uint(i%8)) != 0 // packbits little: کم‌ارزش‌ترین بیت اول
	}
	a := &Arena{
		Name: name,
		W:    f.World.Width, H: f.World.Height,
		cell: float64(f.Grid.Cell), cols: f.Grid.Cols, rows: f.Grid.Rows,
		cells: cells,
	}
	for _, s := range f.Spawns {
		if len(s) == 2 {
			a.Spawns = append(a.Spawns, [2]float64{s[0], s[1]})
		}
	}
	for _, r := range f.Rooms {
		if len(r) == 4 {
			a.Rooms = append(a.Rooms, Room{X: r[0], Y: r[1], W: r[2], H: r[3]})
		}
	}
	a.buildClearance()
	blocked := 0
	for _, c := range cells {
		if c {
			blocked++
		}
	}
	fmt.Printf("🗺️  Arena %q loaded: %.0fx%.0f, grid %dx%d (cell %d), %.1f%% blocked, %d spawns, %d rooms\n",
		name, a.W, a.H, a.cols, a.rows, f.Grid.Cell,
		100*float64(blocked)/float64(n), len(a.Spawns), len(a.Rooms))
	return a, nil
}

// cellBlocked آیا خانه‌ی گرید بسته است؟ بیرون نقشه همیشه بسته حساب می‌شود.
func (a *Arena) cellBlocked(cx, cy int) bool {
	if cx < 0 || cy < 0 || cx >= a.cols || cy >= a.rows {
		return true
	}
	return a.cells[cy*a.cols+cx]
}

// PointBlocked آیا این نقطه داخل دیوار / بیرون زمین است؟
func (a *Arena) PointBlocked(x, y float64) bool {
	return a.cellBlocked(int(math.Floor(x/a.cell)), int(math.Floor(y/a.cell)))
}

// CircleBlocked آیا دایره‌ای به این شعاع اینجا جا می‌شود؟
func (a *Arena) CircleBlocked(x, y, r float64) bool {
	minX := int(math.Floor((x - r) / a.cell))
	maxX := int(math.Floor((x + r) / a.cell))
	minY := int(math.Floor((y - r) / a.cell))
	maxY := int(math.Floor((y + r) / a.cell))
	for cy := minY; cy <= maxY; cy++ {
		for cx := minX; cx <= maxX; cx++ {
			if !a.cellBlocked(cx, cy) {
				continue
			}
			// نزدیک‌ترین نقطه‌ی خانه به مرکز دایره
			nx := clampF(x, float64(cx)*a.cell, float64(cx+1)*a.cell)
			ny := clampF(y, float64(cy)*a.cell, float64(cy+1)*a.cell)
			dx, dy := x-nx, y-ny
			if dx*dx+dy*dy < r*r {
				return true
			}
		}
	}
	return false
}

// ResolveMove موقعیت جدیدِ مجاز را برمی‌گرداند.
// اول سرعت را سقف می‌زند، بعد اگر مقصد داخل دیوار بود روی محورها می‌لغزاند
// (همان کاری که move_and_slide در گودوت می‌کند) تا حرکت کنار دیوار طبیعی بماند.
func (a *Arena) ResolveMove(oldX, oldY, newX, newY, r, dt float64) (float64, float64) {
	maxD := -1.0
	if dt > 0 {
		maxD = maxMoveSpeed * dt
	}
	return a.ResolveMoveMax(oldX, oldY, newX, newY, r, maxD)
}

// ResolveMoveMax مثل ResolveMove ولی سقفِ جابه‌جایی را مستقیم می‌گیرد
// (منفی یعنی بی‌سقف). حرکت به گام‌هایی کوچک‌تر از نصفِ شعاع خرد می‌شود و
// هر گام جدا برخورد/لغزش می‌خورد: قبلاً فقط مقصد چک می‌شد و یک پرشِ بزرگ
// (بعد از یک ثانیه وقفه) می‌توانست از دیوارِ نازک رد شود.
func (a *Arena) ResolveMoveMax(oldX, oldY, newX, newY, r, maxD float64) (float64, float64) {
	dx, dy := newX-oldX, newY-oldY
	d := math.Hypot(dx, dy)
	if maxD >= 0 && d > maxD {
		if d > 0 {
			newX, newY = oldX+dx/d*maxD, oldY+dy/d*maxD
		}
		dx, dy, d = newX-oldX, newY-oldY, maxD
	}
	step := r * 0.5
	if step <= 0 || d <= step {
		return a.resolveStep(oldX, oldY, newX, newY, r)
	}
	// هر گام نسبت به جای فعلی است، نه نقطه‌ای روی خطِ اصلی — وگرنه
	// بازیکنِ گیرکرده پشتِ دیوار در گامِ بعدی یک‌جا آن طرفِ دیوار می‌پرید.
	n := int(math.Ceil(d / step))
	sx, sy := dx/float64(n), dy/float64(n)
	x, y := oldX, oldY
	for i := 0; i < n; i++ {
		x, y = a.resolveStep(x, y, x+sx, y+sy, r)
	}
	return x, y
}

// resolveStep یک گامِ کوتاه: اگر مقصد در دیوار بود روی محورها می‌لغزد.
func (a *Arena) resolveStep(oldX, oldY, newX, newY, r float64) (float64, float64) {
	newX = clampF(newX, r, a.W-r)
	newY = clampF(newY, r, a.H-r)

	if !a.CircleBlocked(newX, newY, r) {
		return newX, newY
	}
	// لغزش روی محور X، بعد روی محور Y
	if !a.CircleBlocked(newX, oldY, r) {
		return newX, oldY
	}
	if !a.CircleBlocked(oldX, newY, r) {
		return oldX, newY
	}
	// هیچ‌کدام نشد: سر جایش بماند. اگر خودِ جای قبلی هم بسته باشد
	// (مثلاً بعد از تغییر نقشه)، به نزدیک‌ترین جای آزاد پرتش کن.
	if a.CircleBlocked(oldX, oldY, r) {
		if fx, fy, ok := a.NearestFree(oldX, oldY, r); ok {
			return fx, fy
		}
	}
	return oldX, oldY
}

// NearestFree نزدیک‌ترین نقطه‌ی آزاد را با جست‌وجوی حلقه‌ای پیدا می‌کند.
func (a *Arena) NearestFree(x, y, r float64) (float64, float64, bool) {
	for ring := 1; ring <= 40; ring++ {
		step := float64(ring) * a.cell
		for i := 0; i < 16; i++ {
			ang := float64(i) * math.Pi / 8
			cx := clampF(x+math.Cos(ang)*step, r, a.W-r)
			cy := clampF(y+math.Sin(ang)*step, r, a.H-r)
			if !a.CircleBlocked(cx, cy, r) {
				return cx, cy, true
			}
		}
	}
	return x, y, false
}

// HasLineOfSight آیا خط مستقیم بین دو نقطه از دیوار رد نمی‌شود؟
// پیمایش DDA روی گرید — دقیق و بدون حلقه روی همه‌ی موانع.
// این همان چیزی است که جلوی «شلیک از پشت دیوار» را می‌گیرد.
func (a *Arena) HasLineOfSight(x1, y1, x2, y2 float64) bool {
	cx, cy := int(math.Floor(x1/a.cell)), int(math.Floor(y1/a.cell))
	ex, ey := int(math.Floor(x2/a.cell)), int(math.Floor(y2/a.cell))
	dx, dy := x2-x1, y2-y1

	stepX, stepY := 1, 1
	if dx < 0 {
		stepX = -1
	}
	if dy < 0 {
		stepY = -1
	}
	// فاصله‌ی پارامتری تا اولین مرز خانه و بین مرزها
	var tMaxX, tMaxY, tDeltaX, tDeltaY float64
	if dx == 0 {
		tMaxX, tDeltaX = math.Inf(1), math.Inf(1)
	} else {
		bx := float64(cx) * a.cell
		if stepX > 0 {
			bx += a.cell
		}
		tMaxX = (bx - x1) / dx
		tDeltaX = a.cell / math.Abs(dx)
	}
	if dy == 0 {
		tMaxY, tDeltaY = math.Inf(1), math.Inf(1)
	} else {
		by := float64(cy) * a.cell
		if stepY > 0 {
			by += a.cell
		}
		tMaxY = (by - y1) / dy
		tDeltaY = a.cell / math.Abs(dy)
	}

	// سقف تکرار: قطر گرید، تا در هیچ حالتی حلقه بی‌نهایت نشود
	maxSteps := a.cols + a.rows + 4
	for i := 0; i < maxSteps; i++ {
		if cx == ex && cy == ey {
			return true
		}
		if tMaxX < tMaxY {
			if tMaxX > 1 {
				return true // به مقصد رسیدیم
			}
			tMaxX += tDeltaX
			cx += stepX
		} else {
			if tMaxY > 1 {
				return true
			}
			tMaxY += tDeltaY
			cy += stepY
		}
		if a.cellBlocked(cx, cy) {
			return false
		}
	}
	return true
}

// RayHitPoint خط را جلو می‌برد تا به دیوار بخورد و آخرین نقطه‌ی آزاد را برمی‌گرداند.
// برای پرتاب بمب: بمب نباید از دیوار رد شود.
func (a *Arena) RayHitPoint(x1, y1, x2, y2 float64) (float64, float64) {
	dist := math.Hypot(x2-x1, y2-y1)
	if dist == 0 {
		return x1, y1
	}
	stepLen := a.cell * 0.5
	steps := int(dist/stepLen) + 1
	ux, uy := (x2-x1)/dist, (y2-y1)/dist
	lastX, lastY := x1, y1
	for i := 1; i <= steps; i++ {
		t := math.Min(float64(i)*stepLen, dist)
		px, py := x1+ux*t, y1+uy*t
		if a.PointBlocked(px, py) {
			return lastX, lastY
		}
		lastX, lastY = px, py
	}
	return x2, y2
}

// RandomSpawn نقطه‌ی شروعی برمی‌گرداند که از بازیکن‌های داده‌شده دورترین باشد.
func (a *Arena) RandomSpawn(occupied [][2]float64) (float64, float64) {
	if len(a.Spawns) == 0 {
		return a.W / 2, a.H / 2
	}
	best, bestDist := a.Spawns[0], -1.0
	for _, s := range a.Spawns {
		nearest := math.Inf(1)
		for _, o := range occupied {
			d := math.Hypot(s[0]-o[0], s[1]-o[1])
			if d < nearest {
				nearest = d
			}
		}
		if nearest > bestDist {
			best, bestDist = s, nearest
		}
	}
	return best[0], best[1]
}

// RespawnSafeDistance کمترین فاصله‌ای که یک تولدِ دوباره باید از حریفِ زنده
// داشته باشد. کمتر از این یعنی بازیکن جلوی لوله‌ی تفنگ ظاهر می‌شود.
const RespawnSafeDistance = 420.0

// RespawnSpawn نقطه‌ی تولدِ دوباره: نه جلوی حریف، نه آن سرِ نقشه.
//
// چرا RandomSpawn به‌تنهایی کافی نیست: آن همیشه دورترین نقطه از حریف را
// می‌دهد. در «عملیات انتقام» که تک‌به‌تک است و فقط دو دقیقه وقت دارد، این
// یعنی هر مرگ یک تعقیبِ طولانی از این سرِ نقشه تا آن سر — بازی می‌ایستد.
// پس نزدیک‌ترین نقطه‌ای انتخاب می‌شود که هنوز امن است.
func (a *Arena) RespawnSpawn(foes [][2]float64) (float64, float64) {
	if len(a.Spawns) == 0 {
		return a.W / 2, a.H / 2
	}
	if len(foes) == 0 {
		s := a.Spawns[rand.Intn(len(a.Spawns))]
		return s[0], s[1]
	}

	best, bestGap := [2]float64{}, math.Inf(1)
	found := false
	for _, s := range a.Spawns {
		nearest := math.Inf(1)
		for _, f := range foes {
			if d := math.Hypot(s[0]-f[0], s[1]-f[1]); d < nearest {
				nearest = d
			}
		}
		if nearest < RespawnSafeDistance {
			continue // درست جلوی حریف
		}
		if nearest < bestGap {
			best, bestGap, found = s, nearest, true
		}
	}
	if found {
		return best[0], best[1]
	}
	// هیچ نقطه‌ای امن نبود (نقشه‌ی تنگ یا حریفِ همه‌جا) — دورترین را بگیر
	return a.RandomSpawn(foes)
}

func clampF(v, lo, hi float64) float64 {
	if hi < lo {
		return lo
	}
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
