package com.coffeebaz.gungame.iap;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.UsedByGodot;

/** سینگلتونِ «MyketBilling» — پرداخت از طریق مایکت */
public class MyketBillingPlugin extends StoreBillingPlugin {
    public MyketBillingPlugin(Godot godot) {
        super(godot, "MyketBilling");
    }

    @Override
    public String getPluginName() {
        return "MyketBilling";
    }

    @Override
    protected String storePackage() {
        return "ir.mservices.market";
    }

    @Override
    protected String bindAction() {
        return "ir.mservices.market.InAppBillingService.BIND";
    }

    // مقادیرِ BroadcastIAB در کتابخانه‌ی رسمیِ مایکت
    @Override
    protected String storeReceiverClass() {
        return "ir.mservices.market.receivers.InAppBillingReceiver";
    }

    @Override
    protected boolean broadcastUsesPing() {
        return true;
    }

    @Override
    protected long broadcastMinVersionCode() {
        return 900;
    }

    // ---- متدهای قابلِ صدا زدن از GDScript ----
    // Godot فقط متدهایی را می‌بیند که مستقیم در همین کلاس تعریف شده‌اند
    // (getDeclaredMethods)، پس این‌ها حتماً باید همین‌جا باشند.

    @UsedByGodot
    @Override
    public void startConnection() {
        super.startConnection();
    }

    @UsedByGodot
    @Override
    public void purchase(String productId, String payload) {
        super.purchase(productId, payload);
    }

    @UsedByGodot
    @Override
    public void consume(String token) {
        super.consume(token);
    }

    @UsedByGodot
    @Override
    public void queryPurchases() {
        super.queryPurchases();
    }
}
