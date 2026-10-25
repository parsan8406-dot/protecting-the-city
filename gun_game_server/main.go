package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// db اتصال جهانی به دیتابیس MongoDB
var db *mongo.Database

// corsMiddleware میدل‌ور برای اجازه درخواست‌های Cross-Origin
// این میدل‌ور CORS headers را اضافه می‌کند و درخواست‌های preflight (OPTIONS) را مدیریت می‌کند
func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Device")

		// درخواست‌های preflight را بدون فراخوانی handler اصلی پاسخ دهید
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next(w, r)
	}
}

func main() {
	// ۰. رمزها (کلید گوگل و ...) از فایل .env کنار سرور — در گیت نیست
	loadDotEnv()
	// فرمان‌های نگهداری پنل مدیریت (admin-hash، admin-unlock، ...) — admin_security.go
	if runAdminCLI(os.Args) {
		return
	}
	googleCfg = loadGoogleConfig()
	if googleCfg.webFlowReady() {
		fmt.Println("✅ Google sign-in configured, callback:", googleCfg.RedirectURL)
	} else {
		fmt.Println("⚠️ Google sign-in is OFF (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / PUBLIC_BASE_URL)")
	}

	// ۱. بارگذاری متغیرهای محیطی با مقادیر پیش‌فرض
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// ۱.۵ بارگذاری نقشه‌ی برخورد زمین بازی.
	// اگر نقشه بالا نیاید هیچ اعتبارسنجی حرکت/خط‌دیدی در کار نیست و بازی
	// قابل تقلب می‌شود، پس همین‌جا متوقف می‌شویم.
	if err := LoadArena(); err != nil {
		log.Fatal("❌ Error loading arena map: ", err)
	}

	// ۲. اتصال به MongoDB
	fmt.Println("🔄 Connecting to MongoDB...")
	clientOptions := options.Client().ApplyURI(mongoURI)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal("❌ Error connecting to MongoDB: ", err)
	}

	// تست اتصال و ping
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Cannot ping MongoDB: %v", err)
	}

	db = client.Database("gun_game_db")
	fmt.Println("✅ Successfully connected to MongoDB!")

	// ۲.۱ آماده‌سازی ساختار دیتابیس:
	// ساخت کالکشن‌ها ← مایگریشن بازیکنان قدیمی ← ایندکس‌ها ← دیتای استاتیک
	initCtx, initCancel := context.WithTimeout(context.Background(), 60*time.Second)
	if err := InitDatabase(initCtx); err != nil {
		initCancel()
		log.Fatalf("❌ Database initialization failed: %v", err)
	}
	EnsureAdminIndexes(initCtx)
	loadAdminLockdown(initCtx)
	initCancel()
	fmt.Println("✅ Collections, indexes and static data are ready!")

	// ۳. راه‌اندازی WebSocket Hub برای مدیریت بازی‌های زنده
	hub := NewHub()
	globalHub = hub // تا هندلرهای HTTP هم بتوانند نوتیفیکیشن بلادرنگ بفرستند
	go hub.Run()
	// تیکِ هوشِ بات‌ها. بعد از Run می‌آید چون فقط سیگنال می‌فرستد و کارِ
	// واقعی روی گوروتینِ خودِ Hub انجام می‌شود.
	hub.StartBotLoop()
	fmt.Println("✅ Real-time WebSocket Hub is running...")

	// پاداش هفتگی سه نفر اول رتبه‌بندی (weekly_rewards.go)
	StartWeeklyRewardLoop()

	// ۴. راه‌اندازی مسیرهای HTTP و WebSocket
	mux := http.NewServeMux()

	// هر مسیری که به نام یک بازیکن کار می‌کند از authGuard رد می‌شود: حسابی
	// که دستگاه ثبت کرده بدون توکن دستگاه قابل استفاده نیست (handlers_auth.go)
	protect := func(h http.HandlerFunc) http.HandlerFunc {
		return corsMiddleware(rateLimit(authGuard(h)))
	}
	// مسیرهای حساس (ساختِ حساب، پول، ورود، جستجو) سهمیه‌ی تنگ‌تری دارند
	protectTight := func(h http.HandlerFunc) http.HandlerFunc {
		return corsMiddleware(rateLimitSensitive(authGuard(h)))
	}

	// --- اکانت: توکن دستگاه و اتصال به گوگل ---
	mux.HandleFunc("/auth/status", protectTight(authStatusHandler))
	mux.HandleFunc("/auth/google/start", protectTight(googleAuthStartHandler))
	mux.HandleFunc("/auth/google/poll", corsMiddleware(rateLimitSensitive(googleAuthPollHandler)))
	mux.HandleFunc("/auth/google/token", protectTight(googleAuthTokenHandler))
	mux.HandleFunc("/auth/google/unlink", protectTight(googleUnlinkHandler))
	// صفحه‌ای که مرورگرِ بازیکن بعد از گوگل به آن برمی‌گردد
	mux.HandleFunc("/auth/google/callback", rateLimitSensitive(googleAuthCallbackHandler))

	// --- مسیرهای قبلی (اکانت و فروشگاه) ---
	mux.HandleFunc("/get_player", protectTight(getPlayerHandler))
	mux.HandleFunc("/get_shop", protect(getShopHandler))
	mux.HandleFunc("/api/shop", protect(getShopHandler))
	mux.HandleFunc("/buy_item", protect(buyItemHandler))
	// بسته‌ی شانسی — ویترینِ «پک شانس» در تب ویژه (lucky_box.go)
	mux.HandleFunc("/lucky_box", protect(luckyBoxHandler))
	mux.HandleFunc("/equip_item", protect(equipItemHandler))
	mux.HandleFunc("/tutorial/done", protect(tutorialDoneHandler))
	// اسکین‌ها (فقط از بتل‌پس) و ارتقای کاراکتر — skins.go
	mux.HandleFunc("/skins", protect(getSkinsHandler))
	mux.HandleFunc("/skins/equip", protect(equipSkinHandler))
	mux.HandleFunc("/upgrades", protect(getUpgradesHandler))
	mux.HandleFunc("/upgrade_character", protect(upgradeCharacterHandler))

	// کد هدیه، جایزه‌ی تبلیغ، خرید درون‌برنامه‌ای
	mux.HandleFunc("/gift_code/redeem", protectTight(redeemGiftCodeHandler))
	mux.HandleFunc("/admin/gift_codes/create", corsMiddleware(serverKeyOnly(createGiftCodeHandler)))
	mux.HandleFunc("/ads/reward/status", protect(adRewardStatusHandler))
	mux.HandleFunc("/ads/reward/claim", protectTight(adRewardClaimHandler))
	mux.HandleFunc("/iap/verify", protectTight(iapVerifyHandler))

	// --- منوی پروفایل ---
	mux.HandleFunc("/profile", protect(getProfileHandler))
	mux.HandleFunc("/profile/update", protectTight(updateProfileHandler))

	// --- منوی دوستان ---
	mux.HandleFunc("/friends", protect(getFriendsHandler))
	mux.HandleFunc("/friends/search", protectTight(searchPlayerHandler))
	mux.HandleFunc("/friends/request", protect(sendFriendRequestHandler))
	mux.HandleFunc("/friends/respond", protect(respondFriendRequestHandler))
	mux.HandleFunc("/friends/remove", protect(removeFriendHandler))
	mux.HandleFunc("/friends/gift", protect(sendGiftHandler))

	// --- منوی پیام ها ---
	mux.HandleFunc("/messages", protect(getMessagesHandler))
	mux.HandleFunc("/messages/read", protect(readMessageHandler))
	mux.HandleFunc("/messages/claim", protect(claimMessageRewardHandler))
	mux.HandleFunc("/messages/delete", protect(deleteMessageHandler))
	mux.HandleFunc("/messages/read_all", protect(readAllMessagesHandler))
	mux.HandleFunc("/messages/claim_all", protect(claimAllMessagesHandler))

	// --- پیام کاربر به سازنده (تنظیمات → ارسال پیام) ---
	mux.HandleFunc("/support/message", protectTight(sendSupportMessageHandler))
	// خواندنِ پیام‌ها فقط از پنل مدیریت (قبلاً این مسیر برای همه باز بود و
	// پیام‌های همه‌ی بازیکن‌ها را به هر کسی نشان می‌داد)
	mux.HandleFunc("/support/messages", corsMiddleware(serverKeyOnly(listSupportMessagesHandler)))

	// --- چت زنده (خصوصی / شهر / جهانی) ---
	mux.HandleFunc("/chat/overview", protect(getChatOverviewHandler))
	mux.HandleFunc("/chat/history", protect(getChatHistoryHandler))
	mux.HandleFunc("/chat/send", protect(sendChatMessageHandler))
	mux.HandleFunc("/chat/read", protect(readChatRoomHandler))

	// --- حالت‌های بازی چندنفره ---
	mux.HandleFunc("/game_modes", protect(getGameModesHandler))
	mux.HandleFunc("/game_modes/select", protect(selectGameModeHandler))

	// --- صفِ پیدا کردن حریف ---
	mux.HandleFunc("/matchmaking/join", protect(joinMatchmakingHandler))
	mux.HandleFunc("/matchmaking/status", protect(matchmakingStatusHandler))
	mux.HandleFunc("/matchmaking/leave", protect(leaveMatchmakingHandler))

	// --- صفحه‌ی رتبه بندی (دوستان / شهرها / رتبه کلی) ---
	mux.HandleFunc("/leaderboard", protect(getLeaderboardHandler))

	// --- منوی شهر (کلن) ---
	mux.HandleFunc("/clan", protect(getClanHandler))
	mux.HandleFunc("/clans", protect(getClansHandler))
	mux.HandleFunc("/clan/create", protectTight(createClanHandler))
	mux.HandleFunc("/clan/join", protect(joinClanHandler))
	mux.HandleFunc("/clan/leave", protect(leaveClanHandler))
	mux.HandleFunc("/clan/requests", protect(getClanRequestsHandler))
	mux.HandleFunc("/clan/respond", protect(respondClanRequestHandler))
	mux.HandleFunc("/clan/kick", protect(kickClanMemberHandler))
	mux.HandleFunc("/clan/role", protect(setClanRoleHandler))
	mux.HandleFunc("/clan/update", protect(updateClanHandler))
	mux.HandleFunc("/clan/transfer", protect(transferClanLeaderHandler))

	// --- ثبت نتیجه مسابقه (منبع آمار پروفایل) ---
	// فقط سرویس‌های داخلی با کلید GAME_SERVER_KEY (هیچ کلاینتی صدایش نمی‌زند)
	mux.HandleFunc("/match/result", corsMiddleware(serverKeyOnly(submitMatchResultHandler)))

	// --- ماموریت‌های روزانه و پاداش فصل ---
	mux.HandleFunc("/missions/daily", protect(getDailyMissionsHandler))
	mux.HandleFunc("/missions/claim", protect(claimDailyMissionHandler))
	mux.HandleFunc("/missions/bonus/claim", protect(claimDailyBonusHandler))
	mux.HandleFunc("/season/pass", protect(getSeasonPassHandler))
	mux.HandleFunc("/season/pass/claim", protect(claimSeasonPassHandler))
	mux.HandleFunc("/season/pass/buy", protect(buySeasonPassHandler))
	mux.HandleFunc("/season/challenges/claim", protect(claimSeasonChallengeHandler))
	mux.HandleFunc("/season/cups", protect(getSeasonCupsHandler))
	mux.HandleFunc("/season/cups/claim", protect(claimSeasonCupHandler))

	// --- پنل مدیریت (/admin/) — admin_auth.go ---
	// بدون ADMIN_ACCOUNTS در .env کاملاً خاموش است (404)
	registerAdminRoutes(mux)
	if adminPanelEnabled() {
		fmt.Println("✅ Admin panel is on at", adminBasePath()+"/")
	} else {
		fmt.Println("⚠️ Admin panel is OFF (ADMIN_ACCOUNTS)")
	}

	// مسیر WebSocket (CheckOrigin شامل در upgrader است)
	// باز کردنِ سوکت هم سهمیه دارد: هر سوکت دو گوروتین و یک بافرِ ۲۵۶تایی
	// می‌گیرد، پس بازکردنِ پشت‌سر همِ سوکت بدون محدودیت حافظه‌ی سرور را
	// می‌خورد. خودِ join جداگانه با توکن دستگاه بررسی می‌شود (hub.go).
	mux.HandleFunc("/ws", rateLimit(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))

	// ۵. پیکربندی سرور HTTP با timeout‌های معقول
	// BIND_ADDR روی سرور واقعی 127.0.0.1 است تا بک‌اند فقط از پشت nginx
	// در دسترس باشد؛ خالی یعنی همه‌ی اینترفیس‌ها (برای تست با گوشی در شبکه‌ی محلی)
	addr := os.Getenv("BIND_ADDR") + ":" + port
	server := &http.Server{
		Addr:         addr,
		Handler:      mux,
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// ۶. اجرای سرور در Goroutine برای Graceful Shutdown
	go func() {
		fmt.Printf("🚀 Server is running on %s...\n", addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("❌ Server error: %v", err)
		}
	}()

	// ۷. مدیریت سیگنال‌های خروج (CTRL+C یا SIGTERM)
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	fmt.Println("\n🛑 Shutting down server gracefully...")

	// ۸. Graceful Shutdown: منتظر پایان درخواست‌های فعلی
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("❌ Server forced to shutdown: %v", err)
	}

	// ۹. قطع اتصال از MongoDB
	if err := client.Disconnect(shutdownCtx); err != nil {
		log.Printf("❌ Error disconnecting MongoDB: %v", err)
	}

	fmt.Println("👋 Server stopped cleanly.")
}
