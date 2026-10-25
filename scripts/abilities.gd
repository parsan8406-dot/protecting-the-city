extends Object
class_name Abilities
## عددهای توانایی‌های دکمه‌ای — کپیِ دقیقِ gun_game_server/abilities.go.
##
## آنلاین مرجع سرور است و این عددها فقط برای پیش‌نمایش (مثلاً طولِ پرتو)
## به‌کار می‌آیند؛ شمارش‌معکوسِ دکمه‌ها از پیامِ ability خودِ سرور ساخته
## می‌شود. آفلاین (بازی سریع) سروری نیست و همین‌ها قانونِ بازی‌اند.
## اگر یکی را آن‌جا عوض کردی، این‌جا هم عوض کن.

const BOMB_STOCK := 3
const BOMB_COOLDOWN := 5.0

const SPRINT_ACTIVE := 5.0
const SPRINT_COOLDOWN := 20.0
const SPRINT_MULT := 1.2

## کوتاه و با اولین حمله‌ی خودت می‌شکند (همان abilities.go)
const GUARD_ACTIVE := 2.5
const GUARD_COOLDOWN := 22.0

const LASER_ACTIVE := 3.0
const LASER_COOLDOWN := 25.0
const LASER_RANGE := 900.0
const LASER_HALF_WIDTH := 14.0
## کسی که تمامِ پرتو را بخورد این کسر از سقفِ جانش را از دست می‌دهد
const LASER_DAMAGE_FRAC := 0.60
const LASER_TICK := 0.25

const TEAM_HEAL_RADIUS := 320.0
const TEAM_HEAL_COOLDOWN := 20.0

## شعاعِ بدنِ بازیکن روی سرور (arena.go → playerRadius)
const PLAYER_RADIUS := 25.0

## بردِ رادار: حریف فقط وقتی روی مینی‌مپ می‌آید که این‌قدر به تو نزدیک باشد.
## برای همه یکی است، پس هیچ‌کس از نقشه بیشتر از بقیه نمی‌بیند.
const RADAR_RANGE := 700.0


## خسارتِ هر ضربه‌ی لیزر — همان فرمولِ سرور (laserTickDamage)
static func laser_tick_damage(max_hp: int) -> int:
	var ticks := int(round(LASER_ACTIVE / LASER_TICK))
	return maxi(1, int(ceil(float(max_hp) * LASER_DAMAGE_FRAC / float(ticks))))


## آیا دایره‌ی (center, radius) پاره‌خطِ a→b را قطع می‌کند؟ (segmentHitsCircle)
static func segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 0.0:
		t = clampf((center - a).dot(ab) / l2, 0.0, 1.0)
	return center.distance_to(a + ab * t) <= radius
