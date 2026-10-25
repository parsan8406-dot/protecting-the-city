package com.coffeebaz.gungame.iap;

import android.app.Activity;
import android.app.ActivityOptions;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Parcelable;
import android.util.Log;

/**
 * اکتیویتیِ نامرئیِ واسط برای صفحه‌ی پرداختِ فروشگاه — همان کاری که
 * ProxyBillingActivity در کتابخانه‌ی رسمیِ مایکت می‌کند.
 *
 * چرا مستقیم از اکتیویتیِ Godot باز نمی‌کنیم؟
 *  - اکتیویتیِ Godot با launchMode=singleInstancePerTask اجرا می‌شود و
 *    نتیجه‌ی startActivityForResult از آن قابلِ اتکا نیست.
 *  - مایکتِ جدید صفحه‌ی پرداخت را به‌شکلِ Intent ساده (getBuyIntentV2) می‌دهد
 *    که باید با startActivityForResult باز شود، و نسخه‌ی قدیمی PendingIntent
 *    می‌دهد که روی اندروید ۱۴+ بدونِ اجازه‌ی صریحِ BAL باز نمی‌شود.
 *
 * نتیجه با StoreBillingPlugin.onProxyResult به پلاگین برمی‌گردد.
 */
public class BillingProxyActivity extends Activity {
    static final String EXTRA_BUY_INTENT = "buy_intent";
    static final String EXTRA_STORE_PACKAGE = "store_package";

    private static final String TAG = "StoreBilling";
    private static final String STATE_LAUNCHED = "launched";
    private static final int REQUEST_CODE = 0xB112;
    /** همان SDK_VERSION ـِ کتابخانه‌ی رسمیِ مایکت (billing/build.gradle) */
    private static final int MYKET_SDK_VERSION = 6;

    private boolean delivered = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (savedInstanceState != null && savedInstanceState.getBoolean(STATE_LAUNCHED)) {
            // بعد از بازسازیِ اکتیویتی، صفحه‌ی فروشگاه قبلاً باز شده؛ فقط منتظرِ نتیجه بمان
            return;
        }
        try {
            Parcelable buy = getIntent().getParcelableExtra(EXTRA_BUY_INTENT);
            String storePackage = getIntent().getStringExtra(EXTRA_STORE_PACKAGE);
            if (buy instanceof Intent) {
                Intent forward = new Intent((Intent) buy);
                forward.putExtra("SDK_VERSION", MYKET_SDK_VERSION);
                ComponentName target = forward.resolveActivity(getPackageManager());
                if (target == null || storePackage == null
                        || !storePackage.equals(target.getPackageName())) {
                    // فقط صفحه‌ای که مالِ خودِ فروشگاه است باز شود
                    Log.w(TAG, "buy intent does not resolve to the store: " + target);
                    deliver(RESULT_FIRST_USER, null);
                    return;
                }
                forward.setComponent(target);
                Log.i(TAG, "launching buy intent (v2) " + target.flattenToShortString());
                startActivityForResult(forward, REQUEST_CODE);
            } else if (buy instanceof PendingIntent) {
                PendingIntent pi = (PendingIntent) buy;
                Bundle options = null;
                if (Build.VERSION.SDK_INT >= 34) {
                    // اندروید ۱۴+: بدونِ این، PendingIntent ـِ فروشگاه اجازه‌ی باز کردنِ صفحه ندارد
                    options = ActivityOptions.makeBasic()
                            .setPendingIntentBackgroundActivityStartMode(
                                    ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                            .toBundle();
                }
                Log.i(TAG, "launching buy intent (pending)");
                startIntentSenderForResult(pi.getIntentSender(), REQUEST_CODE, new Intent(),
                        0, 0, 0, options);
            } else {
                Log.w(TAG, "no buy intent");
                deliver(RESULT_FIRST_USER, null);
            }
        } catch (Throwable e) {
            Log.w(TAG, "could not open store purchase screen", e);
            deliver(RESULT_FIRST_USER, null);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putBoolean(STATE_LAUNCHED, true);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_CODE) {
            Log.i(TAG, "store purchase result: " + resultCode);
            deliver(resultCode, data);
        }
    }

    @Override
    protected void onDestroy() {
        // اگر بدونِ نتیجه بسته شد (مثلاً سیستم کشتش)، خرید را لغوشده اعلام کن
        if (!delivered && isFinishing()) {
            StoreBillingPlugin.onProxyResult(RESULT_CANCELED, null);
            delivered = true;
        }
        super.onDestroy();
    }

    private void deliver(int resultCode, Intent data) {
        if (!delivered) {
            delivered = true;
            StoreBillingPlugin.onProxyResult(resultCode, data);
        }
        finish();
    }
}
