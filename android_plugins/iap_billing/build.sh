#!/usr/bin/env bash
# ساخت BazaarBilling.aar و MyketBilling.aar بدون Gradle: فقط javac + jar
# (همان روشِ android_plugins/rewarded_ads). وابستگیِ بیرونی ندارد — رابطِ
# پرداختِ فروشگاه در IabService.java دستی پیاده شده.
#
# هر aar فقط پلاگین و مجوزِ فروشگاهِ خودش را در مانیفست دارد؛ export plugin
# (addons/iap_billing/export_plugin.gd) بر اساسِ feature ـِ پریست فقط یکی را
# داخل APK می‌گذارد، تا نسخه‌ی بازار ارجاعی به مایکت نداشته باشد و برعکس.
set -euo pipefail
cd "$(dirname "$0")"

GODOT_VERSION="4.7.2.stable"
MIRROR="https://maven.myket.ir"
ANDROID_JAR="${ANDROID_JAR:-$LOCALAPPDATA/Android/Sdk/platforms/android-34/android.jar}"
JDK_BIN="${JDK_BIN:-/f/Program Files/Java/jdk-17.0.19/bin}"
OUT_DIR="../../addons/iap_billing/bin"

mkdir -p .deps .build/classes
[ -f .deps/godot.jar ] || { curl -sfL "$MIRROR/org/godotengine/godot/$GODOT_VERSION/godot-$GODOT_VERSION.aar" -o .deps/godot.aar && unzip -p .deps/godot.aar classes.jar > .deps/godot.jar && rm .deps/godot.aar; }

rm -rf .build/classes/*
"$JDK_BIN/javac" -encoding UTF-8 -source 8 -target 8 -nowarn -Xlint:-options \
  -bootclasspath "$ANDROID_JAR" -cp ".deps/godot.jar" \
  -d .build/classes $(find src -name '*.java')
"$JDK_BIN/jar" cf .build/classes.jar -C .build/classes .

mkdir -p "$OUT_DIR"
for store in bazaar myket; do
  name="$( [ "$store" = bazaar ] && echo BazaarBilling || echo MyketBilling )"
  stage=".build/aar_$store"
  rm -rf "$stage" && mkdir -p "$stage"
  cp .build/classes.jar "$stage/classes.jar"
  cp "AndroidManifest.$store.xml" "$stage/AndroidManifest.xml"
  : > "$stage/R.txt"
  rm -f "$OUT_DIR/$name.aar"
  (cd "$stage" && "$JDK_BIN/jar" cfM "../../$OUT_DIR/$name.aar" AndroidManifest.xml classes.jar R.txt)
  echo "built $OUT_DIR/$name.aar"
done
