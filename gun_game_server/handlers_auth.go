package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// احراز هویت: توکن دستگاه + اتصال حساب به گوگل
//
// مدل امنیتی:
//   - هر حساب تازه موقع ساخت (GET /get_player) یک «توکن دستگاه» می‌گیرد. خودِ
//     توکن فقط همان یک بار به کلاینت داده می‌شود؛ سرور فقط هش SHA-256 آن را
//     در auth.sessions نگه می‌دارد (حداکثر ۵ دستگاه).
//   - وصل کردن حساب به گوگل فقط با توکنِ همان دستگاه ممکن است؛ پس کسی که فقط
//     نام کاربریِ دیگری را می‌داند نمی‌تواند گوگلِ خودش را به آن حساب بچسباند.
//   - حسابِ وصل‌شده به گوگل «محافظت‌شده» است: authGuard هر درخواستی را که به
//     نام این حساب بیاید بدون توکنِ معتبر رد می‌کند (401 / auth_required).
//   - اگر دستگاه گم شد، «ورود با گوگل» روی دستگاه تازه حساب را پیدا می‌کند و یک
//     توکن تازه می‌دهد — پیشرفت بازیکن برمی‌گردد.
//
// جریان گوگل (بدون پلاگین بومی، روی اندروید و PC یکسان):
//   1. POST /auth/google/start   → آدرس صفحه‌ی گوگل + poll_secret
//   2. کلاینت آدرس را در مرورگر سیستم باز می‌کند (OS.shell_open)
//   3. گوگل به GET /auth/google/callback برمی‌گردد؛ سرور code را با PKCE و
//      client_secret عوض می‌کند و id_token را بررسی می‌کند
//   4. کلاینت با POST /auth/google/poll نتیجه را می‌گیرد (یک‌بارمصرف)
//
// پلاگین بومی اندروید (Credential Manager) هم می‌تواند id_token را مستقیم به
// POST /auth/google/token بدهد؛ منطق اتصال/ورود یکی است.
//
// تنظیمات (متغیر محیطی):
//   GOOGLE_CLIENT_ID      شناسه‌ی OAuth نوع «Web application»
//   GOOGLE_CLIENT_SECRET  رمزِ همان کلاینت (فقط روی سرور)
//   PUBLIC_BASE_URL       آدرس عمومی سرور، مثلاً https://api.example.com
//                         (redirect URI در کنسول گوگل: <PUBLIC_BASE_URL>/auth/google/callback)
// =============================================================================

const (
	// ColGoogleAuth جریان‌های نیمه‌تمامِ ورود با گوگل (TTL ده دقیقه)
	ColGoogleAuth = "auth_google_pending"

	// MaxSessionsPerPlayer سقف دستگاه‌های هم‌زمان؛ قدیمی‌ترین کنار می‌رود
	MaxSessionsPerPlayer = 5

	sessionTokenBytes = 32
	googleAuthTTL     = 10 * time.Minute
	maxGuardBodyBytes = 1 << 20

	// کدهای خطای ماشینی — کلاینت بر اساس این‌ها پیام و دکمه‌ی درست را نشان می‌دهد
	AuthCodeRequired       = "auth_required"
	AuthCodeDeviceRequired = "device_token_required"
	AuthCodeBanned         = "banned" // مسدود از پنل مدیریت
	AuthCodeUnavailable    = "google_unavailable"
	AuthCodeDeviceUnknown  = "device_not_verified"
	AuthCodeAlreadyLinked  = "already_linked"
	AuthCodeGoogleInUse    = "google_in_use"
	AuthCodeNoAccount      = "no_account"
	AuthCodeCancelled      = "cancelled"
	AuthCodeGoogleFailed   = "google_failed"
	AuthCodeExpired        = "expired"
	AuthIntentLink         = "link"
	AuthIntentLogin        = "login"
	googlePendingStatus    = "pending"
	googleDoneStatus       = "done"
	googleErrorStatus      = "error"
	googleScope            = "openid email profile"
	googleIssuer           = "https://accounts.google.com"
	googleIssuerShort      = "accounts.google.com"
	googleHTTPTimeout      = 10 * time.Second
	googleDeviceNameMaxLen = 40
)

// آدرس‌های گوگل — متغیرند تا تست بتواند سرور جعلی جایشان بگذارد
var (
	googleAuthURL      = "https://accounts.google.com/o/oauth2/v2/auth"
	googleTokenURL     = "https://oauth2.googleapis.com/token"
	googleTokenInfoURL = "https://oauth2.googleapis.com/tokeninfo"
	googleHTTP         = &http.Client{Timeout: googleHTTPTimeout}
)

// googleConfig تنظیمات OAuth که موقع بالا آمدن سرور از محیط خوانده می‌شود
type googleConfig struct {
	ClientID     string
	ClientSecret string
	RedirectURL  string
}

var googleCfg = loadGoogleConfig()

func loadGoogleConfig() googleConfig {
	cfg := googleConfig{
		ClientID:     strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_ID")),
		ClientSecret: strings.TrimSpace(os.Getenv("GOOGLE_CLIENT_SECRET")),
	}
	if base := strings.TrimRight(strings.TrimSpace(os.Getenv("PUBLIC_BASE_URL")), "/"); base != "" {
		cfg.RedirectURL = base + "/auth/google/callback"
	}
	return cfg
}

// webFlowReady جریان مرورگری فقط با هر سه مقدار کار می‌کند
func (c googleConfig) webFlowReady() bool {
	return c.ClientID != "" && c.ClientSecret != "" && c.RedirectURL != ""
}

// ============== توکن دستگاه ==============

func randomToken(nBytes int) (string, error) {
	b := make([]byte, nBytes)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// sessionMatches آیا توکن با یکی از دستگاه‌های ثبت‌شده می‌خواند؟
// مقایسه با زمان ثابت است و روی همه‌ی نشست‌ها انجام می‌شود.
func sessionMatches(sessions []PlayerSession, token string) bool {
	if token == "" {
		return false
	}
	want := []byte(hashToken(token))
	ok := 0
	for _, s := range sessions {
		ok |= subtle.ConstantTimeCompare([]byte(s.TokenHash), want)
	}
	return ok == 1
}

// bearerToken توکن را از هدر Authorization: Bearer <token> برمی‌دارد
func bearerToken(r *http.Request) string {
	h := strings.TrimSpace(r.Header.Get("Authorization"))
	if len(h) > 7 && strings.EqualFold(h[:7], "bearer ") {
		return strings.TrimSpace(h[7:])
	}
	return ""
}

func deviceName(r *http.Request) string {
	d := strings.TrimSpace(r.Header.Get("X-Device"))
	if len([]rune(d)) > googleDeviceNameMaxLen {
		d = string([]rune(d)[:googleDeviceNameMaxLen])
	}
	return d
}

func newSession(device string) (string, PlayerSession, error) {
	token, err := randomToken(sessionTokenBytes)
	if err != nil {
		return "", PlayerSession{}, err
	}
	return token, PlayerSession{TokenHash: hashToken(token), Device: device, CreatedAt: time.Now()}, nil
}

// issueSession یک دستگاه تازه به حساب اضافه می‌کند و توکنش را برمی‌گرداند.
// فقط MaxSessionsPerPlayer تای آخر می‌مانند.
func issueSession(ctx context.Context, playerID, device string) (string, error) {
	token, s, err := newSession(device)
	if err != nil {
		return "", err
	}
	res, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": playerID}, bson.M{
		"$push": bson.M{"auth.sessions": bson.M{"$each": []PlayerSession{s}, "$slice": -MaxSessionsPerPlayer}},
		"$set":  bson.M{"auth.last_login_at": time.Now()},
	})
	if err != nil {
		return "", err
	}
	if res.MatchedCount == 0 {
		return "", mongo.ErrNoDocuments
	}
	return token, nil
}

// claimFirstSession برای حساب‌های قدیمی که هنوز هیچ دستگاهی ندارند: اولین
// دستگاهی که بیاید مالک شناخته می‌شود. شرطِ «هنوز نشستی ندارد» روی خودِ آپدیت
// است، پس دو درخواست هم‌زمان نمی‌توانند هر دو مالک شوند.
func claimFirstSession(ctx context.Context, playerID, device string) (string, error) {
	token, s, err := newSession(device)
	if err != nil {
		return "", err
	}
	res, err := col(ColPlayers).UpdateOne(ctx, bson.M{
		"player_id":       playerID,
		"auth.google_id":  bson.M{"$exists": false},
		"auth.sessions.0": bson.M{"$exists": false},
	}, bson.M{"$push": bson.M{"auth.sessions": s}})
	if err != nil {
		return "", err
	}
	if res.MatchedCount == 0 {
		return "", nil
	}
	return token, nil
}

// authProbe فقط همان بخشی از بازیکن که برای تصمیم‌گیری امنیتی لازم است
type authProbe struct {
	PlayerID    string     `bson:"player_id"`
	Username    string     `bson:"username"`
	Auth        PlayerAuth `bson:"auth"`
	IsBanned    bool       `bson:"is_banned"`
	BanReason   string     `bson:"ban_reason"`
	BannedUntil *time.Time `bson:"banned_until"`
}

func loadAuthProbe(ctx context.Context, filter bson.M) (*authProbe, error) {
	var p authProbe
	err := col(ColPlayers).FindOne(ctx, filter,
		options.FindOne().SetProjection(bson.M{
			"player_id": 1, "username": 1, "auth": 1,
			"is_banned": 1, "ban_reason": 1, "banned_until": 1,
		})).Decode(&p)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// isProtected حسابِ وصل‌شده به گوگل بدون توکن معتبر قابل استفاده نیست
func isProtected(a PlayerAuth) bool { return a.GoogleID != "" }

// needsToken می‌گوید این حساب برای هر کاری توکن دستگاه لازم دارد یا نه.
//
// قبلاً فقط حساب‌های گوگل توکن می‌خواستند و حساب مهمان با «فقط دانستنِ اسم»
// قابل استفاده بود: چون کلاینت اسم مهمان را «Player<عدد>» می‌سازد، کلِ
// حساب‌های مهمان قابل شمارش و تصاحب بودند (خرج کردن سکه، خواندن پیام‌ها،
// چت به اسمِ دیگری، اخراج از شهر). حالا هر حسابی که حتی یک دستگاه ثبت‌شده
// دارد توکن می‌خواهد — یعنی هر حسابی که بعد از افزوده‌شدنِ توکنِ دستگاه
// ساخته شده، مهمان یا گوگلی.
//
// حساب‌های قدیمی که هنوز هیچ نشستی ندارند عمداً بیرون می‌مانند تا با
// claimFirstSession اولین دستگاهشان را بگیرند و بازیکنِ قدیمی پشتِ در نماند.
func needsToken(a PlayerAuth) bool { return isProtected(a) || len(a.Sessions) > 0 }

func authRequired(w http.ResponseWriter) {
	httpErrorCode(w, "این حساب به گوگل وصل است؛ برای ادامه با گوگل وارد شو", AuthCodeRequired, http.StatusUnauthorized)
}

// deviceTokenRequired حسابِ مهمانی که توکنِ این دستگاه را ندارد. پیام با
// authRequired فرق دارد چون راه‌حلش «ورود با گوگل» نیست.
func deviceTokenRequired(w http.ResponseWriter) {
	httpErrorCode(w, "این حساب روی این دستگاه شناخته نشد", AuthCodeDeviceRequired, http.StatusUnauthorized)
}

// httpErrorCode مثل httpError ولی با کد ماشینی کنار پیام فارسی
func httpErrorCode(w http.ResponseWriter, message, code string, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message, "code": code})
}

// ============== نگهبان درخواست‌ها ==============

// actingUsernames همه‌ی نام‌هایی که درخواست به نامشان عمل می‌کند: ?username=
// و فیلد username بدنه‌ی JSON. هر دو بررسی می‌شوند تا نشود نگهبان را با یک
// اسم فریب داد و هندلر با اسم دیگری کار کند. بدنه دوباره سر جایش گذاشته می‌شود.
func actingUsernames(w http.ResponseWriter, r *http.Request) ([]string, bool) {
	names := []string{}
	if u := r.URL.Query().Get("username"); u != "" {
		names = append(names, u)
	}
	if r.Body == nil || r.Method == http.MethodGet || r.Method == http.MethodHead {
		return names, true
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxGuardBodyBytes+1))
	if err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return nil, false
	}
	if len(body) > maxGuardBodyBytes {
		httpError(w, "درخواست خیلی بزرگ است", http.StatusRequestEntityTooLarge)
		return nil, false
	}
	r.Body = io.NopCloser(bytes.NewReader(body))
	var probe struct {
		Username string `json:"username"`
	}
	if json.Unmarshal(body, &probe) == nil && probe.Username != "" {
		names = append(names, probe.Username)
	}
	return names, true
}

// authGuard جلوی هر درخواستی به نام یک حساب محافظت‌شده را بدون توکن معتبر
// می‌گیرد. حساب‌های مهمان همان رفتار قبلی را دارند.
func authGuard(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions || db == nil {
			next(w, r)
			return
		}
		names, ok := actingUsernames(w, r)
		if !ok {
			return
		}
		if len(names) > 0 {
			token := bearerToken(r)
			ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
			for _, name := range names {
				probe, err := loadAuthProbe(ctx, bson.M{"username": name})
				if err != nil {
					// حساب نیست (ثبت‌نامِ اولِ /get_player) یا دیتابیس جواب
					// نداد — هندلر خودش تصمیم می‌گیرد.
					continue
				}
				// حسابِ مسدود (پنل مدیریت) هیچ کاری نمی‌تواند بکند
				if probeBanned(probe) {
					cancel()
					bannedResponse(w, probe)
					return
				}
				if !needsToken(probe.Auth) || sessionMatches(probe.Auth.Sessions, token) {
					continue
				}
				cancel()
				if isProtected(probe.Auth) {
					authRequired(w)
				} else {
					deviceTokenRequired(w)
				}
				return
			}
			cancel()
		}
		next(w, r)
	}
}

// wsJoinAllowed همان قانون برای join وب‌سوکت: حساب محافظت‌شده بدون توکن
// معتبر نمی‌تواند وارد هاب شود (نه بازی، نه چت و نوتیف).
func wsJoinAllowed(username, token string) bool {
	if db == nil || username == "" {
		return true
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	probe, err := loadAuthProbe(ctx, bson.M{"username": username})
	if err == mongo.ErrNoDocuments {
		return true // حساب نیست — هاب خودش رفتار قبلی را دارد
	}
	if err != nil {
		// خطای دیتابیس (مثلاً timeout زیرِ بار) نباید درِ حسابِ محافظت‌شده را
		// بدونِ توکن باز کند؛ کلاینت خودش دوباره وصل می‌شود.
		log.Printf("⚠️ ws join check failed for %q: %v", username, err)
		return false
	}
	if probeBanned(probe) {
		return false
	}
	return !needsToken(probe.Auth) || sessionMatches(probe.Auth.Sessions, token)
}

// banActive مسدودیتِ موقت بعد از BannedUntil خودبه‌خود تمام می‌شود
func banActive(isBanned bool, until *time.Time, now time.Time) bool {
	return isBanned && (until == nil || now.Before(*until))
}

// probeBanned اگر مسدودیتِ موقت تمام شده باشد پرچمش را هم پاک می‌کند تا
// رتبه‌بندی (که فقط is_banned را نگاه می‌کند) دوباره نشانش بدهد.
func probeBanned(p *authProbe) bool {
	if !p.IsBanned {
		return false
	}
	if banActive(p.IsBanned, p.BannedUntil, time.Now()) {
		return true
	}
	go func(playerID string) {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_, _ = col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": playerID, "banned_until": bson.M{"$lte": time.Now()}},
			bson.M{"$set": bson.M{"is_banned": false},
				"$unset": bson.M{"ban_reason": "", "banned_at": "", "banned_until": ""}})
	}(p.PlayerID)
	return false
}

// bannedResponse پاسخِ 403 با کد banned — کلاینت متن را به بازیکن نشان می‌دهد
func bannedResponse(w http.ResponseWriter, p *authProbe) {
	msg := "حساب تو مسدود شده است"
	if p.BannedUntil != nil {
		msg += " تا " + persianDuration(time.Until(*p.BannedUntil)) + " دیگر"
	}
	if p.BanReason != "" {
		msg += " — دلیل: " + p.BanReason
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusForbidden)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg, "code": AuthCodeBanned})
}

// ============== وضعیت اکانت ==============

// authStatusHandler نمای امن اکانت برای تنظیمات
// GET /auth/status?username=
func authStatusHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	probe, err := loadAuthProbe(ctx, bson.M{"username": username})
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	linked := isProtected(probe.Auth)
	out := map[string]interface{}{
		"player_id":        probe.PlayerID,
		"username":         probe.Username,
		"linked":           linked,
		"provider":         probe.Auth.Provider,
		"device_verified":  sessionMatches(probe.Auth.Sessions, bearerToken(r)),
		"device_count":     len(probe.Auth.Sessions),
		"google_available": googleCfg.webFlowReady(),
	}
	if linked {
		out["email"] = probe.Auth.Email
		out["google_name"] = probe.Auth.GoogleName
		out["linked_at"] = probe.Auth.LinkedAt
	}
	jsonResponse(w, out)
}

// ============== ادعاهای id_token ==============

type googleClaims struct {
	Sub           string
	Email         string
	EmailVerified bool
	Name          string
	Aud           []string
	Iss           string
	Exp           int64
}

// claimsFromMap هر دو شکلِ خروجی را می‌فهمد: payload خودِ JWT (عدد و bool)
// و پاسخ tokeninfo گوگل (همه‌چیز رشته)
func claimsFromMap(m map[string]interface{}) googleClaims {
	c := googleClaims{
		Sub:   asString(m["sub"]),
		Email: asString(m["email"]),
		Name:  asString(m["name"]),
		Iss:   asString(m["iss"]),
	}
	switch v := m["aud"].(type) {
	case string:
		c.Aud = []string{v}
	case []interface{}:
		for _, a := range v {
			c.Aud = append(c.Aud, asString(a))
		}
	}
	switch v := m["exp"].(type) {
	case float64:
		c.Exp = int64(v)
	case string:
		c.Exp, _ = strconv.ParseInt(v, 10, 64)
	}
	switch v := m["email_verified"].(type) {
	case bool:
		c.EmailVerified = v
	case string:
		c.EmailVerified = strings.EqualFold(v, "true")
	}
	return c
}

func asString(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

// validate قوانین OIDC: صادرکننده‌ی گوگل، مخاطب همین کلاینت، منقضی نشده
func (c googleClaims) validate(clientID string, now time.Time) error {
	if c.Sub == "" {
		return errors.New("sub خالی است")
	}
	if c.Iss != googleIssuer && c.Iss != googleIssuerShort {
		return fmt.Errorf("صادرکننده‌ی نامعتبر: %q", c.Iss)
	}
	audOK := false
	for _, a := range c.Aud {
		if a == clientID && clientID != "" {
			audOK = true
		}
	}
	if !audOK {
		return errors.New("این توکن برای این بازی صادر نشده")
	}
	if c.Exp <= now.Unix() {
		return errors.New("توکن منقضی شده")
	}
	return nil
}

// parseIDTokenPayload بخشِ میانیِ JWT را باز می‌کند. امضا اینجا بررسی نمی‌شود:
// این تابع فقط برای توکنی است که مستقیم و روی TLS از خودِ گوگل (token
// endpoint) گرفته شده — طبق OIDC Core 3.1.3.7 همین کافی است. توکنی که از
// کلاینت می‌رسد همیشه از verifyGoogleIDToken (tokeninfo) رد می‌شود.
func parseIDTokenPayload(idToken string) (googleClaims, error) {
	parts := strings.Split(idToken, ".")
	if len(parts) != 3 {
		return googleClaims{}, errors.New("id_token نامعتبر")
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return googleClaims{}, err
	}
	var m map[string]interface{}
	if err := json.Unmarshal(raw, &m); err != nil {
		return googleClaims{}, err
	}
	return claimsFromMap(m), nil
}

// exchangeGoogleCode کدِ برگشتی از صفحه‌ی گوگل را با PKCE به id_token تبدیل می‌کند
func exchangeGoogleCode(ctx context.Context, code, verifier string) (googleClaims, error) {
	form := url.Values{
		"code":          {code},
		"client_id":     {googleCfg.ClientID},
		"client_secret": {googleCfg.ClientSecret},
		"redirect_uri":  {googleCfg.RedirectURL},
		"grant_type":    {"authorization_code"},
		"code_verifier": {verifier},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, googleTokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return googleClaims{}, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := googleHTTP.Do(req)
	if err != nil {
		return googleClaims{}, err
	}
	defer resp.Body.Close()

	var out struct {
		IDToken string `json:"id_token"`
		Error   string `json:"error"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&out); err != nil {
		return googleClaims{}, err
	}
	if resp.StatusCode != http.StatusOK || out.IDToken == "" {
		return googleClaims{}, fmt.Errorf("تبادل کد با گوگل ناموفق بود: %s", out.Error)
	}
	claims, err := parseIDTokenPayload(out.IDToken)
	if err != nil {
		return googleClaims{}, err
	}
	return claims, claims.validate(googleCfg.ClientID, time.Now())
}

// verifyGoogleIDToken توکنی که از کلاینت (پلاگین بومی) رسیده را خودِ گوگل
// تأیید می‌کند؛ امضا، انقضا و صادرکننده سمت گوگل بررسی می‌شوند.
func verifyGoogleIDToken(ctx context.Context, idToken string) (googleClaims, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		googleTokenInfoURL+"?id_token="+url.QueryEscape(idToken), nil)
	if err != nil {
		return googleClaims{}, err
	}
	resp, err := googleHTTP.Do(req)
	if err != nil {
		return googleClaims{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return googleClaims{}, errors.New("گوگل این توکن را تأیید نکرد")
	}
	var m map[string]interface{}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&m); err != nil {
		return googleClaims{}, err
	}
	claims := claimsFromMap(m)
	return claims, claims.validate(googleCfg.ClientID, time.Now())
}

// ============== اتصال / ورود ==============

type googleResult struct {
	OK       bool
	Code     string
	Message  string
	Email    string
	PlayerID string
}

func googleFail(code, message string) googleResult {
	return googleResult{Code: code, Message: message}
}

// applyGoogleIdentity هویت تأییدشده‌ی گوگل را روی حساب اعمال می‌کند:
// link → وصل کردن به حساب playerID؛ login → پیدا کردن حسابِ وصل‌شده
func applyGoogleIdentity(ctx context.Context, intent, playerID string, c googleClaims) googleResult {
	existing, err := loadAuthProbe(ctx, bson.M{"auth.google_id": c.Sub})
	if err != nil && err != mongo.ErrNoDocuments {
		return googleFail(AuthCodeGoogleFailed, "خطای سرور؛ دوباره تلاش کن")
	}

	if intent == AuthIntentLogin {
		if existing == nil {
			return googleFail(AuthCodeNoAccount, "این حساب گوگل به هیچ حسابی در بازی وصل نیست")
		}
		return googleResult{OK: true, Email: c.Email, PlayerID: existing.PlayerID}
	}

	// --- link ---
	if existing != nil {
		if existing.PlayerID == playerID {
			return googleResult{OK: true, Email: c.Email, PlayerID: playerID}
		}
		return googleFail(AuthCodeGoogleInUse, "این حساب گوگل قبلاً به حساب دیگری وصل شده")
	}

	now := time.Now()
	set := bson.M{
		"auth.google_id":      c.Sub,
		"auth.google_name":    c.Name,
		"auth.provider":       "google",
		"auth.is_guest":       false,
		"auth.email_verified": c.EmailVerified,
		"auth.linked_at":      now,
		"updated_at":          now,
	}
	if c.Email != "" && c.EmailVerified {
		set["auth.email"] = strings.ToLower(c.Email)
	}
	res, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": playerID, "auth.google_id": bson.M{"$exists": false}},
		bson.M{"$set": set})
	if err != nil {
		if mongo.IsDuplicateKeyError(err) {
			return googleFail(AuthCodeGoogleInUse, "این حساب گوگل قبلاً به حساب دیگری وصل شده")
		}
		return googleFail(AuthCodeGoogleFailed, "خطا در ذخیره‌ی اتصال")
	}
	if res.MatchedCount == 0 {
		return googleFail(AuthCodeAlreadyLinked, "این حساب از قبل به یک حساب گوگل وصل است")
	}

	// اعلان امنیتی در صندوق پیام — اگر کار خودِ بازیکن نبود، متوجه می‌شود
	_ = insertMessage(ctx, MessageModel{
		RecipientID: playerID,
		SenderID:    "system",
		SenderName:  "بازی",
		Type:        MsgTypeSystem,
		Title:       "حسابت به گوگل وصل شد",
		Body: "حسابت حالا به " + maskEmail(c.Email) + " وصل است و پیشرفتت محافظت می‌شود. " +
			"اگر گوشی را عوض کردی یا بازی پاک شد، با «ورود با گوگل» همه‌چیز برمی‌گردد.",
	})
	return googleResult{OK: true, Email: c.Email, PlayerID: playerID}
}

// maskEmail ایمیل را برای متن‌های عمومی نیمه‌پنهان می‌کند: pa***@gmail.com
func maskEmail(email string) string {
	at := strings.LastIndex(email, "@")
	if at <= 0 {
		return "حساب گوگل"
	}
	name := []rune(email[:at])
	keep := 2
	if len(name) <= 2 {
		keep = 1
	}
	return string(name[:keep]) + "***" + email[at:]
}

// ============== جریان مرورگری ==============

// GoogleAuthPending یک جریان نیمه‌تمام. خودِ poll_secret ذخیره نمی‌شود، فقط
// هشش؛ و توکن ورود تازه همان لحظه‌ی poll ساخته می‌شود، نه این‌جا.
type GoogleAuthPending struct {
	State          string    `bson:"state"`
	PollHash       string    `bson:"poll_hash"`
	Verifier       string    `bson:"verifier"`
	Intent         string    `bson:"intent"`
	PlayerID       string    `bson:"player_id,omitempty"`
	Device         string    `bson:"device,omitempty"`
	Status         string    `bson:"status"`
	Code           string    `bson:"code,omitempty"`
	Message        string    `bson:"message,omitempty"`
	Email          string    `bson:"email,omitempty"`
	ResultPlayerID string    `bson:"result_player_id,omitempty"`
	CreatedAt      time.Time `bson:"created_at"`
	ExpiresAt      time.Time `bson:"expires_at"`
}

type googleStartBody struct {
	Username string `json:"username"`
	Intent   string `json:"intent"`
}

// requireLinkingDevice برای link: فقط دستگاهِ تأییدشده‌ی حساب، و فقط حسابی
// که هنوز وصل نیست
func requireLinkingDevice(ctx context.Context, w http.ResponseWriter, r *http.Request, username string) (*authProbe, bool) {
	probe, err := loadAuthProbe(ctx, bson.M{"username": username})
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return nil, false
	}
	if !sessionMatches(probe.Auth.Sessions, bearerToken(r)) {
		httpErrorCode(w, "این دستگاه هنوز برای این حساب تأیید نشده", AuthCodeDeviceUnknown, http.StatusForbidden)
		return nil, false
	}
	if isProtected(probe.Auth) {
		httpErrorCode(w, "این حساب از قبل به گوگل وصل است", AuthCodeAlreadyLinked, http.StatusConflict)
		return nil, false
	}
	return probe, true
}

// googleAuthStartHandler شروع جریان: آدرس صفحه‌ی گوگل و رمزِ پیگیری
// POST /auth/google/start  {"username":"...","intent":"link"|"login"}
func googleAuthStartHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	if !googleCfg.webFlowReady() {
		httpErrorCode(w, "ورود با گوگل روی سرور تنظیم نشده", AuthCodeUnavailable, http.StatusServiceUnavailable)
		return
	}
	var req googleStartBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	pending := GoogleAuthPending{Intent: req.Intent, Device: deviceName(r)}
	switch req.Intent {
	case AuthIntentLink:
		probe, ok := requireLinkingDevice(ctx, w, r, req.Username)
		if !ok {
			return
		}
		pending.PlayerID = probe.PlayerID
	case AuthIntentLogin:
	default:
		httpError(w, "intent نامعتبر است", http.StatusBadRequest)
		return
	}

	state, err1 := randomToken(24)
	poll, err2 := randomToken(32)
	verifier, err3 := randomToken(48) // ۶۴ کاراکتر — در بازه‌ی ۴۳ تا ۱۲۸ PKCE
	if err1 != nil || err2 != nil || err3 != nil {
		httpError(w, "خطای سرور", http.StatusInternalServerError)
		return
	}
	now := time.Now()
	pending.State = state
	pending.PollHash = hashToken(poll)
	pending.Verifier = verifier
	pending.Status = googlePendingStatus
	pending.CreatedAt = now
	pending.ExpiresAt = now.Add(googleAuthTTL)
	if _, err := col(ColGoogleAuth).InsertOne(ctx, pending); err != nil {
		httpError(w, "خطای سرور", http.StatusInternalServerError)
		return
	}

	jsonResponse(w, map[string]interface{}{
		"auth_url":    googleConsentURL(state, verifier),
		"poll_secret": poll,
		"expires_in":  int(googleAuthTTL.Seconds()),
	})
}

func googleConsentURL(state, verifier string) string {
	challenge := sha256.Sum256([]byte(verifier))
	q := url.Values{
		"client_id":             {googleCfg.ClientID},
		"redirect_uri":          {googleCfg.RedirectURL},
		"response_type":         {"code"},
		"scope":                 {googleScope},
		"state":                 {state},
		"code_challenge":        {base64.RawURLEncoding.EncodeToString(challenge[:])},
		"code_challenge_method": {"S256"},
		"prompt":                {"select_account"},
	}
	return googleAuthURL + "?" + q.Encode()
}

// googleAuthCallbackHandler برگشت از صفحه‌ی گوگل (در مرورگر بازیکن)
// GET /auth/google/callback?state=&code=
func googleAuthCallbackHandler(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	state := q.Get("state")
	if state == "" {
		writeAuthPage(w, false, "درخواست نامعتبر", "این صفحه را ببند و از داخل بازی دوباره امتحان کن.")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	var p GoogleAuthPending
	if err := col(ColGoogleAuth).FindOne(ctx, bson.M{"state": state, "status": googlePendingStatus}).Decode(&p); err != nil {
		writeAuthPage(w, false, "این لینک منقضی شده", "از داخل بازی دوباره روی دکمه‌ی گوگل بزن.")
		return
	}

	finish := func(res googleResult) {
		upd := bson.M{"email": res.Email, "result_player_id": res.PlayerID, "code": res.Code, "message": res.Message}
		upd["status"] = googleErrorStatus
		if res.OK {
			upd["status"] = googleDoneStatus
		}
		_, _ = col(ColGoogleAuth).UpdateOne(ctx,
			bson.M{"state": state, "status": googlePendingStatus}, bson.M{"$set": upd})
	}

	if e := q.Get("error"); e != "" {
		finish(googleFail(AuthCodeCancelled, "ورود با گوگل لغو شد"))
		writeAuthPage(w, false, "لغو شد", "می‌توانی به بازی برگردی.")
		return
	}

	claims, err := exchangeGoogleCode(ctx, q.Get("code"), p.Verifier)
	if err != nil {
		fmt.Printf("⚠️ google code exchange: %v\n", err)
		finish(googleFail(AuthCodeGoogleFailed, "تأیید حساب گوگل انجام نشد"))
		writeAuthPage(w, false, "تأیید انجام نشد", "به بازی برگرد و دوباره امتحان کن.")
		return
	}

	res := applyGoogleIdentity(ctx, p.Intent, p.PlayerID, claims)
	finish(res)
	if !res.OK {
		writeAuthPage(w, false, "انجام نشد", res.Message)
		return
	}
	if p.Intent == AuthIntentLogin {
		writeAuthPage(w, true, "حسابت پیدا شد", "به بازی برگرد؛ حسابت همان‌جا بارگذاری می‌شود.")
		return
	}
	writeAuthPage(w, true, "حسابت به گوگل وصل شد", "پیشرفتت حالا محافظت می‌شود. به بازی برگرد.")
}

// googleAuthPollHandler نتیجه‌ی جریان — یک‌بارمصرف
// POST /auth/google/poll  {"poll_secret":"..."}
func googleAuthPollHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		PollSecret string `json:"poll_secret"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.PollSecret == "" {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	hash := hashToken(req.PollSecret)
	var p GoogleAuthPending
	if err := col(ColGoogleAuth).FindOne(ctx, bson.M{"poll_hash": hash}).Decode(&p); err != nil {
		httpErrorCode(w, "زمان ورود تمام شد؛ دوباره امتحان کن", AuthCodeExpired, http.StatusNotFound)
		return
	}
	if p.Status == googlePendingStatus {
		jsonResponse(w, map[string]interface{}{"status": googlePendingStatus})
		return
	}
	// مصرف اتمیک: فقط یک poll می‌تواند نتیجه را بردارد
	del, err := col(ColGoogleAuth).DeleteOne(ctx, bson.M{"poll_hash": hash, "status": p.Status})
	if err != nil || del.DeletedCount == 0 {
		httpErrorCode(w, "زمان ورود تمام شد؛ دوباره امتحان کن", AuthCodeExpired, http.StatusNotFound)
		return
	}
	res := googleResult{OK: p.Status == googleDoneStatus, Code: p.Code, Message: p.Message,
		Email: p.Email, PlayerID: p.ResultPlayerID}
	writeGoogleResult(ctx, w, p.Intent, p.Device, res)
}

// googleAuthTokenHandler مسیر پلاگین بومی: id_token مستقیم از کلاینت
// POST /auth/google/token  {"username":"...","intent":"link"|"login","id_token":"..."}
func googleAuthTokenHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	if googleCfg.ClientID == "" {
		httpErrorCode(w, "ورود با گوگل روی سرور تنظیم نشده", AuthCodeUnavailable, http.StatusServiceUnavailable)
		return
	}
	var req struct {
		Username string `json:"username"`
		Intent   string `json:"intent"`
		IDToken  string `json:"id_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IDToken == "" {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	playerID := ""
	switch req.Intent {
	case AuthIntentLink:
		probe, ok := requireLinkingDevice(ctx, w, r, req.Username)
		if !ok {
			return
		}
		playerID = probe.PlayerID
	case AuthIntentLogin:
	default:
		httpError(w, "intent نامعتبر است", http.StatusBadRequest)
		return
	}

	claims, err := verifyGoogleIDToken(ctx, req.IDToken)
	if err != nil {
		httpErrorCode(w, "تأیید حساب گوگل انجام نشد", AuthCodeGoogleFailed, http.StatusUnauthorized)
		return
	}
	writeGoogleResult(ctx, w, req.Intent, deviceName(r), applyGoogleIdentity(ctx, req.Intent, playerID, claims))
}

// writeGoogleResult پاسخ مشترک poll و token. برای ورود، توکن دستگاه تازه
// همین‌جا ساخته می‌شود تا هیچ‌وقت در دیتابیس به‌صورت خام نماند.
func writeGoogleResult(ctx context.Context, w http.ResponseWriter, intent, device string, res googleResult) {
	if !res.OK {
		jsonResponse(w, map[string]interface{}{"status": googleErrorStatus, "code": res.Code, "error": res.Message})
		return
	}
	out := map[string]interface{}{"status": googleDoneStatus, "intent": intent, "email": res.Email}
	if intent == AuthIntentLogin {
		player, err := getPlayerByID(ctx, res.PlayerID)
		if err != nil {
			jsonResponse(w, map[string]interface{}{"status": googleErrorStatus, "code": AuthCodeNoAccount, "error": "حساب پیدا نشد"})
			return
		}
		token, err := issueSession(ctx, player.PlayerID, device)
		if err != nil {
			jsonResponse(w, map[string]interface{}{"status": googleErrorStatus, "code": AuthCodeGoogleFailed, "error": "خطای سرور"})
			return
		}
		out["username"] = player.Username
		out["player_id"] = player.PlayerID
		out["level"] = player.Level
		out["session_token"] = token
	}
	jsonResponse(w, out)
}

// googleUnlinkHandler جدا کردن حساب از گوگل (دوباره مهمان)
// POST /auth/google/unlink  {"username":"..."}
func googleUnlinkHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req struct {
		Username string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	probe, err := loadAuthProbe(ctx, bson.M{"username": req.Username})
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	// نگهبان هم همین را چک کرده؛ این‌جا دوباره، چون جدا کردن حساس است
	if !sessionMatches(probe.Auth.Sessions, bearerToken(r)) {
		authRequired(w)
		return
	}
	if !isProtected(probe.Auth) {
		jsonResponse(w, map[string]interface{}{"success": true, "linked": false})
		return
	}
	_, err = col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": probe.PlayerID}, bson.M{
		"$unset": bson.M{"auth.google_id": "", "auth.email": "", "auth.google_name": "", "auth.linked_at": ""},
		"$set":   bson.M{"auth.provider": "guest", "auth.is_guest": true, "auth.email_verified": false, "updated_at": time.Now()},
	})
	if err != nil {
		httpError(w, "خطا در ذخیره", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, map[string]interface{}{"success": true, "linked": false})
}

// writeAuthPage صفحه‌ی کوچک نتیجه در مرورگر — هم‌رنگ بازی (سیاه/قرمز/طلایی)
func writeAuthPage(w http.ResponseWriter, ok bool, title, detail string) {
	accent, mark := "#d90b13", "✕"
	if ok {
		accent, mark = "#f0b429", "✓"
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Referrer-Policy", "no-referrer")
	fmt.Fprintf(w, `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>%s</title>
<style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
background:#0b0b0c;color:#f4f4f5;font-family:Tahoma,system-ui,sans-serif;padding:24px;box-sizing:border-box}
.card{max-width:420px;width:100%%;background:#141417;border:1px solid #2c2c31;border-top:4px solid %s;
border-radius:10px;padding:32px 24px;text-align:center}.mark{font-size:56px;color:%s;line-height:1}
h1{font-size:22px;margin:16px 0 8px}p{color:#b4b4ba;line-height:1.9;margin:0}</style></head>
<body><div class="card"><div class="mark">%s</div><h1>%s</h1><p>%s</p></div></body></html>`,
		html.EscapeString(title), accent, accent, mark, html.EscapeString(title), html.EscapeString(detail))
}

// serverKeyOnly مسیرهای داخلیِ سرویس‌به‌سرویس. /match/result آمار و سکه‌ی هر
// بازیکنی را عوض می‌کند و هیچ کلاینتی صدایش نمی‌زند (نتیجه‌ی مسابقه را خودِ
// هاب ثبت می‌کند)؛ پس بدون کلید GAME_SERVER_KEY کاملاً بسته است.
func serverKeyOnly(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := os.Getenv("GAME_SERVER_KEY")
		got := r.Header.Get("X-Server-Key")
		if key == "" || subtle.ConstantTimeCompare([]byte(key), []byte(got)) != 1 {
			httpError(w, "دسترسی ندارید", http.StatusForbidden)
			return
		}
		next(w, r)
	}
}
