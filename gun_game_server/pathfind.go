package main

import (
	"container/heap"
	"math"
)

// مسیریابی روی همان گریدِ برخوردِ زمین.
//
// چون گرید همان منبعی است که دیوارها (و هر مانعی که بعداً به نقشه اضافه شود)
// در آن نوشته می‌شوند، بات‌ها خودبه‌خود هر مانعِ تازه‌ای را دور می‌زنند —
// لازم نیست کسی به کدِ بات دست بزند. کافی است مانع در arena_map.json باشد.
//
// دو مرحله دارد:
//   ۱. گریدِ «جای باز برای یک دایره» یک بار موقع بالا آمدن ساخته می‌شود
//      (clearance). هر خانه می‌گوید آیا بازیکنی به شعاعِ استاندارد آن‌جا
//      جا می‌شود یا نه. بدون این، مسیر از کنارِ دیوار رد می‌شد و بات
//      مدام به گوشه‌ها گیر می‌کرد.
//   ۲. A* روی همان گرید، بعد صاف کردنِ مسیر با خطِ دید — وگرنه بات
//      پله‌پله و مورب‌شکسته راه می‌رود و مصنوعی به‌نظر می‌رسد.

// botClearance شعاعی که مسیریابی برایش جا باز می‌کند. کمی از playerRadius
// بزرگ‌تر است تا بات چسبیده به دیوار راه نرود.
const botClearance = playerRadius + 4.0

// PathPoint یک نقطه‌ی مسیر در مختصاتِ جهانی
type PathPoint struct {
	X, Y float64
}

// buildClearance گریدِ «اینجا برای یک دایره جا هست؟» را می‌سازد.
//
// یک بار موقع LoadArena اجرا می‌شود. برای گریدِ ۲۵۰×۱۴۰ چند میلی‌ثانیه طول
// می‌کشد و بعد هر مسیریابی فقط یک آرایه‌خوانی است.
func (a *Arena) buildClearance() {
	a.free = make([]bool, a.cols*a.rows)
	for cy := 0; cy < a.rows; cy++ {
		for cx := 0; cx < a.cols; cx++ {
			// مرکزِ خانه را می‌سنجیم، همان نقطه‌ای که مسیر از آن رد می‌شود
			x := (float64(cx) + 0.5) * a.cell
			y := (float64(cy) + 0.5) * a.cell
			a.free[cy*a.cols+cx] = !a.CircleBlocked(x, y, botClearance)
		}
	}
}

// cellFree آیا این خانه برای یک بازیکن جا دارد؟ بیرونِ گرید همیشه بسته.
func (a *Arena) cellFree(cx, cy int) bool {
	if cx < 0 || cy < 0 || cx >= a.cols || cy >= a.rows {
		return false
	}
	if a.free == nil {
		return !a.cellBlocked(cx, cy)
	}
	return a.free[cy*a.cols+cx]
}

// nearestFreeCell نزدیک‌ترین خانه‌ی باز به یک نقطه.
//
// لازم است چون مبدأ یا مقصد ممکن است داخلِ حاشیه‌ی دیوار بیفتد (مثلاً
// بازیکنی که چسبیده به دیوار ایستاده). بدون این، A* بلافاصله شکست می‌خورد
// و بات بی‌حرکت می‌ماند.
func (a *Arena) nearestFreeCell(x, y float64) (int, int, bool) {
	cx := int(math.Floor(x / a.cell))
	cy := int(math.Floor(y / a.cell))
	if a.cellFree(cx, cy) {
		return cx, cy, true
	}
	for ring := 1; ring <= 14; ring++ {
		for dy := -ring; dy <= ring; dy++ {
			for dx := -ring; dx <= ring; dx++ {
				// فقط حلقه‌ی بیرونی، نه داخلش که قبلاً دیده شده
				if dx*dx != ring*ring && dy*dy != ring*ring {
					continue
				}
				if a.cellFree(cx+dx, cy+dy) {
					return cx + dx, cy + dy, true
				}
			}
		}
	}
	return cx, cy, false
}

// --- صفِ اولویت برای A* ---

type pfNode struct {
	idx   int
	f     float64
	index int // جای خودش در heap
}

type pfQueue []*pfNode

func (q pfQueue) Len() int            { return len(q) }
func (q pfQueue) Less(i, j int) bool  { return q[i].f < q[j].f }
func (q pfQueue) Swap(i, j int)       { q[i], q[j] = q[j], q[i]; q[i].index = i; q[j].index = j }
func (q *pfQueue) Push(x interface{}) { n := x.(*pfNode); n.index = len(*q); *q = append(*q, n) }
func (q *pfQueue) Pop() interface{} {
	old := *q
	n := len(old)
	it := old[n-1]
	*q = old[:n-1]
	return it
}

// هشت جهت. قطری‌ها هزینه‌ی √۲ دارند تا مسیر واقعاً کوتاه‌ترین باشد.
var pfDirs = [8][2]int{
	{1, 0}, {-1, 0}, {0, 1}, {0, -1},
	{1, 1}, {1, -1}, {-1, 1}, {-1, -1},
}

const sqrt2 = 1.41421356237

// pfMaxExpand سقفِ خانه‌هایی که A* باز می‌کند. کمی بیشتر از کلِ خانه‌های
// گرید (۲۵۰×۱۴۰ = ۳۵۰۰۰) گرفته شده تا فقط جلوی حلقه‌ی بی‌پایان را بگیرد و
// نه مسیرهای دور را. اگر مقصد واقعاً غیرقابل
// دسترس باشد، بدون این سقف کلِ گرید پیمایش می‌شد و تیکِ سرور کند می‌شد.
const pfMaxExpand = 40000

// FindPath کوتاه‌ترین مسیرِ قابل عبور بین دو نقطه‌ی جهانی.
//
// نتیجه از نقطه‌ی بعد از مبدأ شروع می‌شود و به مقصد ختم می‌شود. اگر راهی
// نباشد nil برمی‌گرداند — صداکننده باید همان‌جا تصمیمِ دیگری بگیرد.
func (a *Arena) FindPath(sx, sy, tx, ty float64) []PathPoint {
	if a == nil {
		return nil
	}
	// اگر خطِ مستقیم باز است، اصلاً A* لازم نیست. بیشترِ درگیری‌ها در یک
	// اتاق اتفاق می‌افتند، پس این حالتِ رایج است و باید ارزان بماند.
	if a.walkableLine(sx, sy, tx, ty) {
		return []PathPoint{{tx, ty}}
	}

	scx, scy, okS := a.nearestFreeCell(sx, sy)
	tcx, tcy, okT := a.nearestFreeCell(tx, ty)
	if !okS || !okT {
		return nil
	}
	start := scy*a.cols + scx
	goal := tcy*a.cols + tcx
	if start == goal {
		return []PathPoint{{tx, ty}}
	}

	n := a.cols * a.rows
	gScore := make(map[int]float64, 512)
	cameFrom := make(map[int]int, 512)
	open := &pfQueue{}
	heap.Init(open)

	hEst := func(idx int) float64 {
		cx, cy := idx%a.cols, idx/a.cols
		dx := math.Abs(float64(cx - tcx))
		dy := math.Abs(float64(cy - tcy))
		// فاصله‌ی اکتایل — با هزینه‌ی حرکت هم‌خوان است، پس A* بهینه می‌ماند
		if dx > dy {
			return dx + (sqrt2-1)*dy
		}
		return dy + (sqrt2-1)*dx
	}

	gScore[start] = 0
	heap.Push(open, &pfNode{idx: start, f: hEst(start)})
	closed := make([]bool, n)
	expanded := 0

	for open.Len() > 0 {
		cur := heap.Pop(open).(*pfNode)
		if closed[cur.idx] {
			continue
		}
		closed[cur.idx] = true
		if cur.idx == goal {
			return a.reconstruct(cameFrom, goal, sx, sy, tx, ty)
		}
		expanded++
		if expanded > pfMaxExpand {
			return nil
		}

		cx, cy := cur.idx%a.cols, cur.idx/a.cols
		for _, d := range pfDirs {
			nx, ny := cx+d[0], cy+d[1]
			if !a.cellFree(nx, ny) {
				continue
			}
			// از گوشه‌ی دیوار رد نشو: حرکتِ قطری فقط وقتی مجاز است که هر دو
			// خانه‌ی مجاورش هم باز باشند، وگرنه بات از لای دو دیوار می‌برد
			if d[0] != 0 && d[1] != 0 {
				if !a.cellFree(cx+d[0], cy) || !a.cellFree(cx, cy+d[1]) {
					continue
				}
			}
			nIdx := ny*a.cols + nx
			if closed[nIdx] {
				continue
			}
			step := 1.0
			if d[0] != 0 && d[1] != 0 {
				step = sqrt2
			}
			ng := gScore[cur.idx] + step
			if old, ok := gScore[nIdx]; ok && ng >= old {
				continue
			}
			gScore[nIdx] = ng
			cameFrom[nIdx] = cur.idx
			heap.Push(open, &pfNode{idx: nIdx, f: ng + hEst(nIdx)})
		}
	}
	return nil
}

// reconstruct مسیرِ خانه‌ای را به نقاطِ جهانی تبدیل و صاف می‌کند
func (a *Arena) reconstruct(cameFrom map[int]int, goal int, sx, sy, tx, ty float64) []PathPoint {
	cells := []int{goal}
	for cur := goal; ; {
		prev, ok := cameFrom[cur]
		if !ok {
			break
		}
		cells = append(cells, prev)
		cur = prev
	}
	// برعکس: از مبدأ به مقصد
	for i, j := 0, len(cells)-1; i < j; i, j = i+1, j-1 {
		cells[i], cells[j] = cells[j], cells[i]
	}

	pts := make([]PathPoint, 0, len(cells))
	for _, idx := range cells {
		cx, cy := idx%a.cols, idx/a.cols
		pts = append(pts, PathPoint{
			X: (float64(cx) + 0.5) * a.cell,
			Y: (float64(cy) + 0.5) * a.cell,
		})
	}
	// آخرین نقطه دقیقاً همان مقصدِ خواسته‌شده باشد، نه مرکزِ خانه‌اش
	if len(pts) > 0 {
		pts[len(pts)-1] = PathPoint{tx, ty}
	}
	return a.smooth(sx, sy, pts)
}

// smooth «کشیدنِ نخ»: هر نقطه‌ای که بشود از آن پرید حذف می‌شود.
//
// بدون این، مسیرِ A* پله‌پله است و بات به‌جای یک خطِ مورب، زیگزاگ می‌رود —
// از دور کاملاً مشخص است که آدم نیست.
func (a *Arena) smooth(sx, sy float64, pts []PathPoint) []PathPoint {
	if len(pts) <= 1 {
		return pts
	}
	out := make([]PathPoint, 0, len(pts))
	curX, curY := sx, sy
	i := 0
	for i < len(pts) {
		// دورترین نقطه‌ای که از جای فعلی مستقیم دیده می‌شود
		best := i
		for j := len(pts) - 1; j > i; j-- {
			if a.walkableLine(curX, curY, pts[j].X, pts[j].Y) {
				best = j
				break
			}
		}
		out = append(out, pts[best])
		curX, curY = pts[best].X, pts[best].Y
		if best == len(pts)-1 {
			break
		}
		i = best + 1
	}
	return out
}

// walkableLine آیا یک دایره به شعاعِ بات می‌تواند این خط را طی کند؟
//
// با HasLineOfSight فرق دارد: آن برای گلوله است و گلوله عرض ندارد، این
// برای بدنِ بات است و باید از کنارِ دیوار هم فاصله بگیرد.
func (a *Arena) walkableLine(x1, y1, x2, y2 float64) bool {
	dist := math.Hypot(x2-x1, y2-y1)
	if dist == 0 {
		return true
	}
	step := a.cell * 0.5
	steps := int(dist/step) + 1
	ux, uy := (x2-x1)/dist, (y2-y1)/dist
	for i := 0; i <= steps; i++ {
		t := math.Min(float64(i)*step, dist)
		if a.CircleBlocked(x1+ux*t, y1+uy*t, botClearance) {
			return false
		}
	}
	return true
}
