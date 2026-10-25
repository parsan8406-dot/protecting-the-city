package com.coffeebaz.gungame.iap;

import android.os.Bundle;
import android.os.IBinder;
import android.os.Parcel;
import android.os.RemoteException;

/**
 * پروکسیِ دستیِ سرویس پرداخت درون‌برنامه‌ای (IInAppBillingService نسخه‌ی ۳).
 *
 * بازار و مایکت هر دو همین رابطِ AIDL گوگل را پیاده کرده‌اند. چون این پلاگین
 * بدون Gradle و فقط با javac ساخته می‌شود (مثل rewarded_ads)، کامپایلرِ aidl
 * در دسترس نیست؛ پس همان کدی که aidl تولید می‌کرد اینجا دستی نوشته شده.
 *
 * ترتیبِ متدها در فایل aidl اصلی شماره‌ی تراکنش را تعیین می‌کند و نباید عوض شود
 * (همان aidl ـِ کتابخانه‌ی رسمیِ مایکت، myketstore/myket-billing-client):
 *   1 isBillingSupported · 2 getSkuDetails · 3 getBuyIntent · 4 getPurchases · 5 consumePurchase
 *   6 getBuyIntentV2 · 7 getPurchaseConfig
 */
final class IabService {
    private static final String DESCRIPTOR = "com.android.vending.billing.IInAppBillingService";
    private static final int TX_IS_BILLING_SUPPORTED = IBinder.FIRST_CALL_TRANSACTION;
    private static final int TX_GET_BUY_INTENT = IBinder.FIRST_CALL_TRANSACTION + 2;
    private static final int TX_GET_PURCHASES = IBinder.FIRST_CALL_TRANSACTION + 3;
    private static final int TX_CONSUME_PURCHASE = IBinder.FIRST_CALL_TRANSACTION + 4;
    private static final int TX_GET_BUY_INTENT_V2 = IBinder.FIRST_CALL_TRANSACTION + 5;
    private static final int TX_GET_PURCHASE_CONFIG = IBinder.FIRST_CALL_TRANSACTION + 6;

    private final IBinder remote;

    IabService(IBinder remote) {
        this.remote = remote;
    }

    int isBillingSupported(int apiVersion, String packageName, String type) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(DESCRIPTOR);
            data.writeInt(apiVersion);
            data.writeString(packageName);
            data.writeString(type);
            remote.transact(TX_IS_BILLING_SUPPORTED, data, reply, 0);
            reply.readException();
            return reply.readInt();
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    Bundle getBuyIntent(int apiVersion, String packageName, String sku, String type,
                        String developerPayload) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(DESCRIPTOR);
            data.writeInt(apiVersion);
            data.writeString(packageName);
            data.writeString(sku);
            data.writeString(type);
            data.writeString(developerPayload);
            remote.transact(TX_GET_BUY_INTENT, data, reply, 0);
            reply.readException();
            return readBundle(reply);
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    /** مثل getBuyIntent ولی BUY_INTENT یک Intent ساده است، نه PendingIntent */
    Bundle getBuyIntentV2(int apiVersion, String packageName, String sku, String type,
                          String developerPayload) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(DESCRIPTOR);
            data.writeInt(apiVersion);
            data.writeString(packageName);
            data.writeString(sku);
            data.writeString(type);
            data.writeString(developerPayload);
            remote.transact(TX_GET_BUY_INTENT_V2, data, reply, 0);
            reply.readException();
            return readBundle(reply);
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    /** INTENT_V2_SUPPORT=true یعنی فروشگاه getBuyIntentV2 را می‌خواهد */
    Bundle getPurchaseConfig(int apiVersion) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(DESCRIPTOR);
            data.writeInt(apiVersion);
            remote.transact(TX_GET_PURCHASE_CONFIG, data, reply, 0);
            reply.readException();
            return readBundle(reply);
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    Bundle getPurchases(int apiVersion, String packageName, String type,
                        String continuationToken) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(DESCRIPTOR);
            data.writeInt(apiVersion);
            data.writeString(packageName);
            data.writeString(type);
            data.writeString(continuationToken);
            remote.transact(TX_GET_PURCHASES, data, reply, 0);
            reply.readException();
            return readBundle(reply);
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    int consumePurchase(int apiVersion, String packageName, String purchaseToken) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(DESCRIPTOR);
            data.writeInt(apiVersion);
            data.writeString(packageName);
            data.writeString(purchaseToken);
            remote.transact(TX_CONSUME_PURCHASE, data, reply, 0);
            reply.readException();
            return reply.readInt();
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    private static Bundle readBundle(Parcel reply) {
        if (reply.readInt() == 0) {
            return null;
        }
        return Bundle.CREATOR.createFromParcel(reply);
    }
}
