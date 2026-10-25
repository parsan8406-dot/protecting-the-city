package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// خرید درون‌برنامه‌ای (بازار / مایکت)
// =============================================================================
//
// جریان:
//   ۱. کلاینت با SDK فروشگاه پرداخت می‌کند و purchase_token می‌گیرد.
//   ۲. POST /iap/verify {username, store, product_id, purchase_token}
//   ۳. سرور توکن را از API خودِ فروشگاه استعلام می‌کند (هرگز به حرف کلاینت
//      اعتماد نمی‌کند)، بعد قلب را شارژ می‌کند.
//   ۴. فقط بعد از پاسخ موفق، کلاینت خرید را consume می‌کند.
//
// هر توکن فقط یک بار شارژ می‌شود: _id رکورد iap_purchases برابر
// «فروشگاه:توکن» است. اگر کلاینت بعد از قطعی اینترنت دوباره همان توکن را
// بفرستد، بدون شارژ دوباره پاسخ موفق می‌گیرد تا بتواند consume کند.
//
// متغیرهای محیطی (.env):
//   ANDROID_PACKAGE_NAME   نام پکیج اپ (مثلاً ir.mygame.gungame)
//   BAZAAR_API_SECRET      پیشخوان بازار ← API توسعه‌دهندگان ← کلید
//   MYKET_ACCESS_TOKEN     پنل توسعه‌دهندگان مایکت ← توکن دسترسی API
//   IAP_ALLOW_DEBUG=1      فقط برای تست: توکن‌های "debug-..." بدون استعلام قبول می‌شوند

const ColIAPPurchases = "iap_purchases"

const (
	iapStoreBazaar = "bazaar"
	iapStoreMyket  = "myket"
)

// سرورهای بازار و مایکت داخل ایران‌اند؛ پراکسیِ گوگل (HTTPS_PROXY) نباید رویشان اعمال شود.
var iapHTTP = &http.Client{
	Timeout:   10 * time.Second,
	Transport: &http.Transport{Proxy: nil},
}

type iapVerifyRequest struct {
	Username      string `json:"username"`
	Store         string `json:"store"`
	ProductID     string `json:"product_id"`
	PurchaseToken string `json:"purchase_token"`
	// رسیدِ امضاشده‌ی فروشگاه و امضایش (iap_signature.go) — مرجعِ اصلیِ تأیید
	PurchaseData string `json:"purchase_data"`
	Signature    string `json:"signature"`
}

type IAPPurchase struct {
	ID            string    `bson:"_id"`
	Store         string    `bson:"store"`
	ProductID     string    `bson:"product_id"`
	PurchaseToken string    `bson:"purchase_token"`
	PlayerID      string    `bson:"player_id"`
	Username      string    `bson:"username"`
	Gems          int       `bson:"gems"`
	State         string    `bson:"state"` // "pending" | "credited"
	CreatedAt     time.Time `bson:"created_at"`
	// رسیدِ امضاشده، برای پیگیریِ بعدی (بازگشتِ وجه، شکایت، ...)
	PurchaseData string `bson:"purchase_data,omitempty"`
	Signature    string `bson:"signature,omitempty"`
}

var errIAPNotPurchased = errors.New("purchase not valid")

// verifyStorePurchase توکن را از API فروشگاه استعلام می‌کند.
// verifyPurchase تصمیمِ نهایی درباره‌ی یک رسید — تماماً سمتِ سرور.
//
//  1. امضای فروشگاه روی رسید (iap_signature.go) — همیشه، و کافی.
//  2. اگر کلیدِ API فروشگاه روی سرور هست، استعلامِ زنده هم (لایه‌ی اضافه؛
//     مثلاً پرداختی که بعداً برگشت خورده را هم می‌گیرد).
func verifyPurchase(ctx context.Context, req iapVerifyRequest, playerID string) error {
	if os.Getenv("IAP_ALLOW_DEBUG") == "1" && strings.HasPrefix(req.PurchaseToken, "debug-") {
		return nil
	}
	if err := verifySignedPurchase(req.Store, req.ProductID, req.PurchaseToken, playerID,
		req.PurchaseData, req.Signature); err != nil {
		return err
	}
	if storeAPIConfigured(req.Store) {
		return verifyStorePurchase(ctx, req.Store, req.ProductID, req.PurchaseToken)
	}
	return nil
}

func storeAPIConfigured(store string) bool {
	switch store {
	case iapStoreBazaar:
		return os.Getenv("BAZAAR_API_SECRET") != ""
	case iapStoreMyket:
		return os.Getenv("MYKET_ACCESS_TOKEN") != ""
	}
	return false
}

// verifyStorePurchase توکن را از API فروشگاه استعلام می‌کند (فقط وقتی کلیدش هست).
func verifyStorePurchase(ctx context.Context, store, productID, token string) error {
	pkg := iapPackageName()
	esc := url.PathEscape

	var req *http.Request
	var err error
	switch store {
	case iapStoreBazaar:
		secret := os.Getenv("BAZAAR_API_SECRET")
		if secret == "" {
			return errors.New("BAZAAR_API_SECRET تنظیم نشده")
		}
		endpoint := fmt.Sprintf("https://pardakht.cafebazaar.ir/devapi/v2/api/validate/%s/inapp/%s/purchases/%s/",
			esc(pkg), esc(productID), esc(token))
		req, err = http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
		if err == nil {
			req.Header.Set("CAFEBAZAAR-PISHKHAN-API-SECRET", secret)
		}
	case iapStoreMyket:
		access := os.Getenv("MYKET_ACCESS_TOKEN")
		if access == "" {
			return errors.New("MYKET_ACCESS_TOKEN تنظیم نشده")
		}
		endpoint := fmt.Sprintf("https://developer.myket.ir/api/partners/applications/%s/purchases/products/%s/verify/%s",
			esc(pkg), esc(productID), esc(token))
		req, err = http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
		if err == nil {
			req.Header.Set("X-Access-Token", access)
		}
	default:
		return fmt.Errorf("فروشگاه ناشناس: %s", store)
	}
	if err != nil {
		return err
	}

	resp, err := iapHTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// 404/400 یعنی چنین خریدی وجود ندارد
	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest {
		return errIAPNotPurchased
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("پاسخ %d از %s", resp.StatusCode, store)
	}

	// هر دو فروشگاه مدل گوگل را دارند: purchaseState صفر = پرداخت‌شده
	var body struct {
		PurchaseState *int `json:"purchaseState"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return fmt.Errorf("پاسخ نامعتبر از %s: %w", store, err)
	}
	if body.PurchaseState == nil || *body.PurchaseState != 0 {
		return errIAPNotPurchased
	}
	return nil
}

// iapVerifyHandler
// POST /iap/verify
func iapVerifyHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req iapVerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil ||
		req.Username == "" || req.PurchaseToken == "" || len(req.PurchaseToken) > 512 ||
		len(req.PurchaseData) > 4096 || len(req.Signature) > 1024 {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	req.Store = strings.ToLower(strings.TrimSpace(req.Store))
	if req.Store != iapStoreBazaar && req.Store != iapStoreMyket {
		httpError(w, "فروشگاه نامعتبر است", http.StatusBadRequest)
		return
	}
	pack, ok := findGemPackByProduct(req.ProductID)
	if !ok {
		httpError(w, "محصول نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	var player PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": req.Username}).Decode(&player); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	purchaseID := req.Store + ":" + req.PurchaseToken
	purchases := col(ColIAPPurchases)

	// قبلاً شارژ شده؟ (تکرار بعد از قطعی اینترنت)
	var existing IAPPurchase
	err := purchases.FindOne(ctx, bson.M{"_id": purchaseID}).Decode(&existing)
	if err == nil {
		if existing.PlayerID != player.PlayerID || existing.ProductID != req.ProductID {
			httpError(w, "این رسید متعلق به حساب دیگری است", http.StatusForbidden)
			return
		}
		if existing.State == "credited" {
			respondIAP(ctx, w, player.PlayerID, pack, true)
			return
		}
	} else if err != mongo.ErrNoDocuments {
		httpError(w, "خطای دیتابیس", http.StatusInternalServerError)
		return
	}

	if err := verifyPurchase(ctx, req, player.PlayerID); err != nil {
		if errors.Is(err, errIAPNotPurchased) {
			fmt.Printf("⛔ IAP rejected %s %s %s: %v\n", req.Store, req.Username, req.ProductID, err)
			httpError(w, "پرداخت تأیید نشد", http.StatusPaymentRequired)
			return
		}
		fmt.Println("⚠️ IAP verify:", err)
		// خطای موقت — کلاینت توکن را نگه می‌دارد و بعداً دوباره می‌فرستد
		httpError(w, "ارتباط با فروشگاه برقرار نشد، کمی بعد خودکار دوباره بررسی می‌شود", http.StatusServiceUnavailable)
		return
	}

	// ثبت رسید به حالت pending (اگر نبود)
	_, err = purchases.UpdateOne(ctx, bson.M{"_id": purchaseID}, bson.M{"$setOnInsert": IAPPurchase{
		ID:            purchaseID,
		Store:         req.Store,
		ProductID:     req.ProductID,
		PurchaseToken: req.PurchaseToken,
		PlayerID:      player.PlayerID,
		Username:      player.Username,
		Gems:          pack.TotalAmount(),
		State:         "pending",
		CreatedAt:     time.Now(),
		PurchaseData:  req.PurchaseData,
		Signature:     req.Signature,
	}}, options.Update().SetUpsert(true))
	if err != nil {
		httpError(w, "خطای دیتابیس", http.StatusInternalServerError)
		return
	}

	// pending → credited فقط یک بار موفق می‌شود؛ همان یک بار قلب واریز می‌شود
	claim, err := purchases.UpdateOne(ctx,
		bson.M{"_id": purchaseID, "state": "pending", "player_id": player.PlayerID},
		bson.M{"$set": bson.M{"state": "credited", "credited_at": time.Now()}})
	if err != nil {
		httpError(w, "خطای دیتابیس", http.StatusInternalServerError)
		return
	}
	if claim.ModifiedCount == 1 {
		if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": player.PlayerID},
			bson.M{"$inc": bson.M{"gems": pack.TotalAmount()}}); err != nil {
			_, _ = purchases.UpdateOne(context.Background(), bson.M{"_id": purchaseID},
				bson.M{"$set": bson.M{"state": "pending"}})
			httpError(w, "خطا در شارژ قلب", http.StatusInternalServerError)
			return
		}
		fmt.Printf("💎 IAP %s: %s خرید %s (+%d قلب)\n", req.Store, player.Username, req.ProductID, pack.TotalAmount())
	}

	respondIAP(ctx, w, player.PlayerID, pack, claim.ModifiedCount != 1)
}

func respondIAP(ctx context.Context, w http.ResponseWriter, playerID string, pack currencyPack, already bool) {
	var fresh PlayerModel
	_ = col(ColPlayers).FindOne(ctx, bson.M{"player_id": playerID}).Decode(&fresh)
	jsonResponse(w, map[string]interface{}{
		"success":          true,
		"already_credited": already,
		"item_id":          pack.ItemID,
		"product_id":       pack.ProductID,
		// قلبِ هدیه‌ی بسته هم همین‌جا واریز می‌شود (store_currency.go)
		"reward": map[string]int{"gems": pack.TotalAmount()},
		"coins":  fresh.Coins,
		"gems":   fresh.Gems,
	})
}
