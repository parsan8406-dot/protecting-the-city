package com.coffeebaz.gungame.iap;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.UsedByGodot;

/** سینگلتونِ «BazaarBilling» — پرداخت از طریق کافه‌بازار */
public class BazaarBillingPlugin extends StoreBillingPlugin {
    public BazaarBillingPlugin(Godot godot) {
        super(godot, "BazaarBilling");
    }

    @Override
    public String getPluginName() {
        return "BazaarBilling";
    }

    @Override
    protected String storePackage() {
        return "com.farsitel.bazaar";
    }

    @Override
    protected String bindAction() {
        return "ir.cafebazaar.pardakht.InAppBillingService.BIND";
    }

    // مسیرِ Broadcast مثلِ ReceiverBillingConnection در Poolakey (کتابخانه‌ی رسمیِ
    // بازار): بدونِ component و بدونِ ping، مستقیم billingSupport به بسته‌ی بازار
    @Override
    protected String storeReceiverClass() {
        return null;
    }

    @Override
    protected boolean broadcastUsesPing() {
        return false;
    }

    @Override
    protected long broadcastMinVersionCode() {
        return 801301;
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
