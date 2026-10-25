package main

import (
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

// =============================================================================
// محدودیت نرخ درخواست‌ها
// =============================================================================
//
// تا پیش از این فقط چت محدودیت داشت (handlers_chat.go) و بقیه‌ی مسیرها باز
// بودند. مشکل این بود که شمردنِ حساب‌ها ارزان بود: کلاینت اسم مهمان را
// «Player<عدد پنج‌رقمی>» می‌سازد، پس صد هزار درخواست کلِ حساب‌های مهمان را
// پیدا می‌کرد. حالا توکنِ دستگاه جلوی استفاده از حساب دیگری را می‌گیرد
// (handlers_auth.go: needsToken)، ولی شمردن هنوز نشتِ اطلاعات است و
// ساختِ بی‌پایانِ حساب هنوز می‌تواند دیتابیس را پر کند.
//
// سطل نشانه‌ای (token bucket) ساده: هر کلید ظرفیتی دارد که با نرخ ثابت پر
// می‌شود. burst اجازه می‌دهد بازیکنِ عادی که موقع باز شدنِ بازی چند درخواست
// پشت سر هم می‌فرستد گیر نکند.

// rateBucket یک سطل برای یک کلید (آی‌پی یا حساب)
type rateBucket struct {
	tokens float64
	last   time.Time
}

// rateLimiter مجموعه‌ی سطل‌ها با یک نرخ و ظرفیت مشخص
type rateLimiter struct {
	mu      sync.Mutex
	buckets map[string]*rateBucket
	rate    float64 // نشانه بر ثانیه
	burst   float64 // ظرفیت سطل
	name    string
}

func newRateLimiter(name string, perMinute, burst int) *rateLimiter {
	return &rateLimiter{
		buckets: make(map[string]*rateBucket),
		rate:    float64(perMinute) / 60.0,
		burst:   float64(burst),
		name:    name,
	}
}

// allow یک نشانه برمی‌دارد. false یعنی سهمیه تمام شده.
func (l *rateLimiter) allow(key string) bool {
	if key == "" {
		return true
	}
	now := time.Now()

	l.mu.Lock()
	defer l.mu.Unlock()

	b, ok := l.buckets[key]
	if !ok {
		// سطل تازه پر شروع می‌شود، منهای همین درخواست
		l.buckets[key] = &rateBucket{tokens: l.burst - 1, last: now}
		l.sweepLocked(now)
		return true
	}

	b.tokens += now.Sub(b.last).Seconds() * l.rate
	if b.tokens > l.burst {
		b.tokens = l.burst
	}
	b.last = now

	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// sweepLocked سطل‌های پرشده‌ی بی‌استفاده را دور می‌ریزد تا نقشه بی‌نهایت بزرگ
// نشود. فقط وقتی صدا زده می‌شود که کلید تازه‌ای اضافه شده باشد.
func (l *rateLimiter) sweepLocked(now time.Time) {
	if len(l.buckets) <= rateLimiterMaxKeys {
		return
	}
	// سطلی که به اندازه‌ی پر شدنِ کامل بی‌حرکت مانده، با سطلِ تازه فرقی ندارد
	idle := time.Duration(l.burst/l.rate) * time.Second
	for k, b := range l.buckets {
		if now.Sub(b.last) > idle {
			delete(l.buckets, k)
		}
	}
}

const rateLimiterMaxKeys = 20000

// =============================================================================
// آی‌پیِ واقعیِ درخواست
// =============================================================================
//
// سرور پشت nginx (و آروان‌کلاد) است، پس RemoteAddr همیشه آی‌پیِ پراکسی است و
// محدودیتِ آی‌پی بی‌معنی می‌شود. ولی X-Forwarded-For را هم نمی‌شود کورکورانه
// باور کرد: اگر سرور مستقیم در معرض اینترنت باشد، مهاجم با یک هدرِ ساختگی
// سهمیه‌ی بی‌نهایت می‌گیرد. پس فقط وقتی خوانده می‌شود که TRUST_PROXY=1 باشد.
//
// TRUST_PROXY_HOPS تعداد پراکسی‌های خودی است (پیش‌فرض ۱). از راستِ زنجیره‌ی
// X-Forwarded-For همین تعداد عقب می‌رویم؛ هرچه قبلش باشد را خودِ کلاینت
// می‌توانسته جعل کند.
var (
	trustProxy     = os.Getenv("TRUST_PROXY") == "1"
	trustProxyHops = func() int {
		n, err := strconv.Atoi(os.Getenv("TRUST_PROXY_HOPS"))
		if err != nil || n < 1 {
			return 1
		}
		return n
	}()
)

func clientIP(r *http.Request) string {
	if trustProxy {
		if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
			parts := strings.Split(xff, ",")
			idx := len(parts) - trustProxyHops
			if idx < 0 {
				idx = 0
			}
			if ip := strings.TrimSpace(parts[idx]); ip != "" {
				return ip
			}
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// =============================================================================
// میدل‌ورها
// =============================================================================

var (
	// سقفِ کلیِ هر آی‌پی. بازیکنِ عادی موقع باز شدنِ بازی حدود ۱۵ درخواست
	// می‌فرستد، پس این خیلی بالاتر از استفاده‌ی واقعی است و فقط جلوی
	// سیلِ درخواست را می‌گیرد.
	globalIPLimiter = newRateLimiter("ip", 300, 120)

	// مسیرهای حساس: ساختِ حساب، کد هدیه، جایزه‌ی تبلیغ، خرید، ورود با گوگل،
	// جستجوی بازیکن. این‌ها یا پول می‌سازند یا اطلاعات لو می‌دهند.
	sensitiveIPLimiter = newRateLimiter("sensitive", 30, 15)
)

// rateLimit میدل‌ورِ عمومی — روی همه‌ی مسیرها
func rateLimit(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			next(w, r)
			return
		}
		if !globalIPLimiter.allow(clientIP(r)) {
			tooManyRequests(w, 10)
			return
		}
		next(w, r)
	}
}

// rateLimitSensitive سهمیه‌ی تنگ‌ترِ مسیرهای حساس، *علاوه بر* سهمیه‌ی عمومی
func rateLimitSensitive(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			next(w, r)
			return
		}
		ip := clientIP(r)
		if !globalIPLimiter.allow(ip) || !sensitiveIPLimiter.allow(ip) {
			tooManyRequests(w, 30)
			return
		}
		next(w, r)
	}
}

func tooManyRequests(w http.ResponseWriter, retryAfter int) {
	w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
	httpError(w, "تعداد درخواست‌ها زیاد است، کمی بعد دوباره تلاش کن", http.StatusTooManyRequests)
}
