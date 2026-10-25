package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// پنل مدیریت — ورود، نشست و ثبت کارها
// =============================================================================
//
// پنل یک صفحه‌ی وب است که داخل همین باینری embed شده و روی /admin/ سرو
// می‌شود؛ API آن زیر /admin/api/ است. هیچ‌کدام از authGuard بازیکن رد
// نمی‌شوند چون بدنه‌هایشان فیلد username دارد که مال ادمین نیست.
//
// حساب‌ها از .env می‌آیند (بدون آن پنل کاملاً خاموش است):
//
//	ADMIN_ACCOUNTS=parsa:admin:<رمز>,ali:support:<رمز>
//
// نقش admin همه‌کار می‌کند. نقش support فقط پشتیبانی، پیام، چت و خواندن
// اطلاعات بازیکن را دارد — به اقتصاد، مسدودیت دائمی، کد هدیه و تنظیمات
// بازی دست نمی‌زند.
//
// امنیت:
//   - نشست در حافظه (ری‌استارت = ورود دوباره)، کوکی HttpOnly + SameSite=Strict
//   - هر POST باید هدر X-Admin-CSRF برابرِ توکنِ همان نشست داشته باشد
//   - ورود ناموفق سهمیه‌ی تنگ دارد (هر آی‌پی و هر نام کاربری)
//   - هر تغییری در کالکشن admin_audit ثبت می‌شود

const (
	ColAdminAudit     = "admin_audit"     // ثبت همه‌ی کارهای ادمین‌ها
	ColAdminNotes     = "admin_notes"     // یادداشت داخلی روی بازیکن
	ColAdminCampaigns = "admin_campaigns" // پیام‌های گروهی/همگانی ارسال‌شده

	adminRoleAdmin   = "admin"
	adminRoleSupport = "support"

	adminCookieName   = "gg_admin"
	adminSessionTTL   = 12 * time.Hour
	adminMaxBodyBytes = 1 << 20
)

//go:embed admin_panel
var adminPanelFS embed.FS

var adminStartedAt = time.Now()

// ------------------------------------------------------------ حساب‌ها

type adminAccount struct {
	User     string
	Role     string
	Password string
}

// loadAdminAccounts هر بار از محیط می‌خواند؛ تعدادشان کم است و این‌طور
// عوض کردنِ .env با ری‌استارت کافی است.
func loadAdminAccounts() []adminAccount {
	raw := strings.TrimSpace(os.Getenv("ADMIN_ACCOUNTS"))
	if raw == "" {
		return nil
	}
	out := []adminAccount{}
	for _, part := range strings.Split(raw, ",") {
		fields := strings.SplitN(strings.TrimSpace(part), ":", 3)
		if len(fields) != 3 || fields[0] == "" || len(fields[2]) < 10 {
			continue // رمزِ کوتاه‌تر از ۱۰ حرف قبول نیست
		}
		role := fields[1]
		if role != adminRoleAdmin && role != adminRoleSupport {
			continue
		}
		out = append(out, adminAccount{User: fields[0], Role: role, Password: fields[2]})
	}
	return out
}

func adminPanelEnabled() bool { return len(loadAdminAccounts()) > 0 }

// checkAdminLogin رمزِ همه‌ی حساب‌ها بررسی می‌شود (نه فقط همنام) تا از روی
// زمانِ پاسخ نشود فهمید کدام نام کاربری وجود دارد.
func checkAdminLogin(user, password string) (adminAccount, bool) {
	var match adminAccount
	found := false
	for _, a := range loadAdminAccounts() {
		passOK := verifyAdminPassword(a.Password, password)
		userOK := subtle.ConstantTimeCompare([]byte(a.User), []byte(user)) == 1
		if userOK && passOK {
			match, found = a, true
		}
	}
	return match, found
}

// ------------------------------------------------------------ نشست‌ها

type adminSession struct {
	ID       string // شناسه‌ی نمایشی (نه توکن)
	User     string
	Role     string
	CSRF     string
	IP       string
	Agent    string
	Created  time.Time
	LastSeen time.Time
	Expires  time.Time
}

type adminSessionStore struct {
	mu sync.Mutex
	m  map[string]*adminSession // sha256(token) → نشست
}

var adminSessions = &adminSessionStore{m: map[string]*adminSession{}}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (s *adminSessionStore) create(a adminAccount, ip string) (string, *adminSession) {
	token := randomHex(32)
	now := time.Now()
	sess := &adminSession{ID: randomHex(4), User: a.User, Role: a.Role, CSRF: randomHex(16), IP: ip,
		Created: now, LastSeen: now, Expires: now.Add(adminSessionTTL)}
	s.mu.Lock()
	for k, v := range s.m {
		if now.After(v.Expires) {
			delete(s.m, k)
		}
	}
	s.m[hashToken(token)] = sess
	s.mu.Unlock()
	return token, sess
}

func (s *adminSessionStore) get(token string) *adminSession {
	if token == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	key := hashToken(token)
	sess := s.m[key]
	if sess == nil {
		return nil
	}
	now := time.Now()
	if now.After(sess.Expires) || now.Sub(sess.LastSeen) > adminIdleTimeout || adminLockdown.Load() {
		delete(s.m, key)
		return nil
	}
	// حسابی که از .env حذف شده یا نقشش عوض شده دیگر نشستِ قبلی را ندارد
	valid := false
	for _, a := range loadAdminAccounts() {
		if a.User == sess.User && a.Role == sess.Role {
			valid = true
		}
	}
	if !valid {
		delete(s.m, key)
		return nil
	}
	sess.LastSeen = now
	return sess
}

func (s *adminSessionStore) dropAll() {
	s.mu.Lock()
	s.m = map[string]*adminSession{}
	s.mu.Unlock()
}

func (s *adminSessionStore) dropAllExcept(keep *adminSession) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	n := 0
	for k, v := range s.m {
		if v != keep {
			delete(s.m, k)
			n++
		}
	}
	return n
}

func (s *adminSessionStore) list(me *adminSession) []map[string]interface{} {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []map[string]interface{}{}
	for _, v := range s.m {
		out = append(out, map[string]interface{}{
			"id": v.ID, "user": v.User, "role": v.Role, "ip": v.IP, "agent": v.Agent,
			"created": v.Created, "last_seen": v.LastSeen, "me": v == me,
		})
	}
	return out
}

func sessionFromRequest(r *http.Request) *adminSession {
	c, _ := r.Cookie(adminCookieName)
	if c == nil {
		return nil
	}
	return adminSessions.get(c.Value)
}

func (s *adminSessionStore) drop(token string) {
	s.mu.Lock()
	delete(s.m, hashToken(token))
	s.mu.Unlock()
}

// ------------------------------------------------------------ میدل‌ورها

type adminCtxKey struct{}

func adminFrom(r *http.Request) *adminSession {
	sess, _ := r.Context().Value(adminCtxKey{}).(*adminSession)
	return sess
}

func adminSecurityHeaders(w http.ResponseWriter) {
	h := w.Header()
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("X-Frame-Options", "DENY")
	h.Set("Referrer-Policy", "no-referrer")
	h.Set("X-Robots-Tag", "noindex, nofollow")
	h.Set("Content-Security-Policy", "default-src 'self'; img-src 'self' data:; style-src 'self'; "+
		"script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
}

// adminAPI نگهبانِ همه‌ی مسیرهای /admin/api/ به جز login.
// minRole == support یعنی هر دو نقش؛ admin یعنی فقط مدیر کامل.
func adminAPI(minRole string, next http.HandlerFunc) http.HandlerFunc {
	return rateLimit(func(w http.ResponseWriter, r *http.Request) {
		adminSecurityHeaders(w)
		if !adminPanelEnabled() {
			http.NotFound(w, r)
			return
		}
		if adminLockdown.Load() {
			httpErrorCode(w, "پنل در قفل اضطراری است", "admin_locked", http.StatusLocked)
			return
		}
		sess := sessionFromRequest(r)
		if sess == nil {
			httpErrorCode(w, "وارد نشده‌اید", "admin_login", http.StatusUnauthorized)
			return
		}
		if r.Method != http.MethodGet {
			if subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Admin-CSRF")), []byte(sess.CSRF)) != 1 {
				httpError(w, "توکن امنیتی نامعتبر است — صفحه را رفرش کنید", http.StatusForbidden)
				return
			}
		}
		if minRole == adminRoleAdmin && sess.Role != adminRoleAdmin {
			httpError(w, "این کار فقط برای مدیر کامل مجاز است", http.StatusForbidden)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, adminMaxBodyBytes)
		next(w, r.WithContext(context.WithValue(r.Context(), adminCtxKey{}, sess)))
	})
}

// ------------------------------------------------------------ ورود و خروج

var (
	adminLoginIPLimiter   = newRateLimiter("admin_login_ip", 6, 6)
	adminLoginUserLimiter = newRateLimiter("admin_login_user", 6, 6)
)

// requestIsHTTPS پشت آروان، nginx درخواست را http می‌بیند؛ آدرس عمومیِ https
// یعنی مرورگر روی https است و کوکی باید Secure باشد.
func requestIsHTTPS(r *http.Request) bool {
	return r.TLS != nil || strings.EqualFold(r.Header.Get("X-Forwarded-Proto"), "https") ||
		strings.HasPrefix(os.Getenv("PUBLIC_BASE_URL"), "https://")
}

// POST /admin/api/login {"username","password"}
func adminLoginHandler(w http.ResponseWriter, r *http.Request) {
	adminSecurityHeaders(w)
	if !adminPanelEnabled() {
		http.NotFound(w, r)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط POST", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Code     string `json:"code"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "درخواست نامعتبر", http.StatusBadRequest)
		return
	}
	ip := clientIP(r)
	req.Username = strings.TrimSpace(req.Username)
	if adminLockdown.Load() {
		httpErrorCode(w, "پنل در قفل اضطراری است — فقط از روی سرور باز می‌شود", "admin_locked", http.StatusLocked)
		return
	}
	now := time.Now()
	if adminLoginBlocked(now) {
		httpError(w, "به‌خاطر تلاش‌های ناموفقِ زیاد، ورود موقتاً بسته است", http.StatusTooManyRequests)
		return
	}
	if !adminLoginIPLimiter.allow(ip) || !adminLoginUserLimiter.allow(strings.ToLower(req.Username)) {
		tooManyRequests(w, 60)
		return
	}
	acc, ok := checkAdminLogin(req.Username, req.Password)
	reason := "password"
	if ok {
		// کد دومرحله‌ای: اگر برای حساب تعریف شده اجباری است؛ با ADMIN_REQUIRE_TOTP=1
		// حسابِ بدون کد اصلاً وارد نمی‌شود.
		secret := adminTOTPSecret(acc.User)
		switch {
		case secret != "":
			if !verifyTOTP(acc.User, secret, req.Code, now) {
				ok, reason = false, "totp"
			}
		case os.Getenv("ADMIN_REQUIRE_TOTP") == "1":
			ok, reason = false, "totp_not_configured"
		}
	}
	if !ok {
		time.Sleep(400 * time.Millisecond)
		tripped := adminLoginFailed(now)
		writeAudit(r.Context(), r, &adminSession{User: req.Username}, "login_failed", "",
			map[string]interface{}{"step": reason, "global_lock": tripped})
		if tripped {
			fmt.Printf("🚨 admin login globally blocked for %s (too many failures)\n", adminGlobalFailWindow)
		}
		httpError(w, "نام کاربری، رمز یا کد دومرحله‌ای اشتباه است", http.StatusUnauthorized)
		return
	}
	token, sess := adminSessions.create(acc, ip)
	sess.Agent = truncateRunes(r.UserAgent(), 160)
	http.SetCookie(w, &http.Cookie{
		Name: adminCookieName, Value: token, Path: adminBasePath(),
		HttpOnly: true, Secure: requestIsHTTPS(r), SameSite: http.SameSiteStrictMode,
		Expires: sess.Expires,
	})
	writeAudit(r.Context(), r, sess, "login", "", nil)
	jsonResponse(w, adminMePayload(sess))
}

func adminMePayload(s *adminSession) map[string]interface{} {
	return map[string]interface{}{
		"user": s.User, "role": s.Role, "csrf": s.CSRF, "expires_at": s.Expires,
		"totp": adminTOTPSecret(s.User) != "",
	}
}

func truncateRunes(v string, n int) string {
	r := []rune(v)
	if len(r) > n {
		return string(r[:n])
	}
	return v
}

// GET /admin/api/me
func adminMeHandler(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, adminMePayload(adminFrom(r)))
}

// POST /admin/api/logout
func adminLogoutHandler(w http.ResponseWriter, r *http.Request) {
	if c, _ := r.Cookie(adminCookieName); c != nil {
		adminSessions.drop(c.Value)
	}
	http.SetCookie(w, &http.Cookie{Name: adminCookieName, Value: "", Path: adminBasePath(),
		MaxAge: -1, HttpOnly: true, SameSite: http.SameSiteStrictMode})
	writeAudit(r.Context(), r, adminFrom(r), "logout", "", nil)
	jsonResponse(w, map[string]bool{"success": true})
}

// ------------------------------------------------------------ ثبت کارها

type AdminAuditEntry struct {
	At      time.Time              `bson:"at" json:"at"`
	Admin   string                 `bson:"admin" json:"admin"`
	Action  string                 `bson:"action" json:"action"`
	Target  string                 `bson:"target,omitempty" json:"target,omitempty"`
	Details map[string]interface{} `bson:"details,omitempty" json:"details,omitempty"`
	IP      string                 `bson:"ip" json:"ip"`
}

func writeAudit(ctx context.Context, r *http.Request, s *adminSession, action, target string, details map[string]interface{}) {
	if db == nil {
		return
	}
	who := ""
	if s != nil {
		who = s.User
	}
	c, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
	defer cancel()
	_, _ = col(ColAdminAudit).InsertOne(c, AdminAuditEntry{
		At: time.Now(), Admin: who, Action: action, Target: target, Details: details, IP: clientIP(r),
	})
}

// audit کوتاه‌نوشتِ writeAudit برای هندلرها
func audit(r *http.Request, action, target string, details map[string]interface{}) {
	writeAudit(r.Context(), r, adminFrom(r), action, target, details)
}

// EnsureAdminIndexes ایندکس‌های کالکشن‌های پنل
func EnsureAdminIndexes(ctx context.Context) {
	_, _ = col(ColAdminAudit).Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "at", Value: -1}}},
		{Keys: bson.D{{Key: "target", Value: 1}, {Key: "at", Value: -1}}},
	})
	_, _ = col(ColAdminNotes).Indexes().CreateOne(ctx, mongo.IndexModel{Keys: bson.D{{Key: "player_id", Value: 1}}})
	_, _ = col(ColAdminCampaigns).Indexes().CreateOne(ctx, mongo.IndexModel{Keys: bson.D{{Key: "created_at", Value: -1}}})
	_, _ = col(ColSupportMsgs).Indexes().CreateOne(ctx, mongo.IndexModel{Keys: bson.D{{Key: "status", Value: 1}, {Key: "created_at", Value: -1}}})
	_, _ = col(ColMessages).Indexes().CreateOne(ctx, mongo.IndexModel{Keys: bson.D{{Key: "ref_id", Value: 1}}})
}

// ------------------------------------------------------------ کمک‌های مشترک

func adminDecode(w http.ResponseWriter, r *http.Request, v interface{}) bool {
	if r.Method != http.MethodPost {
		httpError(w, "فقط POST", http.StatusMethodNotAllowed)
		return false
	}
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		httpError(w, "بدنه‌ی درخواست نامعتبر است", http.StatusBadRequest)
		return false
	}
	return true
}

// adminPage شماره‌ی صفحه (از ۱) و اندازه‌اش از query
func adminPage(r *http.Request, def int) (page, size int) {
	page, _ = strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	size, _ = strconv.Atoi(r.URL.Query().Get("size"))
	if size < 1 || size > 200 {
		size = def
	}
	return page, size
}

func findPage(page, size int, sort bson.D) *options.FindOptions {
	return options.Find().SetSort(sort).SetSkip(int64((page - 1) * size)).SetLimit(int64(size))
}

// ------------------------------------------------------------ مسیرها

// registerAdminRoutes همه‌ی مسیرهای پنل را روی mux می‌نشاند
func registerAdminRoutes(mux *http.ServeMux) {
	base := adminBasePath()
	sub, _ := fs.Sub(adminPanelFS, "admin_panel")
	static := http.StripPrefix(base+"/", http.FileServer(http.FS(sub)))
	mux.HandleFunc(base, func(w http.ResponseWriter, r *http.Request) {
		if !adminPanelEnabled() {
			http.NotFound(w, r)
			return
		}
		http.Redirect(w, r, base+"/", http.StatusMovedPermanently)
	})
	mux.HandleFunc(base+"/", rateLimit(func(w http.ResponseWriter, r *http.Request) {
		if !adminPanelEnabled() {
			http.NotFound(w, r)
			return
		}
		adminSecurityHeaders(w)
		static.ServeHTTP(w, r)
	}))

	mux.HandleFunc(base+"/api/login", rateLimit(adminLoginHandler))
	mux.HandleFunc(base+"/api/panic", rateLimit(adminPanicHandler))
	api := func(path, role string, h http.HandlerFunc) {
		mux.HandleFunc(base+"/api/"+path, adminAPI(role, h))
	}
	S, A := adminRoleSupport, adminRoleAdmin

	api("me", S, adminMeHandler)
	api("logout", S, adminLogoutHandler)
	api("dashboard", S, adminDashboardHandler)
	api("server", S, adminServerHandler)
	api("online", S, adminOnlineHandler)
	api("audit", A, adminAuditHandler)
	api("security", S, adminSecurityHandler)
	api("security/logout_all", A, adminLogoutAllHandler)

	// بازیکن‌ها (admin_players.go)
	api("players", S, adminPlayersHandler)
	api("player", S, adminPlayerHandler)
	api("player/economy", A, adminPlayerEconomyHandler)
	api("player/items", A, adminPlayerItemsHandler)
	api("player/ban", S, adminPlayerBanHandler)
	api("player/unban", S, adminPlayerUnbanHandler)
	api("player/mute", S, adminPlayerMuteHandler)
	api("player/kick", S, adminPlayerKickHandler)
	api("player/note", S, adminPlayerNoteHandler)
	api("player/message/delete", S, adminDeletePlayerMessageHandler)

	// پیام و پشتیبانی و چت (admin_content.go)
	api("messages/send", S, adminSendMessageHandler)
	api("messages/campaigns", S, adminCampaignsHandler)
	api("messages/revoke", S, adminRevokeCampaignHandler)
	api("support", S, adminSupportListHandler)
	api("support/ticket", S, adminSupportTicketHandler)
	api("support/reply", S, adminSupportReplyHandler)
	api("support/status", S, adminSupportStatusHandler)
	api("chat", S, adminChatHandler)
	api("chat/delete", S, adminChatDeleteHandler)

	// اقتصاد و تنظیمات بازی (admin_game.go)
	api("gift_codes", S, adminGiftCodesHandler)
	api("gift_codes/create", A, adminGiftCodeCreateHandler)
	api("gift_codes/toggle", A, adminGiftCodeToggleHandler)
	api("gift_codes/redemptions", S, adminGiftCodeRedemptionsHandler)
	api("purchases", S, adminPurchasesHandler)
	api("clans", S, adminClansHandler)
	api("clan", S, adminClanHandler)
	api("clan/update", A, adminClanUpdateHandler)
	api("clan/kick", A, adminClanKickHandler)
	api("clan/disband", A, adminClanDisbandHandler)
	api("modes", S, adminModesHandler)
	api("modes/update", A, adminModeUpdateHandler)
	api("shop", S, adminShopHandler)
	api("shop/update", A, adminShopUpdateHandler)
}
