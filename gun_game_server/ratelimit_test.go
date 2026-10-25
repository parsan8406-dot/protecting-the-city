package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRateLimiterRefills(t *testing.T) {
	l := newRateLimiter("t", 60, 3) // یک نشانه در ثانیه، ظرفیت ۳

	for i := 0; i < 3; i++ {
		if !l.allow("a") {
			t.Fatalf("درخواست %d باید از ظرفیت اولیه رد شود", i+1)
		}
	}
	if l.allow("a") {
		t.Fatal("بعد از تمام شدن ظرفیت باید رد شود")
	}
	// کلید دیگر سطل خودش را دارد
	if !l.allow("b") {
		t.Fatal("سطلِ هر کلید باید جدا باشد")
	}

	// عقب بردنِ ساعتِ سطل = گذشتِ زمان
	l.mu.Lock()
	l.buckets["a"].last = time.Now().Add(-2 * time.Second)
	l.mu.Unlock()
	if !l.allow("a") {
		t.Fatal("بعد از گذشت زمان باید دوباره پر شود")
	}
}

func TestRateLimiterCapsBurst(t *testing.T) {
	l := newRateLimiter("t", 60, 2)
	l.allow("a")
	// یک ساعت بی‌حرکتی نباید سهمیه‌ی یک‌ساعته بدهد
	l.mu.Lock()
	l.buckets["a"].last = time.Now().Add(-time.Hour)
	l.mu.Unlock()
	if !l.allow("a") || !l.allow("a") {
		t.Fatal("ظرفیت باید پر شده باشد")
	}
	if l.allow("a") {
		t.Fatal("سطل نباید از ظرفیتش بیشتر جمع کند")
	}
}

// مهاجمی که فقط اسم حساب را می‌داند نباید بتواند سیل درخواست بفرستد
func TestSensitiveRouteIsLimited(t *testing.T) {
	saved := sensitiveIPLimiter
	sensitiveIPLimiter = newRateLimiter("sensitive", 30, 5)
	t.Cleanup(func() { sensitiveIPLimiter = saved })

	h := rateLimitSensitive(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})

	blocked := 0
	for i := 0; i < 12; i++ {
		r := httptest.NewRequest(http.MethodGet, "/get_player?username=Player1", nil)
		r.RemoteAddr = "198.51.100.7:1234"
		w := httptest.NewRecorder()
		h(w, r)
		if w.Code == http.StatusTooManyRequests {
			blocked++
		}
	}
	if blocked == 0 {
		t.Fatal("شمردنِ حساب‌ها باید بعد از چند درخواست بسته شود")
	}
}

// X-Forwarded-For فقط وقتی خوانده می‌شود که به پراکسی اعتماد کرده باشیم،
// وگرنه مهاجم با عوض کردنِ هدر سهمیه‌ی بی‌نهایت می‌گیرد.
func TestClientIPIgnoresForwardedHeaderByDefault(t *testing.T) {
	saved := trustProxy
	t.Cleanup(func() { trustProxy = saved })

	r := httptest.NewRequest(http.MethodGet, "/", nil)
	r.RemoteAddr = "203.0.113.9:5555"
	r.Header.Set("X-Forwarded-For", "1.2.3.4")

	trustProxy = false
	if got := clientIP(r); got != "203.0.113.9" {
		t.Fatalf("بدون اعتماد به پراکسی باید RemoteAddr باشد، شد %q", got)
	}

	trustProxy = true
	if got := clientIP(r); got != "1.2.3.4" {
		t.Fatalf("با اعتماد به پراکسی باید هدر خوانده شود، شد %q", got)
	}
}

// زنجیره‌ی جعلی: کلاینت خودش چند آی‌پی جلوی هدر می‌گذارد. با یک پراکسیِ
// خودی فقط آخرین ورودی قابل اعتماد است.
func TestClientIPTakesLastTrustedHop(t *testing.T) {
	savedTrust, savedHops := trustProxy, trustProxyHops
	t.Cleanup(func() { trustProxy, trustProxyHops = savedTrust, savedHops })
	trustProxy, trustProxyHops = true, 1

	r := httptest.NewRequest(http.MethodGet, "/", nil)
	r.RemoteAddr = "10.0.0.1:80"
	r.Header.Set("X-Forwarded-For", "9.9.9.9, 8.8.8.8, 203.0.113.5")

	if got := clientIP(r); got != "203.0.113.5" {
		t.Fatalf("باید آخرین گامِ مورد اعتماد باشد، شد %q", got)
	}
}
