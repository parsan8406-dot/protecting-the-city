@tool
extends EditorExportPlugin
## RewardedAds.aar + SDKِ ادیوری را داخلِ APK می‌گذارد.
## سورس و ساخت: android_plugins/rewarded_ads/build.sh

const ADIVERY := "com.adivery:sdk:4.9.0"


func _get_name() -> String:
	return "RewardedAds"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["rewarded_ads/bin/RewardedAds.aar"])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([ADIVERY])
