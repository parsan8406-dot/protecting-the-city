#!/usr/bin/env bash
# ساخت RewardedAds.aar بدون Gradle: فقط javac + jar.
# وابستگی‌ها از آینه‌ی Maven مایکت گرفته می‌شوند (Maven Central از ایران باز نمی‌شود).
set -euo pipefail
cd "$(dirname "$0")"

GODOT_VERSION="4.7.2.stable"
ADIVERY_VERSION="4.9.0"
MIRROR="https://maven.myket.ir"
ANDROID_JAR="${ANDROID_JAR:-$LOCALAPPDATA/Android/Sdk/platforms/android-34/android.jar}"
JDK_BIN="${JDK_BIN:-/f/Program Files/Java/jdk-17.0.19/bin}"
OUT="../../addons/rewarded_ads/bin/RewardedAds.aar"

mkdir -p .deps .build/classes .build/aar
[ -f .deps/godot.jar ] || { curl -sfL "$MIRROR/org/godotengine/godot/$GODOT_VERSION/godot-$GODOT_VERSION.aar" -o .deps/godot.aar && unzip -p .deps/godot.aar classes.jar > .deps/godot.jar && rm .deps/godot.aar; }
[ -f .deps/adivery.jar ] || { curl -sfL "$MIRROR/com/adivery/sdk/$ADIVERY_VERSION/sdk-$ADIVERY_VERSION.aar" -o .deps/adivery.aar && unzip -p .deps/adivery.aar classes.jar > .deps/adivery.jar && rm .deps/adivery.aar; }

rm -rf .build/classes/* .build/aar/*
"$JDK_BIN/javac" -encoding UTF-8 -source 8 -target 8 -nowarn -Xlint:-options \
  -bootclasspath "$ANDROID_JAR" -cp ".deps/godot.jar;.deps/adivery.jar" \
  -d .build/classes $(find src -name '*.java')
"$JDK_BIN/jar" cf .build/aar/classes.jar -C .build/classes .
cp AndroidManifest.xml .build/aar/
: > .build/aar/R.txt
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(cd .build/aar && "$JDK_BIN/jar" cfM "../../$OUT" AndroidManifest.xml classes.jar R.txt)
echo "built $OUT"
