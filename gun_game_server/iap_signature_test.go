package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"testing"

	"go.mongodb.org/mongo-driver/bson"
)

// یک «فروشگاهِ» جعلی برای تست: کلیدِ خصوصی دستِ ماست، کلیدِ عمومی‌اش را به
// سرور می‌دهیم (BAZAAR_RSA_KEY) — درست مثلِ کلیدِ پیشخوانِ بازار.
func testStore(t *testing.T) *rsa.PrivateKey {
	t.Helper()
	priv, err := rsa.GenerateKey(rand.Reader, 1024)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKIXPublicKey(&priv.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	old, had := os.LookupEnv("BAZAAR_RSA_KEY")
	os.Setenv("BAZAAR_RSA_KEY", base64.StdEncoding.EncodeToString(der))
	t.Cleanup(func() {
		if had {
			os.Setenv("BAZAAR_RSA_KEY", old)
		} else {
			os.Unsetenv("BAZAAR_RSA_KEY")
		}
	})
	return priv
}

func receipt(t *testing.T, priv *rsa.PrivateKey, fields map[string]interface{}) (string, string) {
	t.Helper()
	b, _ := json.Marshal(fields)
	digest := sha1.Sum(b)
	sig, err := rsa.SignPKCS1v15(rand.Reader, priv, crypto.SHA1, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	return string(b), base64.StdEncoding.EncodeToString(sig)
}

func validFields() map[string]interface{} {
	return map[string]interface{}{
		"orderId":          "o-1",
		"packageName":      iapPackageName(),
		"productId":        "gems_200",
		"purchaseTime":     1,
		"purchaseState":    0,
		"developerPayload": "player-123",
		"purchaseToken":    "tok-abc",
	}
}

func TestSignedReceiptAcceptedAndForgeriesRejected(t *testing.T) {
	priv := testStore(t)
	data, sig := receipt(t, priv, validFields())

	if err := verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-123", data, sig); err != nil {
		t.Fatalf("رسیدِ درست رد شد: %v", err)
	}

	rejects := map[string]func() error{
		"بدون رسید": func() error {
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-123", "", "")
		},
		"دست‌کاریِ متنِ رسید (بسته‌ی بزرگ‌تر)": func() error {
			f := validFields()
			f["productId"] = "gems_400"
			forged, _ := json.Marshal(f)
			return verifySignedPurchase(iapStoreBazaar, "gems_400", "tok-abc", "player-123", string(forged), sig)
		},
		"امضا با کلیدِ دیگر": func() error {
			other, _ := rsa.GenerateKey(rand.Reader, 1024)
			d, s := receipt(t, other, validFields())
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-123", d, s)
		},
		"ادعای محصولِ دیگر با رسیدِ درست": func() error {
			return verifySignedPurchase(iapStoreBazaar, "gems_400", "tok-abc", "player-123", data, sig)
		},
		"توکنِ دیگر با رسیدِ درست": func() error {
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-other", "player-123", data, sig)
		},
		"رسیدِ حسابِ دیگر (دزدیده‌شده)": func() error {
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-999", data, sig)
		},
		"رسیدِ اپِ دیگر": func() error {
			f := validFields()
			f["packageName"] = "com.other.app"
			d, s := receipt(t, priv, f)
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-123", d, s)
		},
		"پرداختِ برگشت‌خورده": func() error {
			f := validFields()
			f["purchaseState"] = 1
			d, s := receipt(t, priv, f)
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-123", d, s)
		},
		"امضای خراب": func() error {
			return verifySignedPurchase(iapStoreBazaar, "gems_200", "tok-abc", "player-123", data, "!!!")
		},
	}
	for name, fn := range rejects {
		if err := fn(); !errors.Is(err, errIAPNotPurchased) {
			t.Errorf("%s: باید رد می‌شد، شد %v", name, err)
		}
	}
}

// کلیدِ واقعیِ بازار که در کد هست باید سالم parse شود
func TestBundledBazaarKeyParses(t *testing.T) {
	os.Unsetenv("BAZAAR_RSA_KEY")
	pub, err := storePublicKey(iapStoreBazaar)
	if err != nil {
		t.Fatal(err)
	}
	if pub.N.BitLen() < 1024 {
		t.Fatalf("کلید خیلی کوتاه است: %d", pub.N.BitLen())
	}
}

// جریانِ کاملِ /iap/verify روی دیتابیس: رسیدِ امضاشده یک بار شارژ می‌شود،
// تکرارش شارژِ دوباره ندارد، و رسیدِ جعلی هیچ قلبی نمی‌دهد.
func TestIAPVerifyWithSignedReceipt(t *testing.T) {
	ctx := withDB(t)
	os.Unsetenv("IAP_ALLOW_DEBUG")
	os.Unsetenv("BAZAAR_API_SECRET")
	priv := testStore(t)
	p := seedStorePlayer(t, ctx, "__sig_probe", 0)

	const token = "sig-probe-token"
	_, _ = col(ColIAPPurchases).DeleteMany(ctx, bson.M{"purchase_token": token})
	t.Cleanup(func() { _, _ = col(ColIAPPurchases).DeleteMany(ctx, bson.M{"purchase_token": token}) })

	body := func(data, sig, product string) string {
		b, _ := json.Marshal(map[string]string{
			"username": p.Username, "store": "bazaar", "product_id": product,
			"purchase_token": token, "purchase_data": data, "signature": sig,
		})
		return string(b)
	}

	// جعلی: امضا با کلیدِ دیگر
	other, _ := rsa.GenerateKey(rand.Reader, 1024)
	f := validFields()
	f["developerPayload"] = p.PlayerID
	f["purchaseToken"] = token
	fd, fs := receipt(t, other, f)
	if rec := storePost(iapVerifyHandler, "/", body(fd, fs, "gems_200")); rec.Code != http.StatusPaymentRequired {
		t.Fatalf("رسیدِ جعلی باید 402 بگیرد: %d %s", rec.Code, rec.Body)
	}
	if got := reload(t, ctx, p.Username).Gems; got != 0 {
		t.Fatalf("رسیدِ جعلی قلب داد: %d", got)
	}

	// درست — دو بار (مثلِ قطعیِ اینترنت و فرستادنِ دوباره)
	d, s := receipt(t, priv, f)
	for i := 0; i < 2; i++ {
		if rec := storePost(iapVerifyHandler, "/", body(d, s, "gems_200")); rec.Code != 200 {
			t.Fatalf("تأیید %d: %d %s", i, rec.Code, rec.Body)
		}
	}
	pack, _ := findGemPackByProduct("gems_200")
	if got := reload(t, ctx, p.Username).Gems; got != pack.TotalAmount() {
		t.Fatalf("قلب = %d، باید فقط یک بار %d شارژ شود", got, pack.TotalAmount())
	}
}

// کلیدِ واقعیِ مایکت هم باید سالم parse شود
func TestBundledMyketKeyParses(t *testing.T) {
	os.Unsetenv("MYKET_RSA_KEY")
	pub, err := storePublicKey(iapStoreMyket)
	if err != nil {
		t.Fatal(err)
	}
	if pub.N.BitLen() < 1024 {
		t.Fatalf("کلید خیلی کوتاه است: %d", pub.N.BitLen())
	}
}
