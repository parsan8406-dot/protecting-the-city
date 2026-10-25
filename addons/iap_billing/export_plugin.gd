@tool
extends EditorExportPlugin
## پلاگینِ اندرویدیِ پرداخت را داخلِ APK می‌گذارد — فقط برای فروشگاهِ همان پریست:
##   Custom Features شامل «myket» → MyketBilling.aar
##   در غیر این صورت              → BazaarBilling.aar
## (Billing.gd هم فروشگاه را با همین feature انتخاب می‌کند.)
## سورس و ساختِ aarها: android_plugins/iap_billing/build.sh


func _get_name() -> String:
	return "IapBilling"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["iap_billing/bin/%s.aar" % _aar_name()])


func _aar_name() -> String:
	var preset := get_export_preset()
	if preset and "myket" in preset.get_custom_features().to_lower():
		return "MyketBilling"
	return "BazaarBilling"
