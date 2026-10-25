package com.coffeebaz.gungame.ads;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.util.ArraySet;
import android.util.Log;

import com.adivery.sdk.Adivery;
import com.adivery.sdk.AdiveryListener;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Set;
import java.util.UUID;

/**
 * تبلیغ جایزه‌دار ادیوری برای Godot (سینگلتون «RewardedAds»).
 * قرارداد با scripts/Ads.gd:
 *   initialize(app_id) · preloadRewarded(placement_id) · showRewarded(placement_id) · setUserId(id)
 *   rewarded_completed(ad_token) · rewarded_closed() · rewarded_failed(message)
 */
public class RewardedAdsPlugin extends GodotPlugin {
    private static final String TAG = "RewardedAds";
    private static final long LOAD_TIMEOUT_MS = 12000;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean configured = false;
    private String waitingPlacement = null;   // کاربر زده «ببین»، منتظر لود شدن
    private String showingPlacement = null;

    private final Runnable loadTimeout = new Runnable() {
        @Override
        public void run() {
            if (waitingPlacement != null) {
                waitingPlacement = null;
                emit("rewarded_failed", "timeout");
            }
        }
    };

    private final AdiveryListener listener = new AdiveryListener() {
        @Override
        public void onRewardedAdLoaded(String placementId) {
            if (placementId.equals(waitingPlacement)) {
                waitingPlacement = null;
                handler.removeCallbacks(loadTimeout);
                show(placementId);
            }
        }

        @Override
        public void onRewardedAdClosed(String placementId, boolean isRewarded) {
            if (!placementId.equals(showingPlacement)) {
                return;
            }
            showingPlacement = null;
            if (isRewarded) {
                emit("rewarded_completed", UUID.randomUUID().toString());
            } else {
                emit("rewarded_closed");
            }
            // تبلیغ بعدی را از همین حالا آماده کن تا دفعه‌ی بعد سریع باز شود
            prepare(placementId);
        }

        @Override
        public void log(String placementId, String message) {
            Log.w(TAG, placementId + ": " + message);
            if (placementId != null && placementId.equals(waitingPlacement)) {
                waitingPlacement = null;
                handler.removeCallbacks(loadTimeout);
                emit("rewarded_failed", message);
            }
        }
    };

    public RewardedAdsPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "RewardedAds";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new ArraySet<>();
        signals.add(new SignalInfo("rewarded_completed", String.class));
        signals.add(new SignalInfo("rewarded_closed"));
        signals.add(new SignalInfo("rewarded_failed", String.class));
        return signals;
    }

    @UsedByGodot
    public void initialize(final String appId) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Activity activity = getActivity();
                if (activity == null || configured) {
                    return;
                }
                Adivery.configure(activity.getApplication(), appId);
                Adivery.addGlobalListener(listener);
                configured = true;
            }
        });
    }

    @UsedByGodot
    public void setUserId(final String userId) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Adivery.setUserId(userId);
            }
        });
    }

    @UsedByGodot
    public void preloadRewarded(final String placementId) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                prepare(placementId);
            }
        });
    }

    @UsedByGodot
    public void showRewarded(final String placementId) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (!configured) {
                    emit("rewarded_failed", "not configured");
                    return;
                }
                if (Adivery.isLoaded(placementId)) {
                    show(placementId);
                    return;
                }
                waitingPlacement = placementId;
                handler.removeCallbacks(loadTimeout);
                handler.postDelayed(loadTimeout, LOAD_TIMEOUT_MS);
                prepare(placementId);
            }
        });
    }

    private void prepare(String placementId) {
        Activity activity = getActivity();
        if (activity != null && configured && !Adivery.isLoaded(placementId)) {
            Adivery.prepareRewardedAd(activity, placementId);
        }
    }

    private void show(String placementId) {
        showingPlacement = placementId;
        Adivery.showAd(placementId);
    }

    private void emit(final String signal, final Object... args) {
        runOnRenderThread(new Runnable() {
            @Override
            public void run() {
                emitSignal(signal, args);
            }
        });
    }
}
