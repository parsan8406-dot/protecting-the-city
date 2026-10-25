#!/usr/bin/env bash
# قبل از فرستادنِ APK به مایکت یا بازار اجرا کنید:
#   bash tools/check_store_apk.sh build/NirooyeShahr-Myket.apk
#   bash tools/check_store_apk.sh build/NirooyeShahr.apk
#
# چرا؟ بازی سه بار رد شد چون APKِ فرستاده‌شده خروجیِ Debug بود و پلاگینِ
# پرداخت داخلش نبود؛ صفحه‌ی پرداختِ فروشگاه هیچ‌وقت باز نمی‌شد. این اسکریپت
# همان چیزهایی را چک می‌کند که آن بار خراب بود.
set -uo pipefail

APK="${1:?usage: check_store_apk.sh <file.apk>}"
SDK="${ANDROID_SDK_ROOT:-${LOCALAPPDATA:-$HOME}/Android/Sdk}"
BT="$(ls -d "$SDK"/build-tools/* 2>/dev/null | sort -V | tail -1)"
AAPT="$BT/aapt"; [ -x "$AAPT.exe" ] && AAPT="$AAPT.exe"
DEXDUMP="$BT/dexdump"; [ -x "$DEXDUMP.exe" ] && DEXDUMP="$DEXDUMP.exe"
APKSIGNER="$BT/apksigner"; [ -f "$APKSIGNER.bat" ] && APKSIGNER="$APKSIGNER.bat"

fail=0
ok()   { echo "  ✅ $*"; }
bad()  { echo "  ❌ $*"; fail=1; }
warn() { echo "  ⚠️  $*"; }

echo "== $APK"
badging="$("$AAPT" dump badging "$APK" 2>/dev/null)" || { echo "  ❌ cannot read APK"; exit 1; }
perms="$("$AAPT" dump permissions "$APK" 2>/dev/null)"
manifest="$("$AAPT" dump xmltree "$APK" AndroidManifest.xml 2>/dev/null)"

echo "  $(echo "$badging" | head -1 | grep -oE "name='[^']*'|versionCode='[^']*'|versionName='[^']*'" | tr '\n' ' ')"

if echo "$badging" | grep -q "application-debuggable"; then
  bad "Debug build — export with «Export With Debug» UNCHECKED (Release)"
else
  ok "release build (not debuggable)"
fi

if echo "$perms" | grep -q "ir.mservices.market.BILLING"; then store=myket; cls=MyketBillingPlugin
elif echo "$perms" | grep -q "com.farsitel.bazaar.permission.PAY_THROUGH_BAZAAR"; then store=bazaar; cls=BazaarBillingPlugin
else store=""; fi

if [ -z "$store" ]; then
  bad "no billing plugin in this APK (no Myket/Bazaar permission) — purchase can never open the store"
else
  ok "store: $store"
  echo "$manifest" | grep -q "plugin.v2.${cls%Plugin}" && ok "plugin registered (${cls%Plugin})" || bad "plugin meta-data missing"
  echo "$manifest" | grep -q "BillingProxyActivity" && ok "BillingProxyActivity present" || bad "BillingProxyActivity missing"
  # فقط پرداختِ فروشگاهِ دیگر ایراد است؛ <queries> سادهٔ SDK تبلیغ (ادیوری) به
  # com.farsitel.bazaar برای تشخیصِ منبعِ نصب است و ربطی به پرداخت ندارد.
  if [ "$store" = myket ]; then other_re="PAY_THROUGH_BAZAAR|ir.cafebazaar.pardakht|plugin.v2.BazaarBilling"
  else other_re="ir.mservices.market.BILLING|ir.mservices.market.InAppBillingService|plugin.v2.MyketBilling"; fi
  echo "$perms$manifest" | grep -qE "$other_re" && bad "contains the OTHER store's billing — wrong preset" || ok "no other-store billing"

  # Godot فقط متدهایی را می‌بیند که مستقیم روی کلاسِ نهایی تعریف شده‌اند
  tmp="$(mktemp -d)"; (cd "$tmp" && unzip -q -o "$OLDPWD/$APK" 'classes*.dex' 2>/dev/null || unzip -q -o "$APK" 'classes*.dex')
  methods="$(for d in "$tmp"/classes*.dex; do "$DEXDUMP" "$d" 2>/dev/null; done | awk -v c="Lcom/coffeebaz/gungame/iap/$cls;" '
      /Class descriptor/ {inside = index($0, c) > 0}
      inside && /name +:/ {gsub(/[ \x27]/, "", $3); print $3}')"
  rm -rf "$tmp"
  missing=""
  for m in startConnection purchase consume queryPurchases; do
    echo "$methods" | grep -qx "$m" || missing="$missing $m"
  done
  [ -z "$missing" ] && ok "Godot-callable methods declared on $cls" || bad "$cls is missing:$missing (old plugin build)"
fi

echo "$manifest" | grep -q "plugin.v2.RewardedAds" && ok "ads plugin present" || warn "ads plugin (RewardedAds) missing"

if [ -n "$APKSIGNER" ] && certs="$("$APKSIGNER" verify --print-certs "$APK" 2>/dev/null)"; then
  # کلیدِ دیباگِ اندروید یا کلیدِ دیباگی که خودِ Godot می‌سازد (CN=Godot, O=Stichting Godot)
  # بازار: نسخه‌ی ۱ با کلیدِ دیباگِ Godotِ همین سیستم منتشر شده و بازار فقط همان
  # کلید را برای آپدیت قبول می‌کند (پشتیبان: keystores/nirooye-shahr-bazaar.keystore).
  if [ "$store" = "bazaar" ] && echo "$certs" | grep -qi "SHA-1 digest: 80fa35732b200e11de1921cfb06b9a2466697ab6"; then
    ok "signed with the published Bazaar key (SHA-1 80:FA:35…)"
  elif echo "$certs" | grep -qiE "Android Debug|Stichting Godot"; then
    bad "signed with a DEBUG keystore — use the release keystore (nirooye-shahr-release.jks)"
  else
    ok "signed: $(echo "$certs" | grep -m1 'certificate DN' | sed 's/.*DN: //')"
  fi
else
  warn "could not verify signature (apksigner not found)"
fi

if [ "$fail" = 0 ]; then echo "  ==> OK to upload"; else echo "  ==> DO NOT upload this APK"; fi
exit "$fail"
