package com.coffeebaz.gungame.iap;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcelable;
import android.util.Log;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * پرداخت درون‌برنامه‌ای برای Godot — پایه‌ی مشترکِ بازار و مایکت.
 *
 * قرارداد با scripts/Billing.gd:
 *   متدها:     startConnection() · purchase(product_id, payload) · consume(token) · queryPurchases()
 *   سیگنال‌ها: connection_succeeded() · connection_failed(message)
 *              purchase_succeeded(product_id, token, purchase_data, signature)
 *              purchase_cancelled(product_id) · purchase_failed(product_id, message)
 *              purchases_queried(purchases: Array[{product_id, purchase_token, purchase_data, signature}])
 *
 * رفتار عیناً مثلِ کتابخانه‌ی رسمیِ مایکت (myketstore/myket-billing-client):
 *   ۱. اتصال: اول bind به سرویسِ پرداخت؛ اگر نشد (سرویس غیرفعال/ناموجود، یا
 *      جواب نداد) مسیرِ Broadcast — مایکتِ جدید فقط از این راه جواب می‌دهد.
 *   ۲. خرید: getPurchaseConfig؛ اگر INTENT_V2_SUPPORT بود getBuyIntentV2
 *      (Intent ساده) وگرنه getBuyIntent (PendingIntent). صفحه‌ی پرداخت همیشه
 *      از BillingProxyActivity باز می‌شود و نتیجه از همان‌جا برمی‌گردد.
 *
 * این کلاس هیچ تصمیمی درباره‌ی اعتبارِ خرید نمی‌گیرد: رسید و امضای فروشگاه را
 * دست‌نخورده به بازی می‌دهد و بازی آن را به سرور می‌فرستد. امضا فقط روی سرور
 * چک می‌شود (gun_game_server/iap_signature.go) و consume فقط بعد از تأیید سرور.
 * payload همان player_id خریدار است و داخلِ رسیدِ امضاشده برمی‌گردد.
 *
 * برای عیب‌یابی روی گوشی:  adb logcat -s StoreBilling
 *
 * ⚠️ مهم: Godot متدهای پلاگین را با getClass().getDeclaredMethods() پیدا می‌کند،
 * یعنی فقط متدهایی که **مستقیم در کلاسِ نهایی** (MyketBillingPlugin /
 * BazaarBillingPlugin) تعریف شده‌اند. متدهای public این کلاسِ پایه باید آنجا
 * با @UsedByGodot دوباره تعریف شوند (override + super)، وگرنه از GDScript
 * صدا زدنشان بی‌صدا هیچ کاری نمی‌کند — دقیقاً همان باگی که باعث شد بازار و
 * مایکت بازی را رد کنند («در حال اتصال...» و بعد «اتصال برقرار نشد»).
 */
public abstract class StoreBillingPlugin extends GodotPlugin {
    private static final String TAG = "StoreBilling";
    private static final int API_VERSION = 3;
    private static final String TYPE_INAPP = "inapp";

    private static final int RESULT_OK = 0;
    private static final int RESULT_USER_CANCELED = 1;
    private static final int RESULT_ITEM_ALREADY_OWNED = 7;

    private static final long CONNECT_TIMEOUT_MS = 8000;
    private static final long BROADCAST_REPLY_TIMEOUT_S = 20;

    // کلیدهای مسیرِ Broadcast (BroadcastIAB در کتابخانه‌ی مایکت)
    private static final String B_PING = ".ping";
    private static final String B_BILLING_SUPPORT = ".billingSupport";
    private static final String B_PURCHASE = ".purchase";
    private static final String B_GET_PURCHASE = ".getPurchase";
    private static final String B_CONSUME = ".consume";
    private static final String KEY_PACKAGE_NAME = "packageName";
    private static final String KEY_API_VERSION = "apiVersion";
    private static final String KEY_SECURE = "secure";
    private static final String KEY_SKU = "sku";
    private static final String KEY_ITEM_TYPE = "itemType";
    private static final String KEY_DEVELOPER_PAYLOAD = "developerPayload";
    private static final String KEY_TOKEN = "token";

    private enum Mode { NONE, SERVICE, BROADCAST }

    /** فقط یک پلاگینِ پرداخت در هر APK هست؛ اکتیویتیِ واسط و گیرنده از این پیدایش می‌کنند */
    private static volatile StoreBillingPlugin instance;

    private final String tag;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    /** کلیدِ تصادفیِ این نشست؛ فروشگاه آن را در جواب‌های broadcast برمی‌گرداند */
    private final String secureKey = UUID.randomUUID().toString();

    private volatile Mode mode = Mode.NONE;
    private volatile IabService service;
    private volatile ServiceConnection connection;
    /** در حالِ وصل شدن (سرویس یا broadcast) و هنوز نتیجه‌ای اعلام نشده */
    private volatile boolean connecting = false;
    private volatile boolean broadcastPinged = false;
    private volatile String pendingProduct = "";

    private volatile CountDownLatch purchasesLatch;
    private volatile Bundle purchasesReply;

    /**
     * اگر فروشگاه هیچ‌وقت جواب ندهد (bind قبول شد ولی onServiceConnected نیامد،
     * یا ping ـِ broadcast بی‌جواب ماند) بازی نباید تا ابد «در حال اتصال» بماند.
     */
    private final Runnable connectTimeout = new Runnable() {
        @Override
        public void run() {
            if (!connecting) {
                return;
            }
            if (mode == Mode.SERVICE && service == null) {
                Log.w(tag, "service bind timed out, trying broadcast");
                dropConnection();
                if (startBroadcastConnection()) {
                    return;
                }
                failConnection("timeout");
            } else if (mode == Mode.BROADCAST) {
                Log.w(tag, "broadcast ping timed out");
                failConnection("timeout");
            }
        }
    };

    protected StoreBillingPlugin(Godot godot, String tag) {
        super(godot);
        this.tag = tag;
        instance = this;
    }

    /** بسته‌ی اپ فروشگاه (مثلاً ir.mservices.market) */
    protected abstract String storePackage();

    /** اکشنِ bind سرویس پرداخت فروشگاه */
    protected abstract String bindAction();

    /** کلاسِ گیرنده‌ی broadcast داخلِ اپِ فروشگاه؛ null یعنی فقط با نامِ بسته بفرست */
    protected abstract String storeReceiverClass();

    /** مایکت قبل از هر چیز ping می‌خواهد؛ بازار (Poolakey) مستقیم billingSupport */
    protected abstract boolean broadcastUsesPing();

    /** مسیرِ broadcast فقط در نسخه‌های بالاتر از این versionCode ـِ فروشگاه هست */
    protected abstract long broadcastMinVersionCode();

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("connection_succeeded"));
        s.add(new SignalInfo("connection_failed", String.class));
        s.add(new SignalInfo("purchase_succeeded", String.class, String.class, String.class, String.class));
        s.add(new SignalInfo("purchase_cancelled", String.class));
        s.add(new SignalInfo("purchase_failed", String.class, String.class));
        s.add(new SignalInfo("purchases_queried", Object[].class));
        return s;
    }

    // ------------------------------------------------------------------ اتصال

    public void startConnection() {
        main.post(new Runnable() {
            @Override
            public void run() {
                startConnectionOnMain();
            }
        });
    }

    private void startConnectionOnMain() {
        Activity activity = getActivity();
        if (activity == null) {
            emitSignal("connection_failed", "no_activity");
            return;
        }
        if (isReady()) {
            emitSignal("connection_succeeded");
            return;
        }
        if (connecting) {
            // یک اتصال در جریان است؛ تایمر را از نو می‌گذاریم تا این درخواست هم حتماً جواب بگیرد
            main.removeCallbacks(connectTimeout);
            main.postDelayed(connectTimeout, CONNECT_TIMEOUT_MS);
            return;
        }
        if (storeVersionCode(activity) < 0) {
            emitSignal("connection_failed", "store_not_installed");
            return;
        }
        connecting = true;
        Log.i(tag, "connecting to " + storePackage() + " (store version " + storeVersionCode(activity) + ")");
        if (startServiceConnection(activity)) {
            main.removeCallbacks(connectTimeout);
            main.postDelayed(connectTimeout, CONNECT_TIMEOUT_MS);
            return;
        }
        if (startBroadcastConnection()) {
            return;
        }
        failConnection("bind_failed");
    }

    private boolean isReady() {
        return !connecting && ((mode == Mode.SERVICE && service != null)
                || (mode == Mode.BROADCAST && broadcastPinged));
    }

    /** مثلِ ServiceIAB.connect: فقط اگر سرویس پیدا شد و bind قبول شد true */
    private boolean startServiceConnection(Activity activity) {
        Intent intent = new Intent(bindAction());
        intent.setPackage(storePackage());
        List<ResolveInfo> services;
        try {
            PackageManager pm = activity.getPackageManager();
            if (Build.VERSION.SDK_INT >= 33) {
                services = pm.queryIntentServices(intent,
                        PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DISABLED_COMPONENTS));
            } else if (Build.VERSION.SDK_INT >= 24) {
                services = pm.queryIntentServices(intent, PackageManager.MATCH_DISABLED_COMPONENTS);
            } else {
                services = pm.queryIntentServices(intent, 0);
            }
        } catch (Exception e) {
            services = null;
        }
        if (services == null || services.isEmpty()) {
            Log.i(tag, "billing service not found, using broadcast");
            return false;
        }

        final ServiceConnection conn = new ServiceConnection() {
            @Override
            public void onServiceConnected(ComponentName name, final IBinder binder) {
                Log.i(tag, "service connected");
                final ServiceConnection self = this;
                worker.execute(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            IabService s = new IabService(binder);
                            int code = s.isBillingSupported(API_VERSION, packageName(), TYPE_INAPP);
                            if (connection != self) {
                                return;  // در این فاصله تایمر اتصال را رها کرده
                            }
                            if (code != RESULT_OK) {
                                Log.w(tag, "isBillingSupported = " + code);
                                dropConnection();
                                failConnection("billing_not_supported:" + code);
                                return;
                            }
                            service = s;
                            succeedConnection();
                        } catch (Exception e) {
                            Log.w(tag, "isBillingSupported", e);
                            if (connection != self) {
                                return;
                            }
                            dropConnection();
                            // سرویس هست ولی جواب درست نمی‌دهد — مثلِ کتابخانه‌ی مایکت broadcast را امتحان کن
                            main.post(new Runnable() {
                                @Override
                                public void run() {
                                    if (!startBroadcastConnection()) {
                                        failConnection("error:" + e.getClass().getSimpleName());
                                    }
                                }
                            });
                        }
                    }
                });
            }

            @Override
            public void onServiceDisconnected(ComponentName name) {
                Log.i(tag, "service disconnected");
                if (connection != this) {
                    return;
                }
                boolean wasReady = service != null;
                dropConnection();
                if (wasReady) {
                    emitSignal("connection_failed", "disconnected");
                } else {
                    failConnection("disconnected");
                }
            }
        };

        connection = conn;
        mode = Mode.SERVICE;
        boolean bound;
        try {
            bound = activity.getApplicationContext().bindService(intent, conn, Context.BIND_AUTO_CREATE);
        } catch (Exception e) {
            Log.w(tag, "bindService", e);
            bound = false;
        }
        if (!bound) {
            Log.i(tag, "bindService returned false, using broadcast");
            dropConnection();
            return false;
        }
        return true;
    }

    /** مثلِ BroadcastIAB.connect: ping می‌فرستد و منتظرِ جواب می‌ماند */
    private boolean startBroadcastConnection() {
        Activity activity = getActivity();
        if (activity == null || storeVersionCode(activity) <= broadcastMinVersionCode()) {
            return false;
        }
        mode = Mode.BROADCAST;
        if (broadcastUsesPing()) {
            broadcastPinged = false;
            Log.i(tag, "sending broadcast ping");
            sendStoreBroadcast(B_PING, null);
        } else {
            broadcastPinged = true;
            Log.i(tag, "sending broadcast billingSupport");
            Bundle req = new Bundle();
            req.putString(KEY_PACKAGE_NAME, packageName());
            req.putInt(KEY_API_VERSION, API_VERSION);
            sendStoreBroadcast(B_BILLING_SUPPORT, req);
        }
        main.removeCallbacks(connectTimeout);
        main.postDelayed(connectTimeout, CONNECT_TIMEOUT_MS);
        return true;
    }

    private void succeedConnection() {
        main.removeCallbacks(connectTimeout);
        connecting = false;
        Log.i(tag, "connected via " + mode);
        emitSignal("connection_succeeded");
    }

    private void failConnection(String reason) {
        main.removeCallbacks(connectTimeout);
        connecting = false;
        mode = Mode.NONE;
        broadcastPinged = false;
        Log.w(tag, "connection failed: " + reason);
        emitSignal("connection_failed", reason);
    }

    /** اتصالِ سرویس را آزاد می‌کند تا startConnection بعدی از صفر شروع شود */
    private void dropConnection() {
        ServiceConnection c = connection;
        connection = null;
        service = null;
        if (c != null) {
            Activity a = getActivity();
            if (a != null) {
                try {
                    a.getApplicationContext().unbindService(c);
                } catch (Exception ignored) {
                }
            }
        }
    }

    private long storeVersionCode(Context ctx) {
        try {
            PackageManager pm = ctx.getPackageManager();
            PackageInfo info;
            if (Build.VERSION.SDK_INT >= 33) {
                info = pm.getPackageInfo(storePackage(),
                        PackageManager.PackageInfoFlags.of(PackageManager.MATCH_DISABLED_COMPONENTS));
            } else if (Build.VERSION.SDK_INT >= 24) {
                info = pm.getPackageInfo(storePackage(), PackageManager.MATCH_DISABLED_COMPONENTS);
            } else {
                info = pm.getPackageInfo(storePackage(), 0);
            }
            if (Build.VERSION.SDK_INT >= 28) {
                return info.getLongVersionCode();
            }
            return info.versionCode;
        } catch (Exception e) {
            return -1;
        }
    }

    // ------------------------------------------------------------------ خرید

    public void purchase(final String productId, final String payload) {
        if (!isReady()) {
            emitSignal("purchase_failed", productId, "not_connected");
            return;
        }
        pendingProduct = productId;
        final String devPayload = payload == null ? "" : payload;
        Log.i(tag, "purchase " + productId + " via " + mode);

        if (mode == Mode.BROADCAST) {
            Bundle extras = new Bundle();
            extras.putString(KEY_SKU, productId);
            extras.putString(KEY_ITEM_TYPE, TYPE_INAPP);
            extras.putInt(KEY_API_VERSION, API_VERSION);
            extras.putString(KEY_DEVELOPER_PAYLOAD, devPayload);
            sendStoreBroadcast(B_PURCHASE, extras);
            // جواب (BUY_INTENT) در onStoreBroadcast می‌رسد
            return;
        }

        final IabService s = service;
        worker.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    boolean v2 = false;
                    try {
                        Bundle config = s.getPurchaseConfig(API_VERSION);
                        v2 = config != null && config.getBoolean("INTENT_V2_SUPPORT");
                    } catch (Exception e) {
                        Log.i(tag, "getPurchaseConfig not supported: " + e);
                    }
                    Log.i(tag, "INTENT_V2_SUPPORT = " + v2);
                    Bundle b = v2
                            ? s.getBuyIntentV2(API_VERSION, packageName(), productId, TYPE_INAPP, devPayload)
                            : s.getBuyIntent(API_VERSION, packageName(), productId, TYPE_INAPP, devPayload);
                    handleBuyIntentBundle(productId, b);
                } catch (Exception e) {
                    Log.w(tag, "getBuyIntent", e);
                    pendingProduct = "";
                    emitSignal("purchase_failed", productId, "error:" + e.getClass().getSimpleName());
                }
            }
        });
    }

    private void handleBuyIntentBundle(String productId, Bundle b) {
        int code = responseCode(b);
        Log.i(tag, "buy intent response = " + code);
        if (code == RESULT_ITEM_ALREADY_OWNED) {
            // یک خریدِ قبلی هنوز consume نشده — Billing.gd با queryPurchases
            // آن را به سرور می‌فرستد و بعد از تأیید consume می‌کند.
            pendingProduct = "";
            emitSignal("purchase_failed", productId, "already_owned");
            queryPurchases();
            return;
        }
        if (code != RESULT_OK || b == null) {
            pendingProduct = "";
            emitSignal("purchase_failed", productId, "buy_intent:" + code);
            return;
        }
        final Parcelable buy = b.getParcelable("BUY_INTENT");
        if (buy == null) {
            pendingProduct = "";
            emitSignal("purchase_failed", productId, "no_buy_intent");
            return;
        }
        main.post(new Runnable() {
            @Override
            public void run() {
                Activity a = getActivity();
                if (a == null) {
                    onProxyResult(Activity.RESULT_FIRST_USER, null);
                    return;
                }
                try {
                    Intent intent = new Intent(a, BillingProxyActivity.class);
                    intent.putExtra(BillingProxyActivity.EXTRA_BUY_INTENT, buy);
                    intent.putExtra(BillingProxyActivity.EXTRA_STORE_PACKAGE, storePackage());
                    a.startActivity(intent);
                } catch (Exception e) {
                    Log.w(tag, "start proxy activity", e);
                    onProxyResult(Activity.RESULT_FIRST_USER, null);
                }
            }
        });
    }

    /** نتیجه‌ی صفحه‌ی پرداخت، از BillingProxyActivity */
    static void onProxyResult(int resultCode, Intent data) {
        StoreBillingPlugin p = instance;
        if (p != null) {
            p.handlePurchaseResult(resultCode, data);
        }
    }

    private void handlePurchaseResult(int resultCode, Intent data) {
        String product = pendingProduct;
        pendingProduct = "";

        if (data == null) {
            if (resultCode == Activity.RESULT_FIRST_USER) {
                emitSignal("purchase_failed", product, "launch_failed");
            } else {
                emitSignal("purchase_cancelled", product);
            }
            return;
        }
        int code = responseCode(data.getExtras());
        if (resultCode == Activity.RESULT_CANCELED || code == RESULT_USER_CANCELED) {
            emitSignal("purchase_cancelled", product);
            return;
        }
        if (resultCode != Activity.RESULT_OK || code != RESULT_OK) {
            emitSignal("purchase_failed", product, "result:" + resultCode + "/" + code);
            return;
        }

        String purchaseData = data.getStringExtra("INAPP_PURCHASE_DATA");
        String signature = data.getStringExtra("INAPP_DATA_SIGNATURE");
        if (purchaseData == null) {
            emitSignal("purchase_failed", product, "no_purchase_data");
            return;
        }
        try {
            JSONObject o = new JSONObject(purchaseData);
            String pid = o.optString("productId", product);
            String token = o.optString("purchaseToken", o.optString("token", ""));
            if (token.isEmpty()) {
                emitSignal("purchase_failed", pid, "no_token");
                return;
            }
            emitSignal("purchase_succeeded", pid, token, purchaseData, signature == null ? "" : signature);
        } catch (Exception e) {
            emitSignal("purchase_failed", product, "bad_purchase_data");
        }
    }

    // ------------------------------------------------------------------ consume / query

    public void consume(final String token) {
        if (!isReady() || token == null || token.isEmpty()) {
            return;
        }
        if (mode == Mode.BROADCAST) {
            Bundle extras = new Bundle();
            extras.putString(KEY_TOKEN, token);
            extras.putInt(KEY_API_VERSION, API_VERSION);
            sendStoreBroadcast(B_CONSUME, extras);
            return;
        }
        final IabService s = service;
        worker.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    int code = s.consumePurchase(API_VERSION, packageName(), token);
                    if (code != RESULT_OK) {
                        Log.w(tag, "consume failed: " + code);
                    }
                } catch (Exception e) {
                    Log.w(tag, "consume", e);
                }
            }
        });
    }

    /** خریدهای پرداخت‌شده ولی consume‌نشده (مثلاً اپ وسطِ کار بسته شده) */
    public void queryPurchases() {
        if (!isReady()) {
            return;
        }
        final Mode m = mode;
        final IabService s = service;
        worker.execute(new Runnable() {
            @Override
            public void run() {
                List<Object> out = new ArrayList<>();
                String cont = null;
                try {
                    do {
                        Bundle b = m == Mode.BROADCAST
                                ? getPurchasesViaBroadcast(cont)
                                : s.getPurchases(API_VERSION, packageName(), TYPE_INAPP, cont);
                        if (b == null || responseCode(b) != RESULT_OK) {
                            break;
                        }
                        ArrayList<String> items = b.getStringArrayList("INAPP_PURCHASE_DATA_LIST");
                        ArrayList<String> sigs = b.getStringArrayList("INAPP_DATA_SIGNATURE_LIST");
                        if (items != null) {
                            for (int i = 0; i < items.size(); i++) {
                                String sig = sigs != null && i < sigs.size() ? sigs.get(i) : "";
                                JSONObject o = new JSONObject(items.get(i));
                                Dictionary d = new Dictionary();
                                d.put("product_id", o.optString("productId", ""));
                                d.put("purchase_token", o.optString("purchaseToken", o.optString("token", "")));
                                d.put("purchase_data", items.get(i));
                                d.put("signature", sig == null ? "" : sig);
                                out.add(d);
                            }
                        }
                        cont = b.getString("INAPP_CONTINUATION_TOKEN");
                    } while (cont != null && !cont.isEmpty());
                } catch (Exception e) {
                    Log.w(tag, "getPurchases", e);
                }
                emitSignal("purchases_queried", (Object) out.toArray());
            }
        });
    }

    /** روی worker صدا زده می‌شود و تا رسیدنِ جواب (یا تایم‌اوت) صبر می‌کند */
    private Bundle getPurchasesViaBroadcast(String cont) throws InterruptedException {
        CountDownLatch latch = new CountDownLatch(1);
        purchasesReply = null;
        purchasesLatch = latch;
        Bundle extras = new Bundle();
        extras.putString(KEY_ITEM_TYPE, TYPE_INAPP);
        extras.putString(KEY_PACKAGE_NAME, packageName());
        extras.putInt(KEY_API_VERSION, API_VERSION);
        extras.putString(KEY_TOKEN, cont);
        sendStoreBroadcast(B_GET_PURCHASE, extras);
        latch.await(BROADCAST_REPLY_TIMEOUT_S, TimeUnit.SECONDS);
        purchasesLatch = null;
        return purchasesReply;
    }

    // ------------------------------------------------------------------ مسیرِ Broadcast

    private void sendStoreBroadcast(String action, Bundle extras) {
        Activity a = getActivity();
        if (a == null) {
            return;
        }
        Intent intent = new Intent();
        intent.setAction(storePackage() + action);
        intent.setPackage(storePackage());
        if (storeReceiverClass() != null) {
            intent.setComponent(new ComponentName(storePackage(), storeReceiverClass()));
        }
        intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES);
        intent.putExtra(KEY_PACKAGE_NAME, a.getPackageName());
        intent.putExtra(KEY_SECURE, secureKey);
        if (extras != null) {
            intent.putExtras(extras);
        }
        try {
            a.getApplicationContext().sendBroadcast(intent);
        } catch (Exception e) {
            Log.w(tag, "sendBroadcast " + action, e);
        }
    }

    /** از BillingBroadcastReceiver (رشته‌ی اصلی) */
    static void onStoreBroadcast(Intent intent) {
        StoreBillingPlugin p = instance;
        if (p != null && intent != null) {
            p.handleStoreBroadcast(intent);
        }
    }

    private void handleStoreBroadcast(Intent intent) {
        String fullAction = intent.getAction();
        if (fullAction == null || !fullAction.startsWith(storePackage())) {
            return;
        }
        if (!secureKey.equals(intent.getStringExtra(KEY_SECURE))) {
            Log.w(tag, "broadcast with wrong secure key ignored: " + fullAction);
            return;
        }
        String action = fullAction.substring(storePackage().length());
        Bundle extras = intent.getExtras() == null ? new Bundle() : intent.getExtras();
        Log.i(tag, "broadcast reply " + action);

        if (B_PING.equals(action)) {
            if (mode != Mode.BROADCAST || !connecting) {
                return;
            }
            broadcastPinged = true;
            // فروشگاه زنده است؛ برای جوابِ billingSupport دوباره فرصت بده
            main.removeCallbacks(connectTimeout);
            main.postDelayed(connectTimeout, CONNECT_TIMEOUT_MS);
            Bundle req = new Bundle();
            req.putString(KEY_PACKAGE_NAME, packageName());
            req.putInt(KEY_API_VERSION, API_VERSION);
            sendStoreBroadcast(B_BILLING_SUPPORT, req);
        } else if (B_BILLING_SUPPORT.equals(action)) {
            if (mode != Mode.BROADCAST || !connecting) {
                return;
            }
            int code = responseCode(extras);
            if (code == RESULT_OK) {
                succeedConnection();
            } else {
                failConnection("billing_not_supported:" + code);
            }
        } else if (B_PURCHASE.equals(action)) {
            handleBuyIntentBundle(pendingProduct, extras);
        } else if (B_GET_PURCHASE.equals(action)) {
            purchasesReply = extras;
            CountDownLatch latch = purchasesLatch;
            if (latch != null) {
                latch.countDown();
            }
        } else if (B_CONSUME.equals(action)) {
            int code = responseCode(extras);
            if (code != RESULT_OK) {
                Log.w(tag, "consume failed: " + code);
            }
        }
    }

    // ------------------------------------------------------------------ کمکی

    private String packageName() {
        Activity a = getActivity();
        return a != null ? a.getPackageName() : "";
    }

    /** فروشگاه‌ها RESPONSE_CODE را گاهی Integer و گاهی Long برمی‌گردانند */
    private static int responseCode(Bundle b) {
        if (b == null) {
            return -1;
        }
        Object o = b.get("RESPONSE_CODE");
        if (o == null) {
            return RESULT_OK;
        }
        if (o instanceof Integer) {
            return (Integer) o;
        }
        if (o instanceof Long) {
            return ((Long) o).intValue();
        }
        return -1;
    }

    @Override
    public void onMainDestroy() {
        main.removeCallbacks(connectTimeout);
        dropConnection();
        mode = Mode.NONE;
        worker.shutdownNow();
        if (instance == this) {
            instance = null;
        }
        super.onMainDestroy();
    }
}
