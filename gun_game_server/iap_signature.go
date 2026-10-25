package main

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

// =============================================================================
// تأییدِ رسیدِ خرید با امضای فروشگاه — کاملاً سمتِ سرور
// =============================================================================
//
// بازار (و مایکت) هر رسید را با کلیدِ خصوصیِ خودشان امضا می‌کنند:
//   INAPP_PURCHASE_DATA  (JSON: packageName, productId, purchaseToken,
//                          purchaseState, developerPayload, ...)
//   INAPP_DATA_SIGNATURE (SHA1withRSA، base64)
// کلیدِ عمومی در پیشخوان است و اینجا نگه داشته می‌شود. بدونِ کلیدِ خصوصیِ
// فروشگاه نمی‌شود رسیدی ساخت که این امضا را پاس کند، پس کلاینت هیچ نقشی در
// تصمیم ندارد — فقط رسید را دست‌به‌دست می‌کند.
//
// روی امضا این‌ها هم چک می‌شوند:
//   - packageName همین اپ است (رسیدِ اپِ دیگری قبول نمی‌شود)
//   - productId همان بسته‌ای است که ادعا شده
//   - purchaseToken همان توکنی است که کلید یکتاییِ iap_purchases است
//     (هر رسید فقط یک بار شارژ می‌شود — handlers_iap.go)
//   - purchaseState == 0 (پرداخت‌شده، نه لغو/برگشت)
//   - developerPayload == player_id خریدار: رسید به همان حسابی گره می‌خورد که
//     خرید را شروع کرد؛ رسیدی که از گوشیِ کس دیگری دزدیده شود به کار نمی‌آید.

// کلیدهای عمومیِ پیشخوان (base64، X.509). عمومی‌اند و جای امنی لازم ندارند؛
// با متغیرِ محیطیِ همنام می‌شود بدونِ بیلدِ دوباره عوضشان کرد.
const (
	bazaarRSAKeyDefault = "MIHNMA0GCSqGSIb3DQEBAQUAA4G7ADCBtwKBrwCcdXJUHpJHGv16HdpHhdNsMmxRJD0uFECLwQap/lHOTg7xekFA+dfiFJXpc+Tdj7jfNiYNgUKNAxAT1nynAByPAl7CZZgKVpJ1dliwIkupfJfgcpiB0C5Nos0IwALQkA6IH5vC/4C2zZcfQqhltU4y4pvIQGN1NJ+vrJ3bq2kKPBfyJUOAldK1bKnsi59/xbZSHVcmHv3RNXqvjjeHUaGDFLyN3mRp0lnZWXZrlpECAwEAAQ=="
	myketRSAKeyDefault  = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCItmznpWgbbUAl9BIHIr27MCg79L6KsTD+6sKf9FDx1SSHlJqXYGODMlbM3iOyx2fViUrKYsJv1EaOK2C+X61rBDJhoT2z8O+d2pJZB2SPiJtbQh5Vjneqy8xFbtq+j/gfQFpcz+ri9buyCIbedInCSvcTJ5aN1DKB0QaExyVSvwIDAQAB"
	defaultPackageName  = "com.coffeebaz.gungame"
)

// storePublicKey کلیدِ عمومیِ فروشگاه
func storePublicKey(store string) (*rsa.PublicKey, error) {
	raw := ""
	switch store {
	case iapStoreBazaar:
		raw = envOr("BAZAAR_RSA_KEY", bazaarRSAKeyDefault)
	case iapStoreMyket:
		raw = envOr("MYKET_RSA_KEY", myketRSAKeyDefault)
	}
	if raw == "" {
		return nil, fmt.Errorf("کلیدِ عمومیِ %s تنظیم نشده", store)
	}
	der, err := base64.StdEncoding.DecodeString(strings.TrimSpace(raw))
	if err != nil {
		return nil, fmt.Errorf("کلیدِ %s نامعتبر: %w", store, err)
	}
	key, err := x509.ParsePKIXPublicKey(der)
	if err != nil {
		return nil, fmt.Errorf("کلیدِ %s نامعتبر: %w", store, err)
	}
	pub, ok := key.(*rsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("کلیدِ %s از نوع RSA نیست", store)
	}
	return pub, nil
}

func envOr(name, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(name)); v != "" {
		return v
	}
	return fallback
}

func iapPackageName() string {
	return envOr("ANDROID_PACKAGE_NAME", defaultPackageName)
}

// signedPurchase همان JSONِ امضاشده‌ی فروشگاه
type signedPurchase struct {
	PackageName      string `json:"packageName"`
	ProductID        string `json:"productId"`
	PurchaseToken    string `json:"purchaseToken"`
	Token            string `json:"token"` // بعضی نسخه‌های مایکت اسمش این است
	PurchaseState    *int   `json:"purchaseState"`
	DeveloperPayload string `json:"developerPayload"`
}

// verifySignedPurchase رسید را فقط با امضای فروشگاه تأیید می‌کند.
// errIAPNotPurchased یعنی رسید قطعاً معتبر نیست (دوباره فرستادنش فایده ندارد).
func verifySignedPurchase(store, productID, token, playerID, data, signature string) error {
	if data == "" || signature == "" {
		return errIAPNotPurchased
	}
	pub, err := storePublicKey(store)
	if err != nil {
		return err // تنظیماتِ سرور — موقت، کلاینت رسید را نگه می‌دارد
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(signature))
	if err != nil {
		return errIAPNotPurchased
	}
	digest := sha1.Sum([]byte(data))
	if rsa.VerifyPKCS1v15(pub, crypto.SHA1, digest[:], sig) != nil {
		return errIAPNotPurchased
	}

	var p signedPurchase
	if err := json.Unmarshal([]byte(data), &p); err != nil {
		return errIAPNotPurchased
	}
	signedToken := p.PurchaseToken
	if signedToken == "" {
		signedToken = p.Token
	}
	switch {
	case p.PackageName != iapPackageName():
		return fmt.Errorf("%w: پکیجِ دیگر (%s)", errIAPNotPurchased, p.PackageName)
	case p.ProductID != productID:
		return fmt.Errorf("%w: محصولِ دیگر", errIAPNotPurchased)
	case signedToken != token:
		return fmt.Errorf("%w: توکنِ دیگر", errIAPNotPurchased)
	case p.PurchaseState == nil || *p.PurchaseState != 0:
		return fmt.Errorf("%w: پرداخت‌نشده", errIAPNotPurchased)
	case p.DeveloperPayload != playerID:
		return fmt.Errorf("%w: رسید مالِ حسابِ دیگری است", errIAPNotPurchased)
	}
	return nil
}
