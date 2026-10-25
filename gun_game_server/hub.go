package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"math/rand"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

// تجهیزات پیش‌فرض — باید با newPlayerModel در models.go یکی باشد
const (
	defaultCharacterID = "skin_default"
	defaultWeaponID    = "ak47"
)

// ثابت‌های WebSocket و Timings
const (
	writeWait      = 10 * time.Second    // حداکثر زمان برای نوشتن پیام
	pongWait       = 60 * time.Second    // حداکثر زمان انتظار برای pong
	pingPeriod     = (pongWait * 9) / 10 // فاصله ارسال ping
	maxMessageSize = 4096                // حداکثر سایز پیام
)

// ثابت‌های بازی (Gameplay Constants)
const (
	// maxShootRange دیگر ثابتِ سراسری نیست — بردِ واقعی از سلاحِ هر بازیکن می‌آید (weapon_balance.go → WeaponMods.MaxRange)
	hitDamage   = 25              // خسارت هر گلوله
	gracePeriod = 3 * time.Second // دوره حصانت پس از ورود
	// healCooldown/healAmount دیگر ثابتِ سراسری نیستند — از تراز خودِ هر
	// بازیکن می‌آیند (health_regen → balance.go → CharStats.HealAmount/HealCooldown)
	bombCooldown = 5 * time.Second // زمان انتظار بین پرتاب بمب‌ها
	bombDamage   = 50              // خسارت بمب
	minBombRange = 90.0            // نزدیک‌ترین جایی که می‌شود بمب انداخت
	// تأخیر انفجار بمب پس از پرتاب — دقیقاً همان چیزی که کلاینت نشان
	// می‌دهد (۰.۵۵ ثانیه پرواز + ۱ ثانیه فیوز، world.gd). قبلاً ۱ ثانیه بود و
	// خسارت وقتی می‌خورد که حلقه‌ی هشدار هنوز نیمه‌پر بود.
	bombDelay = 1550 * time.Millisecond

	// maxShotDamage سقفِ خسارتِ یک تیر — کم‌تر از جانِ ضعیف‌ترین کاراکترِ سطحِ ۱
	// (TestNoLevelOneLoadoutOneShotsAnyone)
	maxShotDamage = 120
)

// WebSocket Upgrader برای ارتقای اتصالات HTTP به WebSocket
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // اجازه تمام origins
	},
}

// getCharacterHealth سلامت اولیه هر کاراکتر را برمی‌گرداند
// equippedFor تجهیزاتِ ذخیره‌شده‌ی بازیکن را از دیتابیس می‌خواند.
// اگر بازیکن پیدا نشد یا دیتابیس در دسترس نبود، مقدار پیشنهادی کلاینت
// (و در نهایت پیش‌فرض‌ها) استفاده می‌شود تا ورود به بازی بلاک نشود.
// charLevel سطح ارتقای کاراکتر از item_levels است (skins.go) و charSkin/
// weaponSkin اسکینِ فعالِ همان آیتم‌ها — خالی یعنی ظاهر پیش‌فرض.
func equippedFor(username, fallbackChar, fallbackWeapon string) (
	charID, weaponID string, charLevel int, charSkin, weaponSkin string,
) {
	charID, weaponID = fallbackChar, fallbackWeapon
	charLevel = 1
	var stored *PlayerModel

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if p, err := getPlayerByUsername(ctx, username); err != nil {
		log.Printf("⚠️ equipped lookup failed for %s: %v (using client values)", username, err)
	} else {
		if p.EquippedCharacter != "" {
			charID = p.EquippedCharacter
		}
		if p.EquippedWeapon != "" {
			weaponID = p.EquippedWeapon
		}
		stored = p
	}

	if charID == "" {
		charID = defaultCharacterID
	}
	if weaponID == "" {
		weaponID = defaultWeaponID
	}
	if stored != nil {
		charLevel = characterLevel(stored, charID)
		charSkin = activeSkin(stored, charID)
		weaponSkin = activeSkin(stored, weaponID)
	}
	return charID, weaponID, charLevel, charSkin, weaponSkin
}

func getCharacterHealth(characterID string) int {
	return CharacterStats(characterID).Health
}

// statsOf تراز نهاییِ یک بازیکن — کاراکتر + سلاح با هم، از پیش در
// applyLoadout حساب و کش شده (نه این‌که هر بار از نو محاسبه شود).
func statsOf(p *Player) CharStats {
	if p == nil {
		return CharacterStats(defaultCharacterID)
	}
	return p.Stats
}

// applyLoadout تجهیزات و ترازِ نهایی را با هم ست می‌کند — تنها جایی که
// Character/CharacterLevel/Weapon/Stats عوض می‌شوند، تا هیچ‌وقت از هم عقب
// نمانند. سلاح یک لایه‌ی نازک روی تراز کاراکتر می‌نشیند: خسارت/دقت/سرعتِ
// شلیکِ کاراکتر را کمی بالا‌وپایین می‌کند و برد/مخروطِ نشانه‌روی را خودش
// تعیین می‌کند (چیزهایی که به خودِ کاراکتر ربطی ندارند).
func applyLoadout(p *Player, charID, weaponID string, level int) {
	p.Character, p.Weapon, p.CharacterLevel = charID, weaponID, level

	cs := CharacterStatsAtLevel(charID, level)
	wm := WeaponStatsFor(weaponID)
	exact := cs.damageExact
	if exact <= 0 {
		exact = float64(cs.Damage)
	}
	cs.Damage = int(math.Round(exact * wm.DamageMult))
	cs.MissChance = clampUnit(cs.MissChance * wm.MissMult)
	cs.FireCooldown = cs.FireCooldown * wm.FireRateMult
	cs.MaxRange = wm.MaxRange
	cs.FireConeDeg = wm.FireConeDeg
	// 🌟 چرخش: hand_speedِ کاراکتر و controlِ سلاح هر دو روی «چرخش و آزادیِ
	// حرکت» اثر دارند، پس میانگینشان گرفته می‌شود و یکی می‌شوند — نه این‌که
	// هرکدام مسیرِ جدا داشته باشند. هر دو با یک فرمول حساب شده‌اند
	// (۲۶۰ + pip×۶۰) پس میانگین‌گیری معنی‌دار است.
	cs.TurnRate = (cs.TurnRate + wm.TurnRateContribution) / 2.0
	// خشاب بعد از نهایی شدنِ سرعتِ شلیک حساب می‌شود — سلاحِ تندشلیک
	// خشابِ بزرگ‌تری می‌گیرد تا رگبارش واقعاً دوام بیاورد
	cs.MagSize = magazineFor(cs.FireCooldown)
	cs.ReloadSeconds = MagReloadSeconds
	// خسارتِ هر گلوله با سرعتِ شلیک کوچک می‌شود؛ هیچ‌وقت نباید به صفر برسد
	if cs.Damage < 1 {
		cs.Damage = 1
	}
	// و هیچ تیری نباید کسی را یک‌جا بیندازد (تک‌تیرانداز + کاراکترِ پرآتش
	// قبلاً ۱۳۵ می‌زد در برابرِ ۱۲۷ جانِ ضعیف‌ترین کاراکتر)
	if cs.Damage > maxShotDamage {
		cs.Damage = maxShotDamage
	}

	p.Stats = cs
}

// clampUnit عدد را بین ۰ و ۱ نگه می‌دارد (برای MissChance).
func clampUnit(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

// degToRad درجه را به رادیان تبدیل می‌کند
func degToRad(deg float64) float64 {
	return deg * math.Pi / 180.0
}

// angleDiff کوتاه‌ترین اختلافِ دو زاویه را در بازه‌ی (-π, π] برمی‌گرداند.
func angleDiff(from, to float64) float64 {
	// math.Remainder به‌جای حلقه: با rot=1e300 حلقه‌ی قبلی هیچ‌وقت تمام
	// نمی‌شد (۲π زیر دقتِ float گم می‌شد) و کلِ گوروتینِ هاب قفل می‌شد.
	return math.Remainder(to-from, 2*math.Pi)
}

// clampRotation زاویه‌ی current را حداکثر به‌اندازه‌ی maxDelta به سمتِ
// target می‌برد — نسخه‌ی سرور از همان _turn_toward سمتِ کلاینت
// (player.gd)، برای این‌که کلاینتِ دستکاری‌شده نتواند سریع‌تر از
// turn_rateِ واقعیِ کاراکترش بچرخد.
func clampRotation(current, target, maxDelta float64) float64 {
	diff := angleDiff(current, target)
	if math.Abs(diff) <= maxDelta {
		return target
	}
	if diff > 0 {
		return current + maxDelta
	}
	return current - maxDelta
}

// distance فاصله بین دو نقطه را محاسبه می‌کند
func distance(x1, y1, x2, y2 float64) float64 {
	dx := x2 - x1
	dy := y2 - y1
	return math.Sqrt(dx*dx + dy*dy)
}

// WSMessage نمایش یک پیام WebSocket از کلاینت
type WSMessage struct {
	Type       string  `json:"type"` // نوع پیام: join, move, shoot, hit, heal, bomb
	Username   string  `json:"username,omitempty"`
	Target     string  `json:"target,omitempty"`    // برای پیام‌های هدف‌دار (hit)
	X          float64 `json:"x,omitempty"`         // موقعیت X
	Y          float64 `json:"y,omitempty"`         // موقعیت Y
	Rot        float64 `json:"rot,omitempty"`       // جهت نگاه
	CharID     string  `json:"character,omitempty"` // شناسه کاراکتر
	Weapon     string  `json:"weapon,omitempty"`    // شناسه سلاح
	Health     int     `json:"health,omitempty"`
	Seconds    int     `json:"seconds,omitempty"`
	DirectionX float64 `json:"dir_x,omitempty"` // جهت پرتاب بمب (محور X)
	DirectionY float64 `json:"dir_y,omitempty"` // جهت پرتاب بمب (محور Y)
	Distance   float64 `json:"dist,omitempty"`  // فاصله‌ی نشانه‌گرفته‌شده‌ی بمب
	Radius     float64 `json:"radius,omitempty"`
	// Arena یعنی «همین حالا وارد زمینِ بازی شدم».
	//
	// join دو بار می‌آید: یک بار موقعِ باز شدنِ سوکت (توی منو، فقط برای
	// اینکه سرور بداند این کلاینت کیست و چت/نوتیف را برایش بفرستد) و یک
	// بار موقعِ ورود به آرنا. فقط دومی باید بات بسازد و راند را شروع کند.
	Arena   bool                   `json:"arena,omitempty"`
	Damage  int                    `json:"damage,omitempty"`
	RawData map[string]interface{} `json:"-"` // داده‌های خام برای parsing
	// loadout تجهیزاتِ خوانده‌شده از دیتابیس — روی گوروتینِ خودِ کلاینت
	// (readPump) پر می‌شود تا join/equip حلقه‌ی هاب و همه‌ی مسابقه‌ها را
	// پشتِ یک کوئریِ مونگو معطل نکنند. از JSON کلاینت پر نمی‌شود.
	loadout *loadoutInfo
}

// loadoutInfo خروجیِ equippedFor
type loadoutInfo struct {
	charID, weaponID     string
	charLevel            int
	charSkin, weaponSkin string
}

// loadoutOf اگر readPump تجهیزات را از قبل خوانده همان را می‌دهد، وگرنه
// (تست‌ها، پیام‌های درونی) همین‌جا می‌خواند.
func loadoutOf(username string, msg WSMessage) (string, string, int, string, string) {
	if l := msg.loadout; l != nil {
		return l.charID, l.weaponID, l.charLevel, l.charSkin, l.weaponSkin
	}
	return equippedFor(username, msg.CharID, msg.Weapon)
}

// Client نمایش یک اتصال WebSocket برقرار
type Client struct {
	hub       *Hub            // مرجع به Hub برای broadcast
	conn      *websocket.Conn // اتصال WebSocket
	send      chan []byte     // کانال ارسال پیام‌ها
	username  string          // نام کاربری (پر شده پس از join)
	lastShoot time.Time       // زمان آخرین شلیک (برای rate limiting)
	lastHit   time.Time       // زمان آخرین ضربه‌ی ثبت‌شده (rate limiting)
	closed    bool            // کانالِ send بسته شده — دیگر نه پیامی می‌گیرد نه اکشنی
}

// Hub مرکزی برای مدیریت تمام اتصالات و state بازی
type Hub struct {
	clients    map[*Client]bool   // تمام clients متصل
	players    map[string]*Player // state بازیکن‌های فعلی
	register   chan *Client       // کانال ثبت‌نام client جدید
	unregister chan *Client       // کانال حذف client
	broadcast  chan []byte        // کانال broadcast پیام‌ها
	actions    chan hubAction     // کانال اکشن‌های بازی
	notify     chan userMessage   // کانال پیام بلادرنگ به یک بازیکن خاص

	// کول‌داون بمب بر اساس نام کاربری نگه داشته می‌شود، نه روی Player یا Client.
	// وگرنه یک تقلب ساده وجود داشت: قطع کردن اتصال و join دوباره، Player تازه
	// می‌ساخت و LastBombTime صفر می‌شد — یعنی بمب پشت‌سرهم و بدون انتظار.
	bombCooldowns map[string]time.Time

	// قفلِ توانایی‌ها (abilities.go) — به همان دلیلِ بمب بر اساس نام کاربری:
	// کلید "kind:username"، مقدار لحظه‌ای که دوباره باز می‌شود.
	abilityCooldowns map[string]time.Time
	// bombsUsed چند بمب هر بازیکن در هر مسابقه انداخته ("match:username").
	// روی Player نیست تا join دوباره موجودیِ بمب را پر نکند.
	bombsUsed map[string]int

	// bots هوشِ بات‌ها (botai.go). فقط از گوروتینِ Run دست‌کاری می‌شود،
	// مثل players — پس قفلی لازم نیست.
	bots    map[string]*BotRuntime
	botTick chan struct{}

	// راندهای در جریان (match_round.go). مثل players فقط از گوروتینِ Run
	// دست‌کاری می‌شوند.
	rounds      map[string]*RoundState
	playerRound map[string]string // username -> match_id

	// adminCalls کارهای پنل مدیریت (آمار زنده، بیرون انداختن بازیکن) که
	// باید روی گوروتینِ Run اجرا شوند تا به نقشه‌های هاب هم‌زمان دست نخورد.
	adminCalls chan func(h *Hub)

	// sessions سوکتِ فعلیِ هر نام کاربری. اگر بازیکن با سوکتِ تازه وصل شود
	// و سوکتِ قبلی (نیمه‌باز) بعداً بسته شود، پاک‌سازی نباید بازیکنِ تازه را
	// از زمین بیرون بیندازد — فقط وقتی پاک می‌کنیم که همان سوکت مالک باشد.
	sessions map[string]*Client
	// dropped کلاینت‌هایی که وسطِ یک چرخه (مثلاً صفِ ارسالِ پر) کنار گذاشته
	// شدند؛ پاک‌سازیِ بازیکنشان در انتهای همان چرخه‌ی Run انجام می‌شود تا
	// وسطِ پیمایشِ h.clients دوباره broadcast تو در تو نزنیم.
	dropped []*Client
}

// userMessage یک پیام بلادرنگ برای یک یا چند بازیکن مشخص
// (مثلاً «یک درخواست دوستی جدید داری» یا یک پیام چت شهر) — برای اینکه
// لازم نباشد کلاینت منتظر رفرش دوره‌ای بماند.
//
// اگر everyone روشن باشد پیام به همه‌ی متصل‌ها می‌رود (چت جهانی)،
// وگرنه گیرنده‌ها از username و usernames خوانده می‌شوند.
type userMessage struct {
	username  string   // یک گیرنده
	usernames []string // چند گیرنده (مثلاً اعضای یک شهر)
	everyone  bool     // همه‌ی بازیکن‌های متصل
	data      []byte
}

// isRecipient بررسی می‌کند این پیام برای فلان بازیکن هست یا نه
func (m userMessage) isRecipient(username string) bool {
	if m.everyone {
		return true
	}
	if m.username != "" && m.username == username {
		return true
	}
	for _, name := range m.usernames {
		if name == username {
			return true
		}
	}
	return false
}

// globalHub مرجع سراسری به Hub تا هندلرهای HTTP (دوستان، هدیه، پیام‌ها) هم
// بتوانند نوتیفیکیشن بلادرنگ بفرستند. در main() مقداردهی می‌شود.
var globalHub *Hub

// NotifyUser یک پیام بلادرنگ به بازیکنِ آنلاین می‌فرستد.
// اگر بازیکن آنلاین نباشد یا هاب بالا نیامده باشد، بی‌صدا رد می‌شود —
// دفعه‌ی بعد که تب را باز کند خودش از سرور می‌خواند.
func NotifyUser(username string, payload map[string]interface{}) {
	if globalHub == nil || username == "" {
		return
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	queueNotify(userMessage{username: username, data: data})
}

// NotifyUsers همان پیام را برای چند بازیکن می‌فرستد (مثلاً اعضای یک شهر).
func NotifyUsers(usernames []string, payload map[string]interface{}) {
	if globalHub == nil || len(usernames) == 0 {
		return
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	queueNotify(userMessage{usernames: usernames, data: data})
}

// NotifyEveryone پیام را به تمام بازیکن‌های متصل می‌فرستد (چت جهانی).
func NotifyEveryone(payload map[string]interface{}) {
	if globalHub == nil {
		return
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	queueNotify(userMessage{everyone: true, data: data})
}

// queueNotify پیام را در صف هاب می‌گذارد. اگر صف پر باشد بی‌صدا رد می‌شود —
// این پیام‌ها حیاتی نیستند و کلاینت دفعه‌ی بعد خودش از سرور می‌خواند.
func queueNotify(msg userMessage) {
	select {
	case globalHub.notify <- msg:
	default:
	}
}

// hubAction نمایش یک اکشن بازی که باید توسط Hub مدیریت شود
type hubAction struct {
	client *Client
	msg    WSMessage
}

// NewHub یک Hub جدید ایجاد می‌کند
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		players:    make(map[string]*Player),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan []byte),
		actions:    make(chan hubAction, 1000),
		notify:     make(chan userMessage, 512),

		bombCooldowns:    make(map[string]time.Time),
		abilityCooldowns: make(map[string]time.Time),
		bombsUsed:        make(map[string]int),
		bots:             make(map[string]*BotRuntime),
		botTick:          make(chan struct{}, 1),
		rounds:           make(map[string]*RoundState),
		playerRound:      make(map[string]string),
		adminCalls:       make(chan func(h *Hub), 16),
		sessions:         make(map[string]*Client),
	}
}

// Run حلقه اصلی Hub را اجرا می‌کند (باید در Goroutine جداگانه اجرا شود)
// این متد تمام اکشن‌ها و پیام‌ها را پردازش می‌کند
func (h *Hub) Run() {
	lastBotTick := time.Now()
	for {
		h.runOnce(&lastBotTick)
	}
}

// runOnce یک چرخه‌ی هاب. panic در یک پیام نباید کلِ سرور (و همه‌ی
// مسابقه‌ها) را بکشد — لاگ می‌شود و حلقه ادامه می‌دهد.
func (h *Hub) runOnce(lastBotTick *time.Time) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("🔥 hub panic recovered: %v", r)
		}
		h.flushDropped()
	}()
	{
		select {
		// ثبت‌نام client جدید
		case client := <-h.register:
			h.clients[client] = true

		// حذف client قطع‌شده
		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				h.closeClient(client)
				h.cleanupClient(client)
			}

		// broadcast پیام به تمام clients
		case message := <-h.broadcast:
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					h.dropClient(client)
				}
			}

		// پیام بلادرنگ فقط برای یک بازیکن
		case nm := <-h.notify:
			for client := range h.clients {
				if client.username == "" || !nm.isRecipient(client.username) {
					continue
				}
				select {
				case client.send <- nm.data:
				default:
					h.dropClient(client)
				}
			}

		// کارهای پنل مدیریت (admin_live.go)
		case fn := <-h.adminCalls:
			fn(h)

		// پردازش اکشن‌های بازی
		case action := <-h.actions:
			h.handleAction(action.client, action.msg)

		// تیکِ بات‌ها. عمداً همین‌جا و روی همین گوروتین اجرا می‌شود تا
		// h.players هیچ‌وقت هم‌زمان از دو گوروتین دست نخورد.
		case <-h.botTick:
			now := time.Now()
			dt := now.Sub(*lastBotTick).Seconds()
			*lastBotTick = now
			// بعد از یک وقفه‌ی طولانی (مثلاً سرور مشغول بوده) dt را سقف
			// می‌زنیم، وگرنه بات‌ها یک‌باره چند متر می‌پرند
			if dt > 0.25 {
				dt = 0.25
			}
			h.stepBots(dt)
			h.tickAbilities(now)
			h.tickRounds()
		}
	}
}

// dropClient کلاینتی را که صفِ ارسالش پر شده کنار می‌گذارد. کانال فقط یک
// بار بسته می‌شود (ارسال روی کانالِ بسته panic است) و پاک‌سازیِ بازیکنش
// به انتهای چرخه‌ی فعلی موکول می‌شود — قبلاً این مسیر بازیکن را تا ابد
// به‌صورتِ «روح» در مسابقه نگه می‌داشت.
func (h *Hub) dropClient(client *Client) {
	if _, ok := h.clients[client]; !ok {
		return
	}
	h.closeClient(client)
	h.dropped = append(h.dropped, client)
}

// closeClient سوکت را از هاب جدا و کانالش را دقیقاً یک بار می‌بندد.
func (h *Hub) closeClient(c *Client) {
	delete(h.clients, c)
	if !c.closed {
		c.closed = true
		close(c.send)
	}
}

func (h *Hub) flushDropped() {
	for len(h.dropped) > 0 {
		c := h.dropped[0]
		h.dropped = h.dropped[1:]
		h.cleanupClient(c)
	}
}

// cleanupClient بازیکنِ یک سوکتِ بسته‌شده را از زمین و راند و صف بیرون
// می‌آورد — فقط اگر همین سوکت هنوز صاحبِ آن نام کاربری باشد.
func (h *Hub) cleanupClient(client *Client) {
	if client.username == "" || h.sessions[client.username] != client {
		return
	}
	delete(h.sessions, client.username)
	mid := h.matchIDOf(client.username)
	// قطعِ اتصال = حذف از راند. وگرنه اگر کسی وسطِ بازی ببندد، تیمش
	// هیچ‌وقت «تمام» نمی‌شود و راند تا آخرِ تایمر بی‌خود ادامه پیدا می‌کند.
	h.onPlayerEliminated(client.username)
	delete(h.players, client.username)
	delete(h.playerRound, client.username)
	h.releaseAfterLeaving(client.username, mid)
	fmt.Printf("🔌 Player disconnected: %s\n", client.username)
	go SetPlayerOnline(client.username, false)
	h.broadcastPlayerUpdate()
}

// releaseAfterLeaving بعد از رفتنِ یک آدم از زمین (قطعِ اتصال یا خروج):
// اگر کسِ دیگری در این مسابقه نمانده — نه در زمین و نه در راه — کلِ
// مسابقه آزاد و راندش بسته می‌شود؛ وگرنه فقط خودش از صف/مسابقه بیرون می‌رود.
func (h *Hub) releaseAfterLeaving(username, matchID string) {
	if h.humansLeftInMatchOf(matchID) == 0 && !otherHumansPending(matchID, username) {
		h.abandonRound(matchID)
		go ReleaseMatchOf(username)
		return
	}
	go ReleasePlayer(username)
}

// dropSpawnShield محافظِ تولدِ یک بازیکن را همین حالا تمام می‌کند.
//
// فقط وقتی کاری می‌کند که محافظ هنوز فعال باشد؛ آن‌وقت لیستِ بازیکن‌ها
// دوباره پخش می‌شود تا کلاینت‌ها گنبد را از روی او بردارند (کلاینت
// shield_left را از همان لیست می‌خواند).
//
// سپرِ دستی (guard) هم با حمله می‌شکند: وقتی سپر چهار ثانیه بی‌آسیبی می‌داد
// و صاحبش هم‌زمان شلیک می‌کرد، هر دوئلی را بی‌برو‌برگرد می‌برد. حالا سپر
// ابزارِ فرار/عقب‌نشینی است، نه برگِ برنده‌ی حمله.
func (h *Hub) dropSpawnShield(p *Player) {
	if p == nil {
		return
	}
	now := time.Now()
	changed := false
	if now.Before(p.InvulnerableUntil) {
		p.InvulnerableUntil = now
		changed = true
	}
	if now.Before(p.GuardUntil) {
		p.GuardUntil = now
		changed = true
	}
	if changed {
		h.broadcastPlayerUpdate()
	}
}

// validateHit بررسی می‌کند آیا یک شلیک معتبر است
// شامل چک‌های: وجود هدف، حصانت، فاصله، و خط دید (دیوار وسط نباشد)
func (h *Hub) validateHit(shooter *Player, targetUsername string) bool {
	targetPlayer, exists := h.players[targetUsername]
	if !exists {
		return false
	}
	// مُرده نه تیر می‌زند نه تیر می‌خورد — وگرنه تیرهای در راه بعد از مرگ
	// دوباره «کشتن» ثبت می‌کردند و امتیاز/ماموریت باد می‌کرد.
	if shooter.Health <= 0 || targetPlayer.Health <= 0 {
		return false
	}
	// فقط داخلِ همان مسابقه — نه از یک زمین به زمینِ دیگر
	if targetPlayer.MatchID != shooter.MatchID {
		return false
	}
	// آتشِ خودی ممنوع. تیمِ خالی یعنی تمرینِ بی‌تیم و آن‌جا همه حریف‌اند.
	if shooter.Team != "" && targetPlayer.Team == shooter.Team {
		return false
	}
	// بررسی حصانت شاتر و هدف
	if time.Now().Before(targetPlayer.InvulnerableUntil) || time.Now().Before(shooter.InvulnerableUntil) {
		return false
	}
	// سپرِ دستی فقط از خودِ صاحبش محافظت می‌کند؛ او هنوز می‌تواند شلیک کند
	if isGuarded(targetPlayer, time.Now()) {
		return false
	}
	// بررسی فاصله — بردِ سلاحِ واقعیِ شلیک‌کننده، نه یک عددِ ثابتِ سراسری
	// به‌اندازه‌ی بدنِ هدف حاشیه: کلاینت به نسخه‌ی کمی قدیمی‌ترِ هدف شلیک
	// می‌کند و هدفی که دارد دور می‌شود نباید لبِ برد بی‌خود رد شود.
	dist := distance(shooter.X, shooter.Y, targetPlayer.X, targetPlayer.Y)
	if dist > statsOf(shooter).MaxRange+playerRadius {
		return false
	}
	// بررسی خط دید: اگر دیواری بین شلیک‌کننده و هدف باشد، تیر نمی‌خورد.
	// کلاینت هم SightRay دارد ولی کلاینت قابل دستکاری است — حرف آخر اینجاست.
	if a := arenaOf(shooter); a != nil &&
		!a.HasLineOfSight(shooter.X, shooter.Y, targetPlayer.X, targetPlayer.Y) {
		return false
	}
	return true
}

// handleAction اکشن‌های مختلف بازی را مدیریت می‌کند
// اکشن‌ها شامل: join, move, shoot, hit, heal, bomb
func (h *Hub) handleAction(client *Client, msg WSMessage) {
	// پیامی که قبل از کنار گذاشتنِ این کلاینت در صف مانده بود دیگر اعتبار
	// ندارد — جوابش روی کانالِ بسته فرستاده می‌شد و سرور panic می‌کرد.
	if client != nil && client.closed {
		return
	}
	switch msg.Type {
	// اکشن ورود بازیکن جدید به بازی
	case "join":
		if msg.Username == "" || client == nil {
			return
		}
		// همین سوکت قبلاً با نامِ دیگری وارد شده بود: بازیکنِ قبلی را
		// پاک کن تا یتیم در h.players نماند.
		if client.username != "" && client.username != msg.Username {
			h.cleanupClient(client)
		}
		// همین نام با سوکتِ دیگری هم وصل است (اتصالِ دوباره بعد از قطعیِ
		// شبکه): سوکتِ قدیمی بی‌صدا کنار می‌رود و پاک‌سازی‌اش اجرا نمی‌شود.
		if old := h.sessions[msg.Username]; old != nil && old != client {
			h.closeClient(old)
		}
		client.username = msg.Username
		h.sessions[msg.Username] = client

		// همین بازیکن همین حالا داخلِ زمینِ همین مسابقه است (اتصالِ دوباره،
		// یا joinِ تکراری): بازیکنِ زنده دست نمی‌خورد. قبلاً یک Playerِ تازه
		// با جانِ پر و محافظِ تولد جایش می‌نشست — مُرده زنده می‌شد و یک
		// کلاینتِ دستکاری‌شده با join پشتِ‌سرِهم همیشه شکست‌ناپذیر بود.
		if old, ok := h.players[msg.Username]; ok && old.InArena && old.MatchID != "" {
			if m := MatchOf(msg.Username); m != nil && m.MatchID == old.MatchID {
				if msg.Arena {
					shield := time.Until(old.InvulnerableUntil)
					if shield < 0 {
						shield = 0
					}
					h.sendSpawn(client, old.X, old.Y, MapNameForMode(m.ModeID), ThemeOfMatch(msg.Username), shield)
					if r := h.rounds[old.MatchID]; r != nil {
						h.broadcastRoundState(r)
					}
				}
				h.broadcastPlayerUpdate()
				return
			}
		}
		// تجهیزات از دیتابیس خوانده می‌شود، نه از پیام کلاینت: هرچه بازیکن
		// در فروشگاه انتخاب کرده همان بارگذاری می‌شود و کلاینت نمی‌تواند
		// کاراکتری را جا بزند که مالکش نیست.
		charID, weaponID, charLevel, charSkin, weaponSkin := loadoutOf(msg.Username, msg)
		msg.CharID, msg.Weapon = charID, weaponID
		maxHealth := CharacterStatsAtLevel(charID, charLevel).Health
		// نقطه‌ی شروع را سرور تعیین می‌کند، نه کلاینت — دورترین نقطه از بقیه.
		// نقطه‌ی شروع: هم‌تیمی‌ها کنارِ هم، دو تیم دور از هم. برای بازیِ
		// بدونِ ماچ‌میکینگ (تمرین) همان پخشِ قدیمی می‌ماند.
		myTeam := TeamOf(msg.Username)
		myMatch := ""
		myMode := ""
		teamSize := 1
		seat := 0
		if m := MatchOf(msg.Username); m != nil {
			myMatch = m.MatchID
			myMode = m.ModeID
			for _, qp := range m.Players {
				t := fmt.Sprintf("%d", qp.Team)
				if t == myTeam {
					if qp.Username == msg.Username {
						seat = teamSize - 1
					}
					teamSize++
				}
			}
			teamSize--
			if teamSize < 1 {
				teamSize = 1
			}
		}
		// هر حالت زمینِ خودش را دارد؛ حالتِ بدونِ زمینِ اختصاصی روی
		// زمینِ پیش‌فرض می‌افتد (arena.go → ArenaForMode)
		myArena := ArenaForMode(myMode)
		// محافظِ تولد و نامِ نقشه، هر دو از روی حالتِ همین مسابقه
		myRules := rulesForMode(myMode)
		spawnX, spawnY := 0.0, 0.0
		if myArena != nil {
			occupied := make([][2]float64, 0, len(h.players))
			for _, p := range h.players {
				if p.MatchID == myMatch {
					occupied = append(occupied, [2]float64{p.X, p.Y})
				}
			}
			if myMatch != "" {
				teamNo := 0
				if myTeam == "1" {
					teamNo = 1
				}
				spawnX, spawnY = myArena.TeamSpawn(myMatch, teamNo, seat, teamSize, occupied)
			} else {
				spawnX, spawnY = myArena.RandomSpawn(occupied)
			}
		}
		newPlayer := &Player{
			Username:          msg.Username,
			Health:            maxHealth,
			Arena:             myArena,
			X:                 spawnX,
			Y:                 spawnY,
			JoinedAt:          time.Now(),
			InvulnerableUntil: time.Now().Add(myRules.SpawnShield),
			LastMoveTime:      time.Now(),
		}
		applyLoadout(newPlayer, msg.CharID, msg.Weapon, charLevel)
		newPlayer.CharacterSkin, newPlayer.WeaponSkin = charSkin, weaponSkin
		// تیم و مسابقه‌ی همین بازیکن. MatchID مرزِ دیدِ او را تعیین می‌کند:
		// فقط هم‌مسابقه‌ای‌هایش را می‌بیند و فقط آن‌ها او را می‌بینند.
		newPlayer.Team = TeamOf(msg.Username)
		if m := MatchOf(msg.Username); m != nil {
			newPlayer.MatchID = m.MatchID
		}
		newPlayer.InArena = msg.Arena
		h.prepareBombStock(newPlayer, msg.Arena)
		h.players[msg.Username] = newPlayer

		// بات‌های همین مسابقه را وارد آرنا کن. عمداً این‌جا و نه لحظه‌ی
		// جور شدنِ مسابقه: تا وقتی آدم واقعاً وارد زمین نشده، شبیه‌سازی
		// کردنِ بات‌ها فقط مصرفِ بی‌خودِ سرور است.
		// هر بات شماره‌ی صندلیِ خودش را در تیمش می‌گیرد تا هم‌تیمی‌ها
		// نزدیکِ هم ولی نه روی هم ظاهر شوند
		//
		// فقط برای joinِ آرنا: joinِ منو (موقعِ باز شدنِ سوکت) نباید بات
		// بسازد و نباید راند را شروع کند، وگرنه اگر بازیکن هنوز توی منو
		// باشد تایمرِ راند بی‌خود می‌سوزد.
		if msg.Arena {
			seats := map[string]int{}
			sizes := map[string]int{}
			if m := MatchOf(msg.Username); m != nil {
				for _, qp := range m.Players {
					sizes[fmt.Sprintf("%d", qp.Team)]++
				}
			}
			for _, b := range botsInMatchOf(msg.Username) {
				h.AddBot(b.Username, b.Skill, b.Team, newPlayer.MatchID,
					seats[b.Team], sizes[b.Team], myArena)
				seats[b.Team]++
			}
			// راندِ حذفی از همین‌جا شروع می‌شود — وقتی بازیکن واقعاً وارد زمین شد
			h.startRound(msg.Username)
			// ماموریت‌های باز (روزانه و فصل) از دیتابیس خوانده می‌شوند و
			// به‌صورتِ «اهداف» سمتِ چپِ صفحه نشان داده می‌شوند
			h.loadObjectivesAsync(msg.Username, newPlayer.MatchID)
		}
		// کلاینت باید از همین‌جا شروع کند
		h.sendSpawn(client, spawnX, spawnY, MapNameForMode(myMode), ThemeOfMatch(msg.Username), myRules.SpawnShield)
		// ثبت آنلاین شدن در دیتابیس
		go SetPlayerOnline(msg.Username, true)
		fmt.Printf("🎮 Player joined: %s (HP: %d)\n", msg.Username, maxHealth)
		// شمارش معکوسِ ۳-۲-۱ حذف شد؛ حصانتِ اولِ ورود (gracePeriod) سر جایش
		// است و بازیکن از همان لحظه می‌تواند بازی کند.
		// matchID همین‌جا خوانده می‌شود و نه داخلِ گوروتین: خواندنِ h.players
		// از گوروتینِ دیگر مسابقه‌ی داده‌ای است.
		// پخش از گوروتینِ دیگر روی h.clients/h.players مسابقه‌ی داده‌ای بود
		// (و می‌توانست کلِ پروسه را با concurrent map access بکشد)؛ حالا
		// فقط زمان‌بندی بیرون است و خودِ پخش روی گوروتینِ هاب.
		// joinِ منو (بدونِ مسابقه) game_start ندارد.
		if startMatchID := newPlayer.MatchID; startMatchID != "" {
			time.AfterFunc(gracePeriod, func() {
				h.adminCalls <- func(h *Hub) { h.broadcastGameStart(startMatchID) }
			})
		}
		h.broadcastPlayerUpdate()

	// اکشن تعویض تجهیزات از منو (انتخاب کاراکتر/اسلحه)
	//
	// بدون این، نسخه‌ی درون‌حافظه‌ی بازیکن همان تجهیزاتِ لحظه‌ی join می‌ماند —
	// چون join فقط یک بار موقع باز شدن سوکت فرستاده می‌شود. نتیجه این بود که
	// بازیکن در منو کاراکتر عوض می‌کرد ولی موقع ورود به آرنا سرور همان کاراکتر
	// قدیمی را پخش می‌کرد و انتخاب تازه بازنویسی می‌شد.
	//
	// عمداً respawn و countdown ندارد: این فقط ظاهر را تازه می‌کند، بازی را از نو شروع نمی‌کند.
	case "equip":
		if client.username == "" {
			return
		}
		p, exists := h.players[client.username]
		if !exists {
			return
		}
		// مثل join، منبع حقیقت دیتابیس است نه پیام کلاینت؛ پس کلاینت نمی‌تواند
		// کاراکتری را جا بزند که مالکش نیست.
		// تجهیزات فقط برای همان نامی که readPump خوانده معتبر است
		if msg.loadout != nil && msg.Username != client.username {
			msg.loadout = nil
		}
		charID, weaponID, charLevel, charSkin, weaponSkin := loadoutOf(client.username, msg)
		applyLoadout(p, charID, weaponID, charLevel)
		p.CharacterSkin, p.WeaponSkin = charSkin, weaponSkin
		// سقف جان با کاراکتر عوض می‌شود، ولی جان فعلی هیچ‌وقت بالا نمی‌رود تا
		// عوض کردن کاراکتر وسط بازی تبدیل به «هک درمان» نشود.
		if maxHealth := statsOf(p).Health; p.Health > maxHealth {
			p.Health = maxHealth
		}
		fmt.Printf("🔄 Equipment updated: %s (%s / %s)\n", client.username, charID, weaponID)
		h.broadcastPlayerUpdate()

	// اکشن حرکت بازیکن — سرور موقعیت را اعتبارسنجی و در صورت لزوم اصلاح می‌کند
	case "move":
		if client.username == "" {
			return
		}
		p, exists := h.players[client.username]
		if !exists {
			return
		}
		// زمان سپری‌شده از آخرین حرکت — هم برای سقفِ سرعتِ جابه‌جایی هم چرخش
		now := time.Now()
		dt := now.Sub(p.LastMoveTime).Seconds()
		if p.LastMoveTime.IsZero() || dt > 1.0 {
			dt = 1.0 // بعد از وقفه‌ی طولانی سخت‌گیری نکن
		}
		p.LastMoveTime = now

		// 🌟 چرخش هم مثل موقعیت اعتبارسنجی می‌شود: یک کلاینتِ دستکاری‌شده
		// نمی‌تواند سریع‌تر از turn_rateِ واقعیِ کاراکتر/سلاحش بچرخد — وگرنه
		// می‌توانست همیشه فوری «رو به هدف» باشد و کل مکانیزمِ hand_speed را
		// دور بزند. مقدارِ ذخیره‌شده همیشه از این تابع می‌آید، نه از msg.Rot
		// مستقیم؛ همین مقدار بعداً برای مخروطِ شلیک هم استفاده می‌شود.
		if !isFinite(msg.Rot) || math.Abs(msg.Rot) > 1000 {
			return
		}
		p.ClaimedRot = msg.Rot
		h.syncRot(p, now)

		a := arenaOf(p)
		if a == nil {
			p.X, p.Y = msg.X, msg.Y
			h.broadcastMove(client.username, p.X, p.Y, p.Rot)
			return
		}

		// سقفِ جابه‌جایی یک سطلِ توکن است: با زمانِ واقعی پر می‌شود (دویدن
		// تندترش می‌کند) و حداکثر نیم‌ثانیه حرکت ذخیره دارد.
		speedCap := maxMoveSpeed
		if now.Before(p.SprintUntil.Add(sprintGrace)) {
			speedCap *= SprintSpeedMult
		}
		p.MoveBudget = math.Min(p.MoveBudget+speedCap*dt, speedCap*0.5)
		okX, okY := a.ResolveMoveMax(p.X, p.Y, msg.X, msg.Y, playerRadius, p.MoveBudget)
		p.MoveBudget = math.Max(0, p.MoveBudget-math.Hypot(okX-p.X, okY-p.Y))
		p.X, p.Y = okX, okY

		// اگر جایی که کلاینت ادعا کرده با جای مجاز فرق دارد، برش گردان.
		// (دیوارگذر، سرعت غیرمجاز، یا بیرون‌رفتن از زمین)
		if math.Hypot(msg.X-okX, msg.Y-okY) > correctionEpsilon {
			h.sendCorrection(client, okX, okY)
		}
		h.broadcastMove(client.username, p.X, p.Y, p.Rot)

	// اکشن شلیک بازیکن (بدون collision، فقط انیمیشن)
	case "shoot":
		if client.username == "" {
			return
		}
		shooter, exists := h.players[client.username]
		if !exists {
			return
		}
		// بررسی rate limiting: همان فاصله‌ای که خودِ کاراکتر/سلاح روی کلاینت
		// هم اعمال می‌شود — یک کلاینتِ دستکاری‌شده نمی‌تواند تندتر از این بزند.
		minGap := time.Duration(statsOf(shooter).FireCooldown * float64(time.Second))
		if !allowPaced(&client.lastShoot, minGap, time.Now()) {
			return
		}
		// جهتِ لحظه‌ی شلیک همراهِ shoot می‌آید و درست قبل از hit می‌رسد.
		// moveها ۲۰ بار در ثانیه‌اند، پس بدونِ این مخروطِ سرور با جهتی تا
		// ۵۰ میلی‌ثانیه قدیمی‌تر چک می‌شد و اولین تیر به هدفِ تازه بی‌صدا رد
		// می‌شد.
		if isFinite(msg.Rot) && math.Abs(msg.Rot) <= 1000 {
			shooter.ClaimedRot = msg.Rot
			h.syncRot(shooter, time.Now())
		}
		h.broadcastShoot(client.username, msg.X, msg.Y, msg.Rot)

	// اکشن ضربه زدن به هدف
	case "hit":
		if client.username == "" || msg.Target == "" {
			return
		}
		shooter, exists := h.players[client.username]
		if !exists {
			return
		}
		// سقفِ سرعتِ ضربه — هم‌ارزِ همان سقفی که روی «shoot» هست.
		//
		// بدونِ این، یک کلاینتِ دستکاری‌شده می‌توانست بدونِ هیچ شلیکی
		// ثانیه‌ای صد بار «زدم» بفرستد و کلِ فرمولِ سرعتِ شلیک را دور
		// بزند. حالا که تیربار واقعاً تندشلیک است، این سقف مهم‌تر هم
		// شده. کمی حاشیه دارد (۱۵٪) تا لرزشِ شبکه شلیکِ سالم را نخورد.
		if gap := time.Duration(statsOf(shooter).FireCooldown * 0.9 * float64(time.Second)); gap > 0 {
			if !allowPaced(&client.lastHit, gap, time.Now()) {
				return
			}
		}
		// شلیک کردن یعنی محافظِ تولدِ خودت تمام است.
		//
		// چرا: validateHit شلیکِ بازیکنِ حصانت‌دار را رد می‌کند (وگرنه
		// می‌شد از داخلِ گنبد بی‌خطر شکار کرد). ولی با محافظِ پنج ثانیه‌ای،
		// معنی‌اش این بود که بعد از هر ریسپاون پنج ثانیه تیرهایت اصلاً
		// ثبت نمی‌شد — بازیکن شلیک می‌کرد و هیچ اتفاقی نمی‌افتاد.
		// حالا انتخاب با خودِ بازیکن است: یا پشتِ گنبد می‌مانی، یا
		// می‌زنی و گنبد همان لحظه می‌رود.
		h.dropSpawnShield(shooter)
		// شیطانِ وسطِ زمین بازیکن نیست، پس در h.players نمی‌گردیم — کلاینت
		// با همین نامِ قراردادی به او شلیک می‌کند و اعتبارسنجی‌اش (برد، خطِ
		// دید، مخروط، تاسِ دقت) در demon.go انجام می‌شود.
		if msg.Target == DemonTarget {
			h.handleDemonHit(shooter)
			return
		}
		if !h.validateHit(shooter, msg.Target) {
			return
		}
		targetPlayer, exists := h.players[msg.Target]
		if !exists {
			return
		}
		// 🌟 دقتِ شلیک (aim_accuracy) این‌جا اعمال می‌شود، نه سمتِ کلاینت —
		// یک کلاینتِ دستکاری‌شده همیشه می‌تواند «زدم» بفرستد، ولی نمی‌تواند
		// این تاسِ سرور را عوض کند.
		if rand.Float64() < statsOf(shooter).MissChance {
			// شلیک‌کننده باید بفهمد تیرش خطا رفت (کلاینت دیگر خودش تاس
			// نمی‌ریزد و ردِ تیر را همیشه تا هدف می‌کشد)
			data, _ := json.Marshal(map[string]interface{}{"type": "hit_miss", "target": msg.Target})
			h.sendTo(client, data)
			return
		}
		// 🌟 مخروطِ نشانه‌روی (control/hand_speed): باید واقعاً رو به هدف
		// باشی. p.Rot سمتِ سرور خودش سقفِ چرخش دارد (بالاتر)، پس این چک
		// قابلِ‌دور‌زدن نیست.
		h.syncRot(shooter, time.Now())
		if !inFireCone(shooter, targetPlayer.X, targetPlayer.Y) {
			return
		}
		// خسارت از «آتشِ» کاراکترِ شلیک‌کننده می‌آید، نه یک عدد ثابت
		h.noteDamage(client.username, msg.Target)
		targetPlayer.Health -= statsOf(shooter).Damage
		if targetPlayer.Health <= 0 {
			targetPlayer.Health = 0
			// آمار همین راند (در رم — پایان بازی با /match/result ذخیره می‌شود)
			shooter.Kills++
			targetPlayer.Deaths++
			h.broadcastHealth(msg.Target, 0)
			h.broadcastDeath(msg.Target, client.username, "gun")
			h.creditKill(client.username, msg.Target)
			h.onPlayerEliminated(msg.Target)
		} else {
			h.broadcastHealth(msg.Target, targetPlayer.Health)
		}

	// اکشن درمان
	case "heal":
		if client.username == "" {
			return
		}
		player, exists := h.players[client.username]
		if !exists || player.Health <= 0 {
			return
		}
		// health_regen (فروشگاه) اینجا واقعی می‌شود: هم مقدار هر بار درمان
		// هم فاصله‌ی بین دو درمان از تراز کاراکترِ خودِ بازیکن می‌آید.
		st := statsOf(player)
		cooldown := time.Duration(st.HealCooldown * float64(time.Second))
		if player.Health >= st.Health || (!player.LastHealTime.IsZero() && time.Since(player.LastHealTime) < cooldown) {
			return
		}
		player.LastHealTime = time.Now()
		player.Health += st.HealAmount
		if player.Health > st.Health {
			player.Health = st.Health
		}
		h.broadcastHealSuccess(client.username, player.Health)
		h.broadcastHealCooldown(client.username, cooldown)

	// اکشن پرتاب بمب
	case "bomb":
		if client.username == "" {
			return
		}
		player, exists := h.players[client.username]
		if !exists || player.Health <= 0 {
			return
		}
		// کول‌داون بر اساس نام کاربری — با join دوباره ریست نمی‌شود
		if last, ok := h.bombCooldowns[client.username]; ok && time.Since(last) < bombCooldown {
			return
		}
		// هر بازیکن در هر مسابقه فقط BombStock بمب دارد
		if h.bombsLeftFor(player) <= 0 {
			return
		}

		// 🛡️ اعتبارسنجی ورودی: هر عددی که از کلاینت می‌آید باید متناهی باشد.
		// بدون این بررسی، فرستادن NaN در dir_x یک اکسپلویت واقعی بود:
		// math.Min(NaN, range) هم NaN می‌شود، مختصات انفجار NaN می‌شد، و چون
		// مقایسه‌ی `NaN > radius` همیشه false است، بررسی فاصله هیچ‌کس را رد
		// نمی‌کرد — یعنی یک بمب به کلِ نقشه آسیب می‌زد.
		if !isFinite(msg.DirectionX) || !isFinite(msg.DirectionY) || !isFinite(msg.Distance) {
			log.Printf("🚫 bomb rejected: non-finite input from %s (dir %v,%v dist %v)",
				client.username, msg.DirectionX, msg.DirectionY, msg.Distance)
			return
		}

		st := statsOf(player)

		// محاسبه موقعیت انفجار براساس جهت
		dirLen := math.Sqrt(msg.DirectionX*msg.DirectionX + msg.DirectionY*msg.DirectionY)
		dirX, dirY := msg.DirectionX, msg.DirectionY
		if dirLen > 0 {
			dirX /= dirLen
			dirY /= dirLen
		} else {
			// جهت صفر: به‌جای انداختن بمب زیر پای خود بازیکن، رو به جلو
			// پرتاب می‌شود — همان جهتی که کلاینت هم نشان می‌دهد.
			dirX = math.Cos(player.Rot - math.Pi/2)
			dirY = math.Sin(player.Rot - math.Pi/2)
		}

		// فاصله‌ای که بازیکن نشانه گرفته. سرور حرف آخر را می‌زند: هرچه
		// کلاینت بفرستد به بردِ کاراکتر محدود می‌شود، پس کسی نمی‌تواند
		// با دست‌کاری کلاینت بمبش را دورتر بیندازد.
		dist := msg.Distance
		if dist <= 0 {
			dist = st.BombRange // کلاینت قدیمی که فاصله نمی‌فرستد
		}
		dist = math.Min(dist, st.BombRange)
		dist = math.Max(dist, minBombRange)

		// بمب هم حمله است: گنبدِ تولد با آن هم می‌رود
		h.dropSpawnShield(player)
		h.bombCooldowns[client.username] = time.Now()
		player.LastBombTime = time.Now()
		h.pruneBombCooldowns()
		h.bombsUsed[bombStockKey(player)]++
		player.BombsLeft = h.bombsLeftFor(player)
		h.broadcastAbility(player, "bomb", 0, bombCooldown, map[string]interface{}{
			"bombs_left": player.BombsLeft,
		})

		expX := player.X + dirX*dist
		expY := player.Y + dirY*dist
		// بمب نباید از دیوار رد شود — جلوی دیوار می‌افتد
		if a := arenaOf(player); a != nil {
			expX, expY = a.RayHitPoint(player.X, player.Y, expX, expY)
		}

		h.broadcastBombThrown(client.username, player.X, player.Y, expX, expY, st.BombRadius)

		// برنامه‌ریزی انفجار برای جلوگیری از data race
		// نامِ پرتاب‌کننده همراه می‌رود تا انفجار فقط در مسابقه‌ی خودش
		// اثر کند و دیده شود
		// مسابقه و تیم همین لحظه‌ی پرتاب ثبت می‌شوند: اگر پرتاب‌کننده وسطِ
		// فیتیله بیرون برود، انفجار نباید به مسابقه‌ی «خالی» (همه‌ی منویی‌ها)
		// بخورد یا هم‌تیمی‌هایش را بزند.
		thrower, mid, team := client.username, player.MatchID, player.Team
		ex, ey, radius, dmg := expX, expY, st.BombRadius, st.BombDamage
		time.AfterFunc(bombDelay, func() {
			h.adminCalls <- func(h *Hub) {
				h.applyBombDamageAs(mid, thrower, team, ex, ey, radius, dmg)
			}
		})

	// اکشن درونی: اعمال خسارت بمب
	case "apply_bomb_damage":
		if client != nil {
			return
		}
		h.applyBombDamageInternal(h.matchIDOf(msg.Username), msg.Username, msg.X, msg.Y, msg.Radius, msg.Damage)

	// توانایی‌های دکمه‌ای — عددها و اعتبارسنجی همه در abilities.go
	case "sprint", "guard", "laser", "team_heal":
		h.handleAbility(client, msg.Type)

	// اندازه‌گیریِ پینگ: همان عددِ کلاینت برمی‌گردد، کلاینت خودش کم می‌کند
	case "ping":
		if client == nil {
			return
		}
		stamp, _ := msg.RawData["t"].(float64)
		data, _ := json.Marshal(map[string]interface{}{"type": "pong", "t": stamp})
		h.sendTo(client, data)

	// خروج از مسابقه وسطِ بازی (دکمه‌ی تنظیمات). سوکت باز می‌ماند — چت و
	// منو هنوز لازمش دارند — ولی از زمین و راند بیرون می‌رود، درست مثلِ
	// قطعِ اتصال؛ وگرنه آدمکش تا آخرِ راند بی‌حرکت وسطِ زمین می‌ماند.
	case "leave_arena":
		if client == nil || client.username == "" {
			return
		}
		if _, ok := h.players[client.username]; !ok {
			return
		}
		mid := h.matchIDOf(client.username)
		h.onPlayerEliminated(client.username)
		delete(h.players, client.username)
		delete(h.playerRound, client.username)
		h.releaseAfterLeaving(client.username, mid)
		fmt.Printf("🚪 Player left the arena: %s\n", client.username)
		h.broadcastPlayerUpdate()

	// اکشن درونی: ماموریت‌ها از دیتابیس رسیدند (match_objectives.go).
	// فقط از خودِ سرور می‌آید — کلاینت نمی‌تواند برای کسی هدف بسازد.
	case "objectives_loaded":
		if client != nil {
			return
		}
		h.onObjectivesLoaded(msg)
	}
}

// syncRot جهتِ سرور را با سرعتِ مجازِ چرخش به سمتِ آخرین جهتِ ادعاشده‌ی
// کلاینت می‌برد. بودجه‌ی چرخش از زمانِ واقعی می‌آید، نه از فاصله‌ی بینِ
// بسته‌ها — بسته‌های به‌هم‌چسبیده‌ی بعد از لگ چرخش را نمی‌خورند.
func (h *Hub) syncRot(p *Player, now time.Time) {
	dt := 1.0
	if !p.RotAt.IsZero() {
		dt = math.Min(now.Sub(p.RotAt).Seconds(), 1.0)
	}
	p.RotAt = now
	if dt <= 0 {
		return
	}
	maxRotDelta := degToRad(statsOf(p).TurnRate) * dt
	p.Rot = math.Remainder(clampRotation(p.Rot, p.ClaimedRot, maxRotDelta), 2*math.Pi)
}

// inFireCone شلیک‌کننده واقعاً رو به هدف است؟ به مخروطِ سلاح، زاویه‌ای که
// بدنِ هدف از این فاصله می‌پوشاند اضافه می‌شود — هدفِ نزدیکِ در حالِ
// حرکت با کمی تأخیرِ شبکه نباید بی‌خود «بیرونِ مخروط» حساب شود.
func inFireCone(shooter *Player, tx, ty float64) bool {
	toTarget := math.Atan2(ty-shooter.Y, tx-shooter.X) + math.Pi/2
	off := math.Abs(angleDiff(shooter.Rot, toTarget))
	dist := math.Max(distance(shooter.X, shooter.Y, tx, ty), 1)
	return off <= degToRad(statsOf(shooter).FireConeDeg)+math.Atan2(playerRadius, dist)
}

// allowPaced سقفِ سرعت با تحملِ لرزش (GCRA): به‌طور میانگین هر gap یک بار،
// ولی یک پیامِ زودرس (تا یک gap) هم پذیرفته می‌شود تا بسته‌های به‌هم‌چسبیده
// بعد از لرزشِ شبکه شلیکِ سالم را نخورند. tat زمانِ «نوبتِ بعدی» است.
func allowPaced(tat *time.Time, gap time.Duration, now time.Time) bool {
	if gap <= 0 {
		return true
	}
	if !tat.IsZero() && now.Before(tat.Add(-gap)) {
		return false
	}
	if tat.Before(now) {
		*tat = now
	}
	*tat = tat.Add(gap)
	return true
}

// isFinite عددِ آمده از کلاینت قابل اعتماد است؟ (نه NaN، نه بی‌نهایت)
func isFinite(v float64) bool {
	return !math.IsNaN(v) && !math.IsInf(v, 0)
}

// pruneBombCooldowns ردیف‌های منقضی را پاک می‌کند تا نقشه با بازیکن‌هایی که
// دیگر برنمی‌گردند بی‌نهایت بزرگ نشود.
func (h *Hub) pruneBombCooldowns() {
	if len(h.bombCooldowns) < 256 {
		return
	}
	for name, t := range h.bombCooldowns {
		if time.Since(t) > bombCooldown {
			delete(h.bombCooldowns, name)
		}
	}
}

// applyBombDamageInternal خسارت بمب را به تمام بازیکن‌های در شعاع اعمال می‌کند
func (h *Hub) applyBombDamageInternal(matchID, throwerName string, expX, expY, radius float64, damage int) {
	// خط دفاعی دوم: حتی اگر از جایی مقدار خراب رسید، مقایسه‌ی فاصله با NaN
	// همیشه false می‌شود و به همه آسیب می‌خورد. پس اینجا هم بررسی می‌کنیم.
	if !isFinite(expX) || !isFinite(expY) || !isFinite(radius) || radius <= 0 {
		log.Printf("🚫 bomb explosion dropped: bad geometry (%v,%v r=%v)", expX, expY, radius)
		return
	}
	h.broadcastBombExplosion(matchID, expX, expY, radius)

	team := ""
	if p, ok := h.players[throwerName]; ok && p.MatchID == matchID {
		team = p.Team
	}
	h.applyBombDamageAs(matchID, throwerName, team, expX, expY, radius, damage)
}

// applyBombDamageAs همان انفجار با تیمِ ثبت‌شده‌ی لحظه‌ی پرتاب.
func (h *Hub) applyBombDamageAs(matchID, throwerName, throwerTeam string, expX, expY, radius float64, damage int) {
	if !isFinite(expX) || !isFinite(expY) || !isFinite(radius) || radius <= 0 {
		return
	}
	// پرتاب‌کننده را پیدا کن (برای ثبتِ کشته)؛ ممکن است رفته باشد
	var thrower *Player
	if p, ok := h.players[throwerName]; ok && p.MatchID == matchID {
		thrower = p
	}

	for _, player := range h.players {
		// بمب فقط در همان مسابقه اثر دارد
		if player.MatchID != matchID {
			continue
		}
		// آتشِ خودی ممنوع — بمبِ هم‌تیمی هم نباید بزند
		if throwerTeam != "" && player.Team == throwerTeam {
			continue
		}
		// محافظِ تولد و سپرِ دستی هر دو جلوی ترکش را می‌گیرند
		if !canBeHurt(player, time.Now()) {
			continue
		}

		if distance(expX, expY, player.X, player.Y) > radius {
			continue
		}
		// موج انفجار از دیوار رد نمی‌شود
		if a := arenaOf(player); a != nil && !a.HasLineOfSight(expX, expY, player.X, player.Y) {
			continue
		}
		// مرگ با بمب هم از همان مسیرِ مشترک ثبت می‌شود (کشته، امتیاز، پایانِ
		// راند) و «کشته با نارنجک» برای ماموریت‌ها جدا شمرده می‌شود
		h.applyDamage(thrower, player, damage, true)
	}
}

// ============== Broadcast Methods ==============
// این methods پیام‌ها را به تمام clients broadcast می‌کنند

// matchIDOf شناسه‌ی مسابقه‌ی یک بازیکن. خالی یعنی خارج از ماچ‌میکینگ.
// humansLeftInMatchOf چند آدم (نه بات) هنوز در این مسابقه‌اند.
// بعد از پاک شدنِ خودِ قطع‌شده از h.players صدا زده می‌شود.
func (h *Hub) humansLeftInMatchOf(matchID string) int {
	if matchID == "" {
		return 0
	}
	n := 0
	for name, p := range h.players {
		if p.MatchID != matchID {
			continue
		}
		if _, isBot := h.bots[name]; !isBot {
			n++
		}
	}
	return n
}

func (h *Hub) matchIDOf(username string) string {
	if p, ok := h.players[username]; ok {
		return p.MatchID
	}
	return ""
}

// queueBroadcastTo پیام را فقط به کلاینت‌های همان مسابقه می‌فرستد.
//
// این هسته‌ی جداسازیِ مسابقه‌هاست: قبلاً هر پیامی به همه‌ی متصل‌ها می‌رفت،
// پس هر اکانتی که سوکتش باز بود در زمینِ بقیه ظاهر می‌شد — حتی اگر اصلاً
// سرچ نکرده بود.
func (h *Hub) queueBroadcastTo(matchID string, message []byte) {
	for client := range h.clients {
		if client.username == "" {
			continue
		}
		p, ok := h.players[client.username]
		if !ok || p.MatchID != matchID {
			continue
		}
		// «مسابقه‌ی خالی» (تمرینِ بی‌ماچ) فقط مالِ کسانی است که واقعاً
		// وارد زمین شده‌اند — سوکت‌های منو پیامِ بازی لازم ندارند.
		if matchID == "" && !p.InArena {
			continue
		}
		select {
		case client.send <- message:
		default:
			h.dropClient(client)
		}
	}
}

// broadcastPlayerUpdate لیستِ بازیکن‌ها را می‌فرستد — ولی هر مسابقه فقط
// لیستِ خودش را می‌بیند، نه کلِ سرور را.
func (h *Hub) broadcastPlayerUpdate() {
	now := time.Now()
	byMatch := map[string]map[string]*Player{}
	for name, p := range h.players {
		// محافظِ تولد قبل از هر پخش تازه می‌شود؛ همه‌ی گوروتین‌ها روی
		// همین حلقه‌اند پس نوشتنش این‌جا امن است
		p.ShieldLeft = 0
		if left := p.InvulnerableUntil.Sub(now).Seconds(); left > 0 {
			p.ShieldLeft = left
		}
		refreshAbilityTimers(p, now)
		if p.MatchID == "" && !p.InArena {
			continue
		}
		if byMatch[p.MatchID] == nil {
			byMatch[p.MatchID] = map[string]*Player{}
		}
		byMatch[p.MatchID][name] = p
	}
	for mid, players := range byMatch {
		data, _ := json.Marshal(map[string]interface{}{
			"type": "update_players", "players": players})
		h.queueBroadcastTo(mid, data)
	}
}

// sendSpawn نقطه‌ی شروع + اینکه این مسابقه روی کدام زمین و با کدام تم است و
// چند ثانیه محافظِ تولد دارد. کلاینت نقشه و تم را از همین می‌فهمد، نه از
// حدسِ خودش. تمِ خالی یعنی مسابقه‌ای نیست (تمرین) و کلاینت از رنکِ خودش
// تم می‌گیرد.
func (h *Hub) sendSpawn(client *Client, x, y float64, mapName, theme string, shield time.Duration) {
	data, _ := json.Marshal(map[string]interface{}{
		"type": "spawn", "x": x, "y": y,
		"map":            mapName,
		"theme":          theme,
		"shield_seconds": shield.Seconds(),
	})
	h.sendTo(client, data)
}

// sendCorrection موقعیت اصلاح‌شده را به کلاینت خاطی برمی‌گرداند.
// کلاینت باید بی‌چون‌وچرا خودش را به اینجا اسنپ کند.
func (h *Hub) sendCorrection(client *Client, x, y float64) {
	data, _ := json.Marshal(map[string]interface{}{"type": "position_correction", "x": x, "y": y})
	h.sendTo(client, data)
}

// sendTo پیام را فقط برای یک کلاینت می‌فرستد
func (h *Hub) sendTo(client *Client, message []byte) {
	if client == nil {
		return
	}
	if client.closed {
		return
	}
	select {
	case client.send <- message:
	default:
		h.dropClient(client)
	}
}

// broadcastMove حرکت بازیکن را broadcast می‌کند
func (h *Hub) broadcastMove(username string, x, y, rot float64) {
	data, _ := json.Marshal(map[string]interface{}{"type": "move", "username": username, "x": x, "y": y, "rot": rot})
	h.queueBroadcastTo(h.matchIDOf(username), data)
}

// broadcastShoot انیمیشن شلیک را broadcast می‌کند
func (h *Hub) broadcastShoot(shooter string, x, y, rot float64) {
	data, _ := json.Marshal(map[string]interface{}{"type": "shoot", "username": shooter, "x": x, "y": y, "rot": rot})
	h.queueBroadcastTo(h.matchIDOf(shooter), data)
	// صدای شلیک: بات‌های حریفِ اطراف می‌شنوند و می‌آیند سراغش. این تنها
	// راهی است که یک بازیکنِ ساکت را در نقشه‌ی تاریک پیدا می‌کنند — بدونِ
	// آن، بات دیگر جای کسی را از قبل نمی‌داند و درگیری‌ها شکل نمی‌گیرد.
	h.alertBotsToShot(shooter)
}

// broadcastHealth بروزرسانی سلامت بازیکن را ارسال می‌کند
func (h *Hub) broadcastHealth(target string, health int) {
	data, _ := json.Marshal(map[string]interface{}{"type": "health_update", "username": target, "health": health})
	h.queueBroadcastTo(h.matchIDOf(target), data)
}

// broadcastDeath مرگ بازیکن را اطلاع می‌رسد. killer/weapon اختیاری‌اند
// (کلاینت‌های قدیمی نادیده‌شان می‌گیرند) تا کارتِ قاتل و «انتقام/خاموش کردن»
// روی کلاینت حدس نزنند — weapon یکی از gun/bomb/laser/demon است.
func (h *Hub) broadcastDeath(target, killer, weapon string) {
	msg := map[string]interface{}{"type": "die", "username": target}
	if killer != "" {
		msg["killer"] = killer
	}
	if weapon != "" {
		msg["weapon"] = weapon
	}
	data, _ := json.Marshal(msg)
	h.queueBroadcastTo(h.matchIDOf(target), data)
}

// broadcastCountdown شمارش معکوس را ارسال می‌کند
func (h *Hub) broadcastCountdown(matchID string, seconds int) {
	data, _ := json.Marshal(map[string]interface{}{"type": "countdown", "seconds": seconds})
	h.queueBroadcastTo(matchID, data)
}

// broadcastGameStart سیگنال شروع بازی را ارسال می‌کند
func (h *Hub) broadcastGameStart(matchID string) {
	data, _ := json.Marshal(map[string]interface{}{"type": "game_start"})
	h.queueBroadcastTo(matchID, data)
}

// broadcastHealSuccess موفقیت درمان را اطلاع می‌رسد
func (h *Hub) broadcastHealSuccess(username string, newHealth int) {
	data, _ := json.Marshal(map[string]interface{}{"type": "heal_success", "username": username, "health": newHealth})
	h.queueBroadcastTo(h.matchIDOf(username), data)
}

// broadcastHealCooldown cooldown درمان را اطلاع می‌رسد
func (h *Hub) broadcastHealCooldown(username string, cooldown time.Duration) {
	data, _ := json.Marshal(map[string]interface{}{
		"type":     "heal_cooldown",
		"username": username,
		"seconds":  int(math.Round(cooldown.Seconds())),
	})
	h.queueBroadcastTo(h.matchIDOf(username), data)
}

// broadcastBombThrown پرتاب بمب را broadcast می‌کند
func (h *Hub) broadcastBombThrown(shooter string, startX, startY, expX, expY, radius float64) {
	data, _ := json.Marshal(map[string]interface{}{
		"type":        "bomb_thrown",
		"username":    shooter,
		"start_x":     startX,
		"start_y":     startY,
		"explosion_x": expX,
		"explosion_y": expY,
		"bomb_radius": radius,
	})
	h.queueBroadcastTo(h.matchIDOf(shooter), data)
}

// broadcastBombExplosion انفجار بمب را broadcast می‌کند
func (h *Hub) broadcastBombExplosion(matchID string, expX, expY, radius float64) {
	data, _ := json.Marshal(map[string]interface{}{
		"type":             "bomb_explosion",
		"explosion_x":      expX,
		"explosion_y":      expY,
		"explosion_radius": radius,
	})
	h.queueBroadcastTo(matchID, data)
}

// queueBroadcast پیام را به تمام clients ارسال می‌کند
func (h *Hub) queueBroadcast(message []byte) {
	for client := range h.clients {
		select {
		case client.send <- message:
		default:
			h.dropClient(client)
		}
	}
}

// ============== WebSocket Connection Management ==============

// readPump پیام‌های ورودی را از کلاینت می‌خواند و به Hub ارسال می‌کند
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	// تنظیمات WebSocket
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	// سقفِ پیام برای هر اتصال (سطلِ توکن): کلاینتِ سالم حدودِ ۲۰-۶۰ پیام در
	// ثانیه می‌فرستد؛ اسپمِ join/equip/ping دیگر نمی‌تواند هاب را خفه کند.
	const msgRate, msgBurst = 120.0, 240.0
	tokens, lastRefill := msgBurst, time.Now()
	// join و equip کوئریِ دیتابیس دارند: سطلِ کوچکِ جدا (۲ در ثانیه، تا ۴
	// پشتِ‌سرِهم). قبلاً «۲۵۰ میلی‌ثانیه فاصله» بود و joinِ آرنا که همان
	// فریمِ joinِ منو می‌رسید بی‌صدا دور ریخته می‌شد — زمینِ خالی.
	heavyTokens, heavyAt := 4.0, time.Now()
	// joinedAs آخرین نامی که این سوکت با آن join فرستاده. c.username را این‌جا
	// نمی‌خوانیم چون روی گوروتینِ هاب نوشته می‌شود (مسابقه‌ی داده‌ای).
	joinedAs := ""

	// حلقه خواندن پیام‌ها
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}

		// پارس JSON پیام
		var raw map[string]interface{}
		if err := json.Unmarshal(message, &raw); err != nil {
			continue
		}

		msg := parseWSMessage(raw)

		now := time.Now()
		tokens = math.Min(msgBurst, tokens+now.Sub(lastRefill).Seconds()*msgRate)
		lastRefill = now
		if tokens < 1 {
			continue
		}
		tokens--
		// join و equip کوئریِ دیتابیس دارند — حداکثر چهار بار در ثانیه
		if msg.Type == "join" || msg.Type == "equip" {
			heavyTokens = math.Min(4, heavyTokens+now.Sub(heavyAt).Seconds()*2)
			heavyAt = now
			if heavyTokens < 1 {
				continue
			}
			heavyTokens--
		}

		// هر حسابی که دستگاهی ثبت کرده — مهمان یا گوگلی — فقط با
		// توکن دستگاه وارد هاب می‌شود
		// (handlers_auth.go). این‌جا روی گوروتینِ خودِ کلاینت است، پس
		// خواندن از دیتابیس حلقه‌ی هاب را معطل نمی‌کند.
		if msg.Type == "join" {
			token, _ := raw["token"].(string)
			if !wsJoinAllowed(msg.Username, token) {
				log.Printf("🔒 join rejected for protected account %q (bad token)", msg.Username)
				continue
			}
		}
		// تجهیزات همین‌جا (بیرون از هاب) از دیتابیس خوانده می‌شود
		if msg.Type == "join" || msg.Type == "equip" {
			name := msg.Username
			if msg.Type == "join" {
				joinedAs = name
			} else {
				name = joinedAs // هاب دوباره با client.username تطبیق می‌دهد
			}
			if name != "" {
				ch, wp, lv, cs, ws := equippedFor(name, msg.CharID, msg.Weapon)
				msg.loadout = &loadoutInfo{ch, wp, lv, cs, ws}
				msg.Username = name
			}
		}

		// ارسال اکشن به Hub
		c.hub.actions <- hubAction{client: c, msg: msg}
	}
}

// parseWSMessage فیلدهای پیامِ کلاینت را از JSON خام برمی‌دارد.
// تگ‌های json روی WSMessage اینجا استفاده نمی‌شوند، پس هر فیلد تازه‌ای که
// کلاینت می‌فرستد باید همین‌جا هم اضافه شود — جا افتادنِ dist یک بار باعث
// شد بمب همیشه ته بردش بیفتد. جدا شده تا تست بتواند مستقیم صدایش بزند.
func parseWSMessage(raw map[string]interface{}) WSMessage {
	msg := WSMessage{RawData: raw}
	if t, ok := raw["type"].(string); ok {
		msg.Type = t
	}
	if u, ok := raw["username"].(string); ok {
		msg.Username = u
	}
	if tgt, ok := raw["target"].(string); ok {
		msg.Target = tgt
	}
	if xVal, ok := raw["x"].(float64); ok {
		msg.X = xVal
	}
	if yVal, ok := raw["y"].(float64); ok {
		msg.Y = yVal
	}
	if rVal, ok := raw["rot"].(float64); ok {
		msg.Rot = rVal
	}
	if cVal, ok := raw["character"].(string); ok {
		msg.CharID = cVal
	}
	if wVal, ok := raw["weapon"].(string); ok {
		msg.Weapon = wVal
	}
	// این تابع فیلدها را دستی از map برمی‌دارد، پس اضافه کردنِ فیلد به
	// WSMessage به‌تنهایی کافی نیست — بدونِ این خط، arena همیشه false
	// می‌ماند و راند هیچ‌وقت شروع نمی‌شود.
	if aVal, ok := raw["arena"].(bool); ok {
		msg.Arena = aVal
	}
	if dxVal, ok := raw["dir_x"].(float64); ok {
		msg.DirectionX = dxVal
	}
	if dyVal, ok := raw["dir_y"].(float64); ok {
		msg.DirectionY = dyVal
	}
	// فاصله‌ای که بازیکن برای بمب نشانه گرفته. این یکی جا افتاده بود و
	// همین باعث می‌شد msg.Distance همیشه صفر بماند و هندلر بمب به
	// «برد بیشینه» برگردد — یعنی بمب هر جا که نشانه می‌گرفتی، آخرِ برد
	// می‌افتاد. تگ‌های json روی WSMessage اینجا استفاده نمی‌شوند، پس هر
	// فیلد تازه باید دستی همین‌جا هم اضافه شود.
	if distVal, ok := raw["dist"].(float64); ok {
		msg.Distance = distVal
	}
	// عمداً radius / damage / health از کلاینت خوانده نمی‌شوند: آن‌ها را
	// فقط سرور تعیین می‌کند، وگرنه کلاینتِ دستکاری‌شده می‌توانست خسارت
	// و شعاع بمبش را خودش بنویسد.
	return msg
}

// writePump پیام‌های خروجی را به کلاینت ارسال می‌کند
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		// ارسال پیام
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}

			w.Write(message)

			// بهینه‌سازی: تمام پیام‌های موجود در کانال را یکباره ارسال کنید
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		// ارسال ping برای نگه‌داری اتصال
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ServeWs درخواست WebSocket را handle می‌کند و اتصال را upgrade می‌کند
func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("upgrade error:", err)
		return
	}

	client := &Client{
		hub:  hub,
		conn: conn,
		send: make(chan []byte, 256),
	}

	client.hub.register <- client

	// اجرای pump‌ها در Goroutines جداگانه
	go client.writePump()
	go client.readPump()
}
