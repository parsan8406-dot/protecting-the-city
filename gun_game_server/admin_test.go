package main

import (
	"testing"
	"time"
)

func TestBanActive(t *testing.T) {
	now := time.Now()
	past, future := now.Add(-time.Hour), now.Add(time.Hour)
	cases := []struct {
		banned bool
		until  *time.Time
		want   bool
	}{
		{false, nil, false},
		{true, nil, true},     // دائمی
		{true, &future, true}, // موقتِ در جریان
		{true, &past, false},  // موقتِ تمام‌شده
		{false, &future, false},
	}
	for i, c := range cases {
		if got := banActive(c.banned, c.until, now); got != c.want {
			t.Errorf("case %d: got %v want %v", i, got, c.want)
		}
	}
}

func TestLoadAdminAccounts(t *testing.T) {
	t.Setenv("ADMIN_ACCOUNTS", "parsa:admin:long-enough-pass, ali:support:pass:with:colons ,bad:root:long-enough-pass,short:admin:123")
	accs := loadAdminAccounts()
	if len(accs) != 2 {
		t.Fatalf("want 2 valid accounts, got %d: %+v", len(accs), accs)
	}
	if accs[1].Password != "pass:with:colons" || accs[1].Role != adminRoleSupport {
		t.Errorf("colon in password must survive: %+v", accs[1])
	}
	if _, ok := checkAdminLogin("parsa", "long-enough-pass"); !ok {
		t.Error("correct login rejected")
	}
	if _, ok := checkAdminLogin("parsa", "wrong-password-x"); ok {
		t.Error("wrong password accepted")
	}
	if _, ok := checkAdminLogin("ali", "long-enough-pass"); ok {
		t.Error("password of another account accepted")
	}
}

func TestAdminSessionRevokedWhenAccountRemoved(t *testing.T) {
	t.Setenv("ADMIN_ACCOUNTS", "parsa:admin:long-enough-pass")
	acc, _ := checkAdminLogin("parsa", "long-enough-pass")
	token, _ := adminSessions.create(acc, "127.0.0.1")
	if adminSessions.get(token) == nil {
		t.Fatal("fresh session not found")
	}
	t.Setenv("ADMIN_ACCOUNTS", "other:admin:long-enough-pass")
	if adminSessions.get(token) != nil {
		t.Error("session must die when its account is removed from .env")
	}
}

func TestTOTPRFC6238(t *testing.T) {
	// بردارِ آزمونِ RFC 6238 (SHA1): کلید "12345678901234567890"، t=59 → 94287082
	secret := []byte("12345678901234567890")
	if got := totpAt(secret, 59/30); got != "287082" {
		t.Fatalf("got %s want 287082", got)
	}
	b32 := "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
	now := time.Unix(59, 0)
	if !verifyTOTP("u1", b32, "287082", now) {
		t.Fatal("valid code rejected")
	}
	if verifyTOTP("u1", b32, "287082", now) {
		t.Fatal("same code accepted twice (replay)")
	}
	if verifyTOTP("u2", b32, "000000", now) {
		t.Fatal("wrong code accepted")
	}
}

func TestAdminPasswordHash(t *testing.T) {
	h, err := hashAdminPassword("correct horse battery")
	if err != nil {
		t.Fatal(err)
	}
	if !verifyAdminPassword(h, "correct horse battery") || verifyAdminPassword(h, "correct horse batterY") {
		t.Fatal("hash verify wrong")
	}
	t.Setenv("ADMIN_REQUIRE_HASH", "1")
	if verifyAdminPassword("plain-text-password", "plain-text-password") {
		t.Fatal("plaintext accepted while ADMIN_REQUIRE_HASH=1")
	}
}

func TestGlobalLoginLock(t *testing.T) {
	now := time.Now()
	tripped := false
	for i := 0; i < adminGlobalFailLimit; i++ {
		tripped = adminLoginFailed(now) || tripped
	}
	if !tripped || !adminLoginBlocked(now) {
		t.Fatal("global lock should trip after the limit")
	}
	if adminLoginBlocked(now.Add(adminGlobalFailWindow + time.Second)) {
		t.Fatal("global lock should expire")
	}
	adminFails.Lock()
	adminFails.lockedUntil = time.Time{}
	adminFails.Unlock()
}
