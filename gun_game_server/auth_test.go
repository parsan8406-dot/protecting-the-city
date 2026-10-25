package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

func TestSessionMatchesOnlyTheRightToken(t *testing.T) {
	token, s, err := newSession("android")
	if err != nil {
		t.Fatal(err)
	}
	if s.TokenHash == token || len(s.TokenHash) != 64 {
		t.Fatalf("خودِ توکن نباید ذخیره شود؛ فقط هش ۶۴ کاراکتری: %q", s.TokenHash)
	}
	other, s2, _ := newSession("pc")
	sessions := []PlayerSession{s2, s}
	if !sessionMatches(sessions, token) || !sessionMatches(sessions, other) {
		t.Fatal("توکن هر دو دستگاه باید قبول شود")
	}
	if sessionMatches(sessions, "") || sessionMatches(sessions, token+"x") || sessionMatches(nil, token) {
		t.Fatal("توکن خالی/اشتباه یا حساب بدون دستگاه نباید قبول شود")
	}
}

func TestBearerToken(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	if bearerToken(r) != "" {
		t.Fatal("بدون هدر باید خالی باشد")
	}
	r.Header.Set("Authorization", "Bearer  abc.def ")
	if got := bearerToken(r); got != "abc.def" {
		t.Fatalf("got %q", got)
	}
	r.Header.Set("Authorization", "Basic abc")
	if bearerToken(r) != "" {
		t.Fatal("فقط Bearer قبول است")
	}
}

// نگهبان باید هم ?username= و هم username بدنه را ببیند، و بدنه را برای
// هندلر دست‌نخورده برگرداند
func TestActingUsernamesReadsQueryAndBodyAndRestoresBody(t *testing.T) {
	body := `{"username":"victim","item_id":"awm"}`
	r := httptest.NewRequest(http.MethodPost, "/buy_item?username=me", strings.NewReader(body))
	w := httptest.NewRecorder()
	names, ok := actingUsernames(w, r)
	if !ok {
		t.Fatal("نباید رد شود")
	}
	if len(names) != 2 || names[0] != "me" || names[1] != "victim" {
		t.Fatalf("هر دو اسم باید بررسی شوند: %v", names)
	}
	rest, _ := io.ReadAll(r.Body)
	if string(rest) != body {
		t.Fatalf("بدنه برای هندلر خراب شد: %q", rest)
	}

	big := bytes.Repeat([]byte("a"), maxGuardBodyBytes+10)
	r = httptest.NewRequest(http.MethodPost, "/x", bytes.NewReader(big))
	w = httptest.NewRecorder()
	if _, ok := actingUsernames(w, r); ok || w.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("بدنه‌ی خیلی بزرگ باید رد شود، کد %d", w.Code)
	}
}

func TestAuthGuardPassesThroughWithoutDatabase(t *testing.T) {
	called := false
	h := authGuard(func(w http.ResponseWriter, r *http.Request) { called = true })
	h(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/profile?username=a", nil))
	if !called {
		t.Fatal("بدون دیتابیس (تست‌ها) نگهبان نباید چیزی را ببندد")
	}
}

func makeIDToken(t *testing.T, claims map[string]interface{}) string {
	t.Helper()
	payload, _ := json.Marshal(claims)
	return "eyJhbGciOiJSUzI1NiJ9." + base64.RawURLEncoding.EncodeToString(payload) + ".sig"
}

func TestGoogleClaimsValidation(t *testing.T) {
	now := time.Now()
	good := map[string]interface{}{
		"iss": "https://accounts.google.com", "aud": "client-1", "sub": "1234",
		"email": "Player@Gmail.com", "email_verified": true, "exp": float64(now.Add(time.Hour).Unix()),
	}
	c, err := parseIDTokenPayload(makeIDToken(t, good))
	if err != nil {
		t.Fatal(err)
	}
	if err := c.validate("client-1", now); err != nil {
		t.Fatalf("توکن سالم رد شد: %v", err)
	}
	if !c.EmailVerified || c.Sub != "1234" {
		t.Fatalf("ادعاها درست خوانده نشد: %+v", c)
	}
	if c.validate("other-client", now) == nil {
		t.Fatal("توکنِ کلاینتِ دیگر نباید قبول شود")
	}
	if c.validate("client-1", now.Add(2*time.Hour)) == nil {
		t.Fatal("توکن منقضی نباید قبول شود")
	}
	bad := googleClaims{Sub: "1", Iss: "https://evil.example", Aud: []string{"client-1"}, Exp: now.Add(time.Hour).Unix()}
	if bad.validate("client-1", now) == nil {
		t.Fatal("صادرکننده‌ی غیرگوگل نباید قبول شود")
	}
	if (googleClaims{Iss: googleIssuer, Aud: []string{"c"}, Exp: now.Add(time.Hour).Unix()}).validate("c", now) == nil {
		t.Fatal("بدون sub نباید قبول شود")
	}
	if _, err := parseIDTokenPayload("not-a-jwt"); err == nil {
		t.Fatal("توکن بدشکل باید خطا بدهد")
	}
}

// پاسخ tokeninfo همه‌چیز را رشته می‌دهد
func TestClaimsFromTokenInfoStrings(t *testing.T) {
	c := claimsFromMap(map[string]interface{}{
		"iss": "accounts.google.com", "aud": "c", "sub": "9", "email_verified": "true", "exp": "4102444800",
	})
	if !c.EmailVerified || c.Exp != 4102444800 || len(c.Aud) != 1 {
		t.Fatalf("%+v", c)
	}
	if err := c.validate("c", time.Now()); err != nil {
		t.Fatal(err)
	}
}

func TestGoogleConsentURLUsesPKCE(t *testing.T) {
	old := googleCfg
	googleCfg = googleConfig{ClientID: "cid", ClientSecret: "sec", RedirectURL: "https://api.example/auth/google/callback"}
	defer func() { googleCfg = old }()

	raw := googleConsentURL("st4te", "verifier-verifier-verifier-verifier-verifier-1234")
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	q := u.Query()
	if q.Get("code_challenge_method") != "S256" || q.Get("code_challenge") == "" {
		t.Fatal("PKCE باید S256 باشد")
	}
	if q.Get("state") != "st4te" || q.Get("client_id") != "cid" || q.Get("redirect_uri") != googleCfg.RedirectURL {
		t.Fatalf("پارامترها: %v", q)
	}
	if strings.Contains(raw, "sec") || strings.Contains(raw, "verifier-verifier") {
		t.Fatal("رمز کلاینت و verifier نباید در آدرس مرورگر باشند")
	}
}

func TestServerKeyOnlyIsClosedWithoutKey(t *testing.T) {
	h := serverKeyOnly(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusTeapot) })

	t.Setenv("GAME_SERVER_KEY", "")
	w := httptest.NewRecorder()
	h(w, httptest.NewRequest(http.MethodPost, "/match/result", nil))
	if w.Code != http.StatusForbidden {
		t.Fatalf("بدون کلیدِ تنظیم‌شده باید بسته باشد، کد %d", w.Code)
	}

	t.Setenv("GAME_SERVER_KEY", "k1")
	w = httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodPost, "/match/result", nil)
	r.Header.Set("X-Server-Key", "wrong")
	h(w, r)
	if w.Code != http.StatusForbidden {
		t.Fatalf("کلید اشتباه، کد %d", w.Code)
	}
	w = httptest.NewRecorder()
	r.Header.Set("X-Server-Key", "k1")
	h(w, r)
	if w.Code != http.StatusTeapot {
		t.Fatalf("کلید درست باید رد شود، کد %d", w.Code)
	}
}

func TestMaskEmailAndAuthPageEscaping(t *testing.T) {
	if got := maskEmail("parsa@gmail.com"); got != "pa***@gmail.com" {
		t.Fatalf("got %q", got)
	}
	if got := maskEmail("a@b.c"); got != "a***@b.c" {
		t.Fatalf("got %q", got)
	}
	w := httptest.NewRecorder()
	writeAuthPage(w, false, "<script>x</script>", "ok")
	if strings.Contains(w.Body.String(), "<script>x") {
		t.Fatal("متن صفحه باید escape شود")
	}
}

func TestValidateUsernameCountsLettersNotBytes(t *testing.T) {
	for _, ok := range []string{"علی", "Player_2", "مهدی.رضایی", "Ali Reza"} {
		if msg := validateUsername(ok); msg != "" {
			t.Fatalf("%q باید معتبر باشد: %s", ok, msg)
		}
	}
	for _, bad := range []string{"ab", strings.Repeat("ب", 21), "a<b>c", "two  spaces"} {
		if validateUsername(bad) == "" {
			t.Fatalf("%q نباید معتبر باشد", bad)
		}
	}
}

func TestPersonalizeBroadcasts(t *testing.T) {
	p := &PlayerModel{PlayerID: "1", ReadBroadcasts: []string{"b1"}, HiddenBroadcasts: []string{"b2"}}
	msgs := []MessageModel{
		{MessageID: "b1", RecipientID: "*", IsRead: false},
		{MessageID: "b2", RecipientID: "*"},
		{MessageID: "b3", RecipientID: "*", IsRead: true}, // سند مشترک «خوانده» ولی نه برای این بازیکن
		{MessageID: "m1", RecipientID: "1", IsRead: true},
	}
	out := personalizeBroadcasts(p, msgs)
	if len(out) != 3 {
		t.Fatalf("پیام پنهان‌شده باید حذف شود: %d", len(out))
	}
	if !out[0].IsRead || out[1].IsRead || !out[2].IsRead {
		t.Fatalf("وضعیت خوانده‌شدن اشتباه: %+v", out)
	}
}

func TestAchievementCatalogIsSane(t *testing.T) {
	metrics := achievementMetrics(&PlayerModel{})
	seen := map[string]bool{}
	for _, d := range achievementCatalog {
		if seen[d.AchievementID] {
			t.Fatalf("شناسه‌ی تکراری %s", d.AchievementID)
		}
		seen[d.AchievementID] = true
		if _, ok := metrics[d.Metric]; !ok {
			t.Fatalf("%s متریکِ ناشناخته دارد: %s", d.AchievementID, d.Metric)
		}
		if d.Target <= 0 || d.Name == "" {
			t.Fatalf("%s هدف یا اسم ندارد", d.AchievementID)
		}
	}
	// بازیکن تازه باید همان مسابقه‌ی اول چیزی باز کند
	first := 0
	for _, d := range achievementCatalog {
		if d.Target == 1 {
			first++
		}
	}
	if first == 0 {
		t.Fatal("هیچ دستاوردِ «اولین»ی نیست")
	}
}

func TestNextAchievementPicksClosestLocked(t *testing.T) {
	catalog := []map[string]interface{}{
		{"achievement_id": "a", "target": 10, "progress": 10, "unlocked": true},
		{"achievement_id": "b", "target": 100, "progress": 20, "unlocked": false},
		{"achievement_id": "c", "target": 10, "progress": 7, "unlocked": false},
	}
	if got := nextAchievement(catalog); got == nil || got["achievement_id"] != "c" {
		t.Fatalf("got %v", got)
	}
	if nextAchievement(catalog[:1]) != nil {
		t.Fatal("وقتی همه باز شده‌اند هدف بعدی نیست")
	}
}

func TestApplyDotEnvKeepsExistingEnv(t *testing.T) {
	t.Setenv("DOTENV_PROBE_KEEP", "from-system")
	os.Unsetenv("DOTENV_PROBE_NEW")
	defer os.Unsetenv("DOTENV_PROBE_NEW")
	src := "# comment\n\nDOTENV_PROBE_NEW = \"value-1\"\nDOTENV_PROBE_KEEP=from-file\nbroken line\n"
	if n := applyDotEnv(bufio.NewScanner(strings.NewReader(src))); n != 1 {
		t.Fatalf("فقط متغیر تازه باید ست شود، شد %d", n)
	}
	if os.Getenv("DOTENV_PROBE_NEW") != "value-1" || os.Getenv("DOTENV_PROBE_KEEP") != "from-system" {
		t.Fatal("مقدار سیستم باید برنده باشد و کوتیشن حذف شود")
	}
}
