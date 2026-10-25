package main

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base32"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// پنل مدیریت — لایه‌های امنیتی
// =============================================================================
//
//   - رمز در .env فقط به‌صورت هش PBKDF2 است (ADMIN_ACCOUNTS=parsa:admin:pbkdf2-sha256$...)
//     تا اگر فایل .env لو رفت، رمز لو نرود. هش را با `gun_game_server admin-hash` بسازید.
//   - کد دومرحله‌ای (TOTP، مثل Google Authenticator): ADMIN_TOTP_<USER>=<base32>
//     با ADMIN_REQUIRE_TOTP=1 حسابِ بدون کد اصلاً وارد نمی‌شود.
//   - آدرس پنل مخفی: ADMIN_PATH=/panel-xxxx (پیش‌فرض /admin)
//   - قفل سراسری ورود: اگر در ۱۵ دقیقه بیش از ۲۰ ورود ناموفق از هر جا بیاید،
//     ورود ۱۵ دقیقه بسته می‌شود (جلوی حدس‌زدنِ پخش‌شده از آی‌پی‌های مختلف).
//   - قفل اضطراری (دکمه‌ی «هک شدم»): همه‌ی نشست‌ها باطل و ورود بسته می‌شود.
//     فقط از روی خودِ سرور (SSH) باز می‌شود: `gun_game_server admin-unlock`.
//     با کلید اضطراری (ADMIN_PANIC_KEY_SHA256) بدون ورود هم می‌شود قفلش کرد.

const (
	adminHashPrefix     = "pbkdf2-sha256$"
	adminHashIterations = 600_000
	colAdminState       = "admin_state"
	adminLockDocID      = "lockdown"

	adminGlobalFailLimit  = 20
	adminGlobalFailWindow = 15 * time.Minute
	adminIdleTimeout      = time.Hour
)

// adminBasePath مسیرِ پنل؛ همیشه با / شروع و بدون / آخر
func adminBasePath() string {
	p := strings.TrimSpace(os.Getenv("ADMIN_PATH"))
	if p == "" {
		return "/admin"
	}
	if !strings.HasPrefix(p, "/") {
		p = "/" + p
	}
	return strings.TrimRight(p, "/")
}

// ------------------------------------------------------------ هش رمز

func hashAdminPassword(password string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key, err := pbkdf2.Key(sha256.New, password, salt, adminHashIterations, 32)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s%d$%s$%s", adminHashPrefix, adminHashIterations,
		base64.RawStdEncoding.EncodeToString(salt), base64.RawStdEncoding.EncodeToString(key)), nil
}

// verifyAdminPassword رمزِ ذخیره‌شده هش است یا (فقط برای توسعه‌ی محلی) متن ساده
func verifyAdminPassword(stored, password string) bool {
	if !strings.HasPrefix(stored, adminHashPrefix) {
		if os.Getenv("ADMIN_REQUIRE_HASH") == "1" {
			return false
		}
		a, b := sha256.Sum256([]byte(stored)), sha256.Sum256([]byte(password))
		return subtle.ConstantTimeCompare(a[:], b[:]) == 1
	}
	parts := strings.Split(strings.TrimPrefix(stored, adminHashPrefix), "$")
	if len(parts) != 3 {
		return false
	}
	iter, err := strconv.Atoi(parts[0])
	if err != nil || iter < 100_000 {
		return false
	}
	salt, err1 := base64.RawStdEncoding.DecodeString(parts[1])
	want, err2 := base64.RawStdEncoding.DecodeString(parts[2])
	if err1 != nil || err2 != nil {
		return false
	}
	got, err := pbkdf2.Key(sha256.New, password, salt, iter, len(want))
	return err == nil && subtle.ConstantTimeCompare(got, want) == 1
}

// ------------------------------------------------------------ کد دومرحله‌ای

func adminTOTPSecret(user string) string {
	return strings.ToUpper(strings.TrimSpace(os.Getenv("ADMIN_TOTP_" + strings.ToUpper(user))))
}

func totpAt(secret []byte, step int64) string {
	var msg [8]byte
	binary.BigEndian.PutUint64(msg[:], uint64(step))
	mac := hmac.New(sha1.New, secret)
	mac.Write(msg[:])
	sum := mac.Sum(nil)
	off := sum[len(sum)-1] & 0x0f
	code := (binary.BigEndian.Uint32(sum[off:off+4]) & 0x7fffffff) % 1_000_000
	return fmt.Sprintf("%06d", code)
}

var (
	totpUsedMu sync.Mutex
	totpUsed   = map[string]int64{} // user → آخرین step مصرف‌شده (جلوی استفاده‌ی دوباره از یک کد)
)

// verifyTOTP کد ۶ رقمی با یک پله‌ی ۳۰ ثانیه‌ای ارفاق در هر طرف؛ هر کد فقط یک بار
func verifyTOTP(user, secretB32, code string, now time.Time) bool {
	code = strings.TrimSpace(code)
	if len(code) != 6 {
		return false
	}
	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(strings.TrimRight(secretB32, "="))
	if err != nil || len(secret) < 10 {
		return false
	}
	step := now.Unix() / 30
	totpUsedMu.Lock()
	defer totpUsedMu.Unlock()
	for d := int64(-1); d <= 1; d++ {
		s := step + d
		if subtle.ConstantTimeCompare([]byte(totpAt(secret, s)), []byte(code)) == 1 {
			if s <= totpUsed[user] {
				return false
			}
			totpUsed[user] = s
			return true
		}
	}
	return false
}

func newTOTPSecret() string {
	b := make([]byte, 20)
	_, _ = rand.Read(b)
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(b)
}

// ------------------------------------------------------------ قفل سراسری ورود

var adminFails = struct {
	sync.Mutex
	at          []time.Time
	lockedUntil time.Time
}{}

// adminLoginBlocked ورود به‌خاطر حمله‌ی حدس‌زدن موقتاً بسته است؟
func adminLoginBlocked(now time.Time) bool {
	adminFails.Lock()
	defer adminFails.Unlock()
	return now.Before(adminFails.lockedUntil)
}

// adminLoginFailed یک ورود ناموفق؛ true یعنی همین الان قفل سراسری فعال شد
func adminLoginFailed(now time.Time) bool {
	adminFails.Lock()
	defer adminFails.Unlock()
	kept := adminFails.at[:0]
	for _, t := range adminFails.at {
		if now.Sub(t) < adminGlobalFailWindow {
			kept = append(kept, t)
		}
	}
	adminFails.at = append(kept, now)
	if len(adminFails.at) >= adminGlobalFailLimit && !now.Before(adminFails.lockedUntil) {
		adminFails.lockedUntil = now.Add(adminGlobalFailWindow)
		adminFails.at = nil
		return true
	}
	return false
}

// ------------------------------------------------------------ قفل اضطراری

var adminLockdown atomic.Bool

type adminLockState struct {
	ID       string    `bson:"_id" json:"-"`
	Locked   bool      `bson:"locked" json:"locked"`
	By       string    `bson:"by" json:"by"`
	Reason   string    `bson:"reason" json:"reason"`
	At       time.Time `bson:"at" json:"at"`
	IP       string    `bson:"ip" json:"ip"`
	Unlocked time.Time `bson:"unlocked_at,omitempty" json:"-"`
}

// loadAdminLockdown موقع بالا آمدن سرور؛ خطای دیتابیس = قفل (سختگیرانه)
func loadAdminLockdown(ctx context.Context) {
	var st adminLockState
	err := col(colAdminState).FindOne(ctx, bson.M{"_id": adminLockDocID}).Decode(&st)
	switch {
	case err == mongo.ErrNoDocuments:
		adminLockdown.Store(false)
	case err != nil:
		fmt.Println("⚠️ Admin lockdown state unreadable — panel stays LOCKED:", err)
		adminLockdown.Store(true)
	default:
		adminLockdown.Store(st.Locked)
		if st.Locked {
			fmt.Println("🔒 Admin panel is in EMERGENCY LOCKDOWN (run: gun_game_server admin-unlock)")
		}
	}
}

// engageLockdown همه‌ی نشست‌ها را باطل می‌کند و ورود را می‌بندد
func engageLockdown(ctx context.Context, by, reason, ip string) {
	adminLockdown.Store(true)
	adminSessions.dropAll()
	_, _ = col(colAdminState).UpdateOne(ctx, bson.M{"_id": adminLockDocID},
		bson.M{"$set": bson.M{"locked": true, "by": by, "reason": reason, "at": time.Now(), "ip": ip}},
		options.Update().SetUpsert(true))
}

type panicRequest struct {
	PanicKey      string `json:"panic_key"`
	Reason        string `json:"reason"`
	DisableGifts  bool   `json:"disable_gift_codes"`
	RevokeRewards bool   `json:"revoke_recent_rewards"`
	RevokeHours   int    `json:"revoke_hours"`
}

// POST {base}/api/panic — با نشستِ معتبر (هر نقشی) یا با کلید اضطراری
func adminPanicHandler(w http.ResponseWriter, r *http.Request) {
	adminSecurityHeaders(w)
	if !adminPanelEnabled() {
		http.NotFound(w, r)
		return
	}
	var req panicRequest
	r.Body = http.MaxBytesReader(w, r.Body, 8192)
	if !adminDecode(w, r, &req) {
		return
	}
	ip := clientIP(r)
	who := ""
	if sess := sessionFromRequest(r); sess != nil &&
		subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Admin-CSRF")), []byte(sess.CSRF)) == 1 {
		who = sess.User
	} else if req.PanicKey != "" {
		if !adminLoginIPLimiter.allow(ip) {
			tooManyRequests(w, 60)
			return
		}
		want := strings.ToLower(strings.TrimSpace(os.Getenv("ADMIN_PANIC_KEY_SHA256")))
		got := sha256.Sum256([]byte(strings.TrimSpace(req.PanicKey)))
		if want == "" || subtle.ConstantTimeCompare([]byte(hex.EncodeToString(got[:])), []byte(want)) != 1 {
			time.Sleep(400 * time.Millisecond)
			writeAudit(r.Context(), r, &adminSession{User: "?"}, "panic_key_failed", "", nil)
			httpError(w, "کلید اضطراری نادرست است", http.StatusForbidden)
			return
		}
		who = "panic-key"
	} else {
		httpError(w, "وارد نشده‌اید و کلید اضطراری هم نفرستادید", http.StatusUnauthorized)
		return
	}

	ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 30*time.Second)
	defer cancel()
	engageLockdown(ctx, who, strings.TrimSpace(req.Reason), ip)
	result := map[string]interface{}{"locked": true}

	if req.DisableGifts {
		res, err := col(ColGiftCodes).UpdateMany(ctx, bson.M{"active": true}, bson.M{"$set": bson.M{"active": false}})
		if err == nil {
			result["gift_codes_disabled"] = res.ModifiedCount
		}
	}
	if req.RevokeRewards {
		hours := req.RevokeHours
		if hours <= 0 || hours > 24*7 {
			hours = 24
		}
		res, err := col(ColMessages).DeleteMany(ctx, bson.M{
			"sender_id":      adminSenderID,
			"reward":         bson.M{"$ne": nil},
			"reward_claimed": false,
			"created_at":     bson.M{"$gte": time.Now().Add(-time.Duration(hours) * time.Hour)},
		})
		if err == nil {
			result["reward_messages_deleted"] = res.DeletedCount
		}
	}
	details := map[string]interface{}{"reason": req.Reason}
	for k, v := range result {
		details[k] = v
	}
	writeAudit(ctx, r, &adminSession{User: who}, "panic_lockdown", "", details)
	fmt.Printf("🚨 ADMIN EMERGENCY LOCKDOWN by %s from %s\n", who, ip)
	http.SetCookie(w, &http.Cookie{Name: adminCookieName, Value: "", Path: adminBasePath(), MaxAge: -1, HttpOnly: true})
	jsonResponse(w, result)
}

// ------------------------------------------------------------ صفحه‌ی امنیت

// GET {base}/api/security — نشست‌های فعال، ورودهای اخیر، وضعیت قفل
func adminSecurityHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	me := adminFrom(r)
	jsonResponse(w, map[string]interface{}{
		"sessions": adminSessions.list(me),
		"logins": findAll[AdminAuditEntry](ctx, ColAdminAudit,
			bson.M{"action": bson.M{"$in": []string{"login", "login_failed", "panic_key_failed", "panic_lockdown", "logout_all"}}}, "at", 40),
		"totp_enabled":  adminTOTPSecret(me.User) != "",
		"panic_key_set": os.Getenv("ADMIN_PANIC_KEY_SHA256") != "",
		"hashed":        os.Getenv("ADMIN_REQUIRE_HASH") == "1",
	})
}

// POST {base}/api/security/logout_all — همه‌ی نشست‌ها به جز همین یکی
func adminLogoutAllHandler(w http.ResponseWriter, r *http.Request) {
	me := adminFrom(r)
	n := adminSessions.dropAllExcept(me)
	audit(r, "logout_all", "", map[string]interface{}{"sessions": n})
	jsonResponse(w, map[string]interface{}{"success": true, "dropped": n})
}

// ------------------------------------------------------------ فرمان‌های خط فرمان

// runAdminCLI فرمان‌های نگهداری؛ true یعنی فرمانی اجرا شد و برنامه باید تمام شود.
//
//	gun_game_server admin-hash      رمز را از ورودی می‌خواند و هش را چاپ می‌کند
//	gun_game_server admin-totp USER کلید دومرحله‌ای تازه برای اپ Authenticator
//	gun_game_server admin-panickey  کلید اضطراری تازه + هشی که در .env می‌رود
//	gun_game_server admin-unlock    باز کردنِ قفل اضطراری (فقط از روی سرور)
func runAdminCLI(args []string) bool {
	if len(args) < 2 {
		return false
	}
	switch args[1] {
	case "admin-hash":
		fmt.Fprint(os.Stderr, "password: ")
		line, _ := bufio.NewReader(os.Stdin).ReadString('\n')
		pw := strings.TrimRight(line, "\r\n")
		if len(pw) < 12 {
			fmt.Fprintln(os.Stderr, "password must be at least 12 characters")
			os.Exit(1)
		}
		h, err := hashAdminPassword(pw)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println(h)
	case "admin-totp":
		user := "admin"
		if len(args) > 2 {
			user = args[2]
		}
		secret := newTOTPSecret()
		fmt.Printf("ADMIN_TOTP_%s=%s\n", strings.ToUpper(user), secret)
		fmt.Printf("otpauth://totp/GunGame:%s?secret=%s&issuer=GunGame\n", url.PathEscape(user), secret)
	case "admin-panickey":
		b := make([]byte, 24)
		_, _ = rand.Read(b)
		key := base64.RawURLEncoding.EncodeToString(b)
		sum := sha256.Sum256([]byte(key))
		fmt.Println("KEY (keep offline):", key)
		fmt.Printf("ADMIN_PANIC_KEY_SHA256=%s\n", hex.EncodeToString(sum[:]))
	case "admin-unlock":
		cliUnlock()
	default:
		return false
	}
	return true
}

func cliUnlock() {
	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	client, err := mongo.Connect(ctx, options.Client().ApplyURI(uri))
	if err != nil {
		fmt.Fprintln(os.Stderr, "mongo:", err)
		os.Exit(1)
	}
	defer client.Disconnect(ctx)
	_, err = client.Database("gun_game_db").Collection(colAdminState).UpdateOne(ctx,
		bson.M{"_id": adminLockDocID}, bson.M{"$set": bson.M{"locked": false, "unlocked_at": time.Now()}})
	if err != nil {
		fmt.Fprintln(os.Stderr, "unlock failed:", err)
		os.Exit(1)
	}
	_, _ = client.Database("gun_game_db").Collection(ColAdminAudit).InsertOne(ctx, AdminAuditEntry{
		At: time.Now(), Admin: "server-cli", Action: "panic_unlock", IP: "local",
	})
	fmt.Println("✅ unlocked. Now rotate passwords/TOTP in .env if needed, then: systemctl restart gungame")
}
