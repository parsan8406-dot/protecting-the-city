package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// جریان کاملِ حساب محافظت‌شده روی دیتابیسِ واقعی (اگر مونگو بالا نباشد رد
// می‌شود): اتصال به گوگل، نگهبان، وب‌سوکت، ورود روی دستگاه تازه، جدا کردن.

func seedAuthPlayer(t *testing.T, ctx context.Context, name, playerID string) {
	t.Helper()
	cleanup := func() {
		_, _ = col(ColPlayers).DeleteOne(ctx, bson.M{"player_id": playerID})
		_, _ = col(ColMessages).DeleteMany(ctx, bson.M{"recipient_id": playerID})
	}
	cleanup()
	p := NewDefaultPlayer(name, playerID)
	if _, err := col(ColPlayers).InsertOne(ctx, p); err != nil {
		t.Skipf("نمی‌شود بازیکنِ تست ساخت: %v", err)
	}
	t.Cleanup(cleanup)
}

func guardStatus(t *testing.T, target, body, token string) int {
	t.Helper()
	h := authGuard(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) })
	r := httptest.NewRequest(http.MethodPost, target, strings.NewReader(body))
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	h(w, r)
	return w.Code
}

func TestProtectedAccountFlow(t *testing.T) {
	ctx := withDB(t)
	const name, pid = "__auth_flow_probe", "auth_probe_1"
	const other, otherPID = "__auth_flow_other", "auth_probe_2"
	seedAuthPlayer(t, ctx, name, pid)
	seedAuthPlayer(t, ctx, other, otherPID)

	token, err := issueSession(ctx, pid, "test-device")
	if err != nil {
		t.Fatal(err)
	}
	claims := googleClaims{Sub: "test-sub-auth-flow-probe", Email: "Probe@Example.com", EmailVerified: true,
		Iss: googleIssuer, Aud: []string{"c"}, Exp: time.Now().Add(time.Hour).Unix()}
	_, _ = col(ColPlayers).UpdateMany(ctx, bson.M{"auth.google_id": claims.Sub},
		bson.M{"$unset": bson.M{"auth.google_id": ""}})

	// حسابِ قدیمی که هنوز هیچ دستگاهی ثبت نکرده: نگهبان کاری ندارد، وگرنه
	// بازیکنِ پیش از افزوده‌شدنِ توکن پشتِ در می‌ماند (claimFirstSession).
	if code := guardStatus(t, "/buy_item", `{"username":"`+other+`"}`, ""); code != http.StatusNoContent {
		t.Fatalf("حساب بدون نشست نباید بسته باشد، کد %d", code)
	}
	// ولی حسابِ مهمانی که دستگاه ثبت کرده، بدون توکن بسته است — وگرنه
	// «فقط دانستنِ اسم» برای تصاحب حساب کافی بود.
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, ""); code != http.StatusUnauthorized {
		t.Fatalf("مهمانِ دارای نشست بدون توکن باید 401 باشد، کد %d", code)
	}
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, token); code != http.StatusNoContent {
		t.Fatalf("مهمان با توکن درست باید رد شود، کد %d", code)
	}
	if wsJoinAllowed(name, "") || !wsJoinAllowed(name, token) {
		t.Fatal("join وب‌سوکت برای مهمانِ دارای نشست باید توکن بخواهد")
	}

	// اتصال
	if res := applyGoogleIdentity(ctx, AuthIntentLink, pid, claims); !res.OK {
		t.Fatalf("اتصال انجام نشد: %+v", res)
	}
	if res := applyGoogleIdentity(ctx, AuthIntentLink, otherPID, claims); res.OK || res.Code != AuthCodeGoogleInUse {
		t.Fatalf("یک حساب گوگل نباید به دو حساب وصل شود: %+v", res)
	}

	// حالا محافظت‌شده است
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, ""); code != http.StatusUnauthorized {
		t.Fatalf("بدون توکن باید 401 باشد، کد %d", code)
	}
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, "wrong-token"); code != http.StatusUnauthorized {
		t.Fatalf("توکن اشتباه باید 401 باشد، کد %d", code)
	}
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, token); code != http.StatusNoContent {
		t.Fatalf("با توکن درست باید رد شود، کد %d", code)
	}
	// فریب: اسمِ خودم در query، اسمِ قربانی در بدنه
	if code := guardStatus(t, "/buy_item?username="+other, `{"username":"`+name+`"}`, ""); code != http.StatusUnauthorized {
		t.Fatalf("اسم بدنه هم باید بررسی شود، کد %d", code)
	}
	if wsJoinAllowed(name, "") || !wsJoinAllowed(name, token) || !wsJoinAllowed(other, "") {
		t.Fatal("قانون join وب‌سوکت درست نیست")
	}
	// حسابِ محافظت‌شده دستگاه «اولین‌ادعا» نمی‌پذیرد
	if tok, _ := claimFirstSession(ctx, pid, "x"); tok != "" {
		t.Fatal("حساب محافظت‌شده نباید توکن مجانی بدهد")
	}

	// ورود روی دستگاه تازه
	res := applyGoogleIdentity(ctx, AuthIntentLogin, "", claims)
	if !res.OK || res.PlayerID != pid {
		t.Fatalf("ورود باید همین حساب را پیدا کند: %+v", res)
	}
	fresh, err := issueSession(ctx, pid, "new-phone")
	if err != nil || fresh == token {
		t.Fatalf("توکن تازه ساخته نشد: %v", err)
	}
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, fresh); code != http.StatusNoContent {
		t.Fatalf("توکن دستگاه تازه باید کار کند، کد %d", code)
	}
	unknown := claims
	unknown.Sub = "test-sub-nobody"
	if res := applyGoogleIdentity(ctx, AuthIntentLogin, "", unknown); res.OK || res.Code != AuthCodeNoAccount {
		t.Fatalf("گوگلِ ناشناس نباید حسابی پیدا کند: %+v", res)
	}

	// جدا کردن
	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodPost, "/auth/google/unlink", strings.NewReader(`{"username":"`+name+`"}`))
	r.Header.Set("Authorization", "Bearer "+fresh)
	googleUnlinkHandler(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("جدا کردن: کد %d %s", w.Code, w.Body.String())
	}
	// جدا کردن گوگل حساب را بی‌صاحب نمی‌کند: دستگاه‌های ثبت‌شده سر جایشان
	// می‌مانند، پس هنوز توکن لازم است و هر کسی با دانستنِ اسم نمی‌تواند
	// حساب را بردارد.
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, ""); code != http.StatusUnauthorized {
		t.Fatalf("بعد از جدا کردن هم بدون توکن باید 401 باشد، کد %d", code)
	}
	if code := guardStatus(t, "/buy_item", `{"username":"`+name+`"}`, fresh); code != http.StatusNoContent {
		t.Fatalf("بعد از جدا کردن، دستگاهِ خودی باید کار کند، کد %d", code)
	}
}

// سقف دستگاه‌ها: قدیمی‌ترین کنار می‌رود
func TestSessionsAreCapped(t *testing.T) {
	ctx := withDB(t)
	const name, pid = "__auth_cap_probe", "auth_probe_cap"
	seedAuthPlayer(t, ctx, name, pid)
	first, _ := issueSession(ctx, pid, "d0")
	for i := 0; i < MaxSessionsPerPlayer; i++ {
		if _, err := issueSession(ctx, pid, "d"); err != nil {
			t.Fatal(err)
		}
	}
	probe, err := loadAuthProbe(ctx, bson.M{"player_id": pid})
	if err != nil {
		t.Fatal(err)
	}
	if len(probe.Auth.Sessions) != MaxSessionsPerPlayer {
		t.Fatalf("باید %d دستگاه بماند، هست %d", MaxSessionsPerPlayer, len(probe.Auth.Sessions))
	}
	if sessionMatches(probe.Auth.Sessions, first) {
		t.Fatal("قدیمی‌ترین دستگاه باید کنار رفته باشد")
	}
}

// آمار پروفایل از خودِ راند: کشته، آخرین سلاح، فرم اخیر و دستاورد «اولین خون»
func TestProfileStatsFromRound(t *testing.T) {
	ctx := withDB(t)
	if err := seedAchievements(ctx); err != nil {
		t.Skipf("کاتالوگ دستاورد ساخته نشد: %v", err)
	}
	const name, pid = "__stats_probe", "stats_probe_1"
	seedAuthPlayer(t, ctx, name, pid)

	part := MatchParticipant{PlayerID: pid, Username: name, Kills: 3, Deaths: 1, GrenadeKills: 1, WeaponUsed: "awm"}
	if err := persistProfileStats(ctx, pid, "strike", part, 120, false); err != nil {
		t.Fatal(err)
	}
	if err := persistProfileStats(ctx, pid, "strike", MatchParticipant{WeaponUsed: "mp5"}, 60, true); err != nil {
		t.Fatal(err)
	}
	p, err := getPlayerByID(ctx, pid)
	if err != nil {
		t.Fatal(err)
	}
	if p.Stats.Kills != 3 || p.Stats.Deaths != 1 || p.Stats.GrenadeKills != 1 || p.Stats.PlaytimeSeconds != 180 {
		t.Fatalf("آمار ثبت نشد: %+v", p.Stats)
	}
	if p.Stats.LastUsedWeapon != "mp5" {
		t.Fatalf("آخرین سلاح باید mp5 باشد: %q", p.Stats.LastUsedWeapon)
	}
	// «تعداد بازی» را فقط ApplyMatchResult می‌نویسد — حتی در مساوی.
	// قبلاً مساوی استثنا بود چون endRound در مساوی ApplyMatchResult را صدا
	// نمی‌زد؛ حالا که مساوی هم بردِ کامل است، شمردنش این‌جا یعنی دوبار.
	if p.Stats.TotalMatches != 0 {
		t.Fatalf("تعداد بازی را فقط ApplyMatchResult می‌نویسد، نه persistProfileStats: %d", p.Stats.TotalMatches)
	}
	if len(p.RecentMatches) != 2 || !p.RecentMatches[1].Draw {
		t.Fatalf("فرم اخیر: %+v", p.RecentMatches)
	}
	got := map[string]bool{}
	for _, a := range p.Achievements {
		if got[a.AchievementID] {
			t.Fatalf("دستاورد تکراری %s", a.AchievementID)
		}
		got[a.AchievementID] = true
	}
	// «اولین خون» از کشته‌ی همین تابع می‌آید. «اولین مسابقه» به تعدادِ
	// بازی وابسته است و آن را ApplyMatchResult می‌نویسد، نه این تابع —
	// پس این‌جا هنوز باز نشده و همان هم درست است.
	if !got["ach_first_blood"] {
		t.Fatalf("«اولین خون» باز نشد: %v", got)
	}
	if got["ach_first_match"] {
		t.Fatalf("«اولین مسابقه» به تعداد بازی وابسته است و هنوز نباید باز شده باشد: %v", got)
	}
	// بررسی دوباره چیزی را دو بار باز نمی‌کند
	if fresh := checkAndUnlockAchievements(ctx, p); len(fresh) != 0 {
		t.Fatalf("دستاورد دوباره باز شد: %+v", fresh)
	}
}
