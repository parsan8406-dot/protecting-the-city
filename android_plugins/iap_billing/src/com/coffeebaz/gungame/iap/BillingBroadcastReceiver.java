package com.coffeebaz.gungame.iap;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * گیرنده‌ی جواب‌های فروشگاه در مسیرِ Broadcast (همان IABReceiver ـِ کتابخانه‌ی
 * رسمیِ مایکت). وقتی bind به سرویسِ پرداخت ممکن نیست، فروشگاه جواب‌ها را با
 * broadcast به این کلاس می‌فرستد (اکشن‌های <store>.ping / .purchase / ...).
 * اصالتِ پیام با کلیدِ secure ـِ همین نشست در StoreBillingPlugin چک می‌شود.
 */
public class BillingBroadcastReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        StoreBillingPlugin.onStoreBroadcast(intent);
    }
}
