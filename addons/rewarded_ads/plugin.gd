@tool
extends EditorPlugin
## فقط export plugin را ثبت می‌کند؛ منطقِ تبلیغ در scripts/Ads.gd است.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("export_plugin.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
