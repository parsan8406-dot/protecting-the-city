package main

import (
	"math"
	"math/rand"
	"testing"
	"time"
)

// -----------------------------------------------------------------------------
// این فایل تضمین می‌کند هیچ عددِ گیم‌پلی صرفاً روی حرفِ کلاینت تکیه نمی‌کند.
// هر ویژگی‌ای که روی «چقدر خسارت می‌خورد» یا «چند بار در ثانیه شلیک می‌شود»
// اثر دارد باید سمتِ سرور دوباره حساب/محدود شود — یک کلاینتِ دستکاری‌شده
// نباید بتواند با فرستادنِ عددهای دلخواه از این محدودیت‌ها رد شود.
// -----------------------------------------------------------------------------

// clampRotation نباید هیچ‌وقت بیشتر از maxDelta در یک قدم بچرخاند، حتی اگر
// کلاینت زاویه‌ی خیلی دورتری را ادعا کند (شبیه‌سازیِ کلاینتِ تقلبی).
func TestClampRotationNeverExceedsMaxDelta(t *testing.T) {
	rng := rand.New(rand.NewSource(1))
	for i := 0; i < 500; i++ {
		current := (rng.Float64()*2 - 1) * math.Pi
		claimed := (rng.Float64()*2 - 1) * math.Pi // کلاینتِ تقلبی هر چیزی ادعا می‌کند
		maxDelta := rng.Float64() * math.Pi / 4    // حداکثر تا ۴۵ درجه در این قدم

		got := clampRotation(current, claimed, maxDelta)
		moved := math.Abs(angleDiff(current, got))
		if moved > maxDelta+1e-9 {
			t.Fatalf("clampRotation moved %.4f rad, cap was %.4f (current=%.2f claimed=%.2f)",
				moved, maxDelta, current, claimed)
		}
	}
}

// اگر فاصله‌ی کوتاه‌تر از maxDelta باشد، باید دقیقاً به همان زاویه برسد —
// نه کندتر (تجربه‌ی بازیکنِ درست نباید خراب شود).
func TestClampRotationReachesCloseTargetsExactly(t *testing.T) {
	got := clampRotation(0, degToRad(5), degToRad(30))
	if !isCloseAngle(got, degToRad(5)) {
		t.Errorf("expected exact arrival at 5deg, got %.2f deg", radToDegT(got))
	}
}

// دور زدنِ نزدیکِ مرزِ ±۱۸۰ نباید گیر کند یا جهتِ اشتباه برود.
func TestClampRotationHandlesWrapBoundary(t *testing.T) {
	// از ۱۷۵ درجه به -۱۰۰ درجه، کوتاه‌ترین مسیر ۸۵ درجه (از مرز رد می‌شود)
	got := clampRotation(degToRad(175), degToRad(-100), degToRad(30))
	expect := degToRad(175 + 30)
	if !isCloseAngle(got, expect) {
		t.Errorf("expected %.1f deg, got %.1f deg", radToDegT(expect), radToDegT(got))
	}
}

// همان تستِ speed cap ولی برای «شلیکِ سریع‌تر از حدِ مجاز»: سرور باید
// FireCooldownِ واقعیِ کاراکتر+سلاح را اعمال کند، نه یک عددِ کلاینتی.
// (این تست خودِ فرمول را چک می‌کند؛ اجرای واقعی در hub.go روی همین متکی است.)
func TestFireCooldownIsAlwaysPositive(t *testing.T) {
	for cid := range characterPips {
		for wid := range weaponPips {
			cs := CharacterStats(cid)
			wm := WeaponStatsFor(wid)
			fc := cs.FireCooldown * wm.FireRateMult
			// کف عمداً پایین آمده: تیربار حالا واقعاً ثانیه‌ای ~۱۰ تیر
			// می‌زند. مهم این است که همیشه یک سقفِ سرورساخته وجود داشته
			// باشد (hub.go روی همین عدد هم shoot و هم hit را محدود می‌کند)،
			// نه اینکه عدد بزرگ باشد.
			if fc <= 0.08 {
				t.Errorf("%s+%s: fire cooldown %.3f خیلی کوتاه است (قابلِ‌سوءاستفاده)", cid, wid, fc)
			}
		}
	}
}

// مطمئن می‌شویم MissChange و FireConeDeg مقدارهایی هستند که واقعاً می‌توانند
// یک شلیک را رد کنند — یعنی این مکانیزم‌ها صفرِ همیشگی نیستند و کارِ واقعی
// انجام می‌دهند (اگر کسی روزی فرمول را طوری عوض کند که همیشه ۰ بدهد، این
// تست متوجه می‌شود که مکانیزم عملاً غیرفعال شده).
func TestMissChanceAndFireConeCanActuallyReject(t *testing.T) {
	anyPositiveMiss := false
	for cid := range characterPips {
		if CharacterStats(cid).MissChance > 0 {
			anyPositiveMiss = true
			break
		}
	}
	if !anyPositiveMiss {
		t.Error("هیچ کاراکتری MissChance مثبت ندارد — مکانیزمِ دقت غیرفعال شده")
	}
	for wid := range weaponPips {
		wm := WeaponStatsFor(wid)
		if wm.FireConeDeg <= 0 || wm.FireConeDeg >= 90 {
			t.Errorf("%s: fire_cone_deg=%.1f خارج از بازه‌ی معقول (باید واقعاً محدودکننده باشد)", wid, wm.FireConeDeg)
		}
	}
}

func isCloseAngle(a, b float64) bool {
	return math.Abs(angleDiff(a, b)) < 1e-6
}

func radToDegT(r float64) float64 {
	return r * 180.0 / math.Pi
}

// -----------------------------------------------------------------------------
// شبیه‌سازیِ حمله: یک کلاینتِ تقلبی که سعی می‌کند با فرستادنِ چرخشِ فوری
// (نه تدریجی) به سمتِ یک هدفِ پشتِ سرش، بدون رعایتِ hand_speed شلیک بگیرد.
// همان دنباله‌ی عملیاتی که hub.go در «move» و «hit» اجرا می‌کند، اینجا با
// همان توابعِ واقعی (clampRotation, angleDiff, statsOf) دوباره اجرا می‌شود.
// -----------------------------------------------------------------------------

func TestCheatingClientCannotInstantTurnToFire(t *testing.T) {
	p := &Player{X: 500, Y: 500, Rot: 0}
	applyLoadout(p, "skin_lighting", "m24sws", 1) // سریع‌ترینِ ممکن (برای سخت‌گیرترین حالت)

	// هدف دقیقاً پشتِ بازیکن (۱۸۰ درجه اختلاف)
	target := &Player{X: 500, Y: 580}
	toTargetAngle := math.Atan2(target.Y-p.Y, target.X-p.X) + math.Pi/2

	// 🌟 کلاینتِ تقلبی ادعا می‌کند فوراً رو به هدف است
	dt := 0.016 // یک تیکِ فیزیک معمولی (~۶۰fps)
	maxRotDelta := degToRad(statsOf(p).TurnRate) * dt
	p.Rot = clampRotation(p.Rot, toTargetAngle, maxRotDelta)

	// سرور باید فقط به‌اندازه‌ی توانِ واقعیِ کاراکتر بچرخاندش، نه فوری
	facingOff := math.Abs(angleDiff(p.Rot, toTargetAngle))
	if facingOff < degToRad(statsOf(p).FireConeDeg) {
		t.Fatalf("کلاینتِ تقلبی توانست در یک فریم رو به هدف شود (facingOff=%.1f deg) — چرخش محدود نشد",
			radToDegT(facingOff))
	}

	// و همین‌طور شلیک باید رد شود، چون هنوز داخلِ مخروط نیست
	if facingOff <= degToRad(statsOf(p).FireConeDeg) {
		t.Fatal("شلیک باید رد می‌شد ولی داخلِ مخروط حساب شد")
	}

	// حالا چرخشِ واقعی را چند صد فریم شبیه‌سازی می‌کنیم — باید نهایتاً برسد
	steps := 0
	for facingOff > degToRad(statsOf(p).FireConeDeg) && steps < 10000 {
		maxRotDelta = degToRad(statsOf(p).TurnRate) * dt
		p.Rot = clampRotation(p.Rot, toTargetAngle, maxRotDelta)
		facingOff = math.Abs(angleDiff(p.Rot, toTargetAngle))
		steps++
	}
	if steps >= 10000 {
		t.Fatal("چرخشِ تدریجی هیچ‌وقت به هدف نرسید")
	}
	if steps < 2 {
		t.Fatal("چرخش خیلی سریع رسید — انگار محدودیتی اعمال نشده")
	}
}

// «زدم» فرستادن هم سقفِ سرعت دارد.
//
// سقفِ قبلی فقط روی پیامِ shoot بود (که فقط افکت است). یک کلاینتِ
// دستکاری‌شده می‌توانست بدونِ هیچ شلیکی ثانیه‌ای صد بار hit بفرستد و کلِ
// فرمولِ سرعتِ شلیک را دور بزند — حالا که سلاح‌ها واقعاً تندشلیک شده‌اند،
// این سقف تعیین‌کننده است.
func TestHitActionIsRateLimited(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("arena: %v", err)
		}
	}
	h := NewHub()
	shooter := addPlayer(h, "cheater", "0", "m1", 500, 500)
	target := addPlayer(h, "victim", "1", "m1", 545, 500)
	shooter.Rot = math.Pi / 2 // رو به هدف
	shooter.Stats.FireCooldown = 0.3
	shooter.Stats.Damage = 10
	startHealth := target.Health

	client := &Client{hub: h, username: "cheater"}
	msg := WSMessage{Type: "hit", Target: "victim"}

	// ده بار پشتِ‌سرِ‌هم، بدونِ هیچ فاصله‌ای
	for i := 0; i < 10; i++ {
		h.handleAction(client, msg)
	}

	// یک ضربه‌ی زودرس برای جذبِ لرزشِ شبکه مجاز است (allowPaced)، نه بیشتر
	lost := startHealth - target.Health
	if lost != 2*shooter.Stats.Damage {
		t.Errorf("۱۰ ضربه‌ی پشتِ‌سرِ‌هم %d خسارت زد؛ فقط دو تا باید ثبت می‌شد (%d)",
			lost, 2*shooter.Stats.Damage)
	}

	// بعد از گذشتِ فاصله‌ی مجاز، ضربه‌ی بعدی باید بگیرد
	before := target.Health
	client.lastHit = time.Now().Add(-time.Second)
	h.handleAction(client, msg)
	if before-target.Health != shooter.Stats.Damage {
		t.Error("ضربه‌ی مجاز بعد از پایانِ فاصله ثبت نشد")
	}
}
