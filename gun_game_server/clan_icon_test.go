package main

import "testing"

// نشان شهر فقط باید شکل "emblem:<نماد>:<رنگ>" یا خالی باشد — مسیر دلخواه
// (مثلاً res://...) نباید به دیتابیس برسد و بعد روی کلاینت بقیه لود شود.
func TestValidClanIcon(t *testing.T) {
	ok := []string{"", "emblem:0:0", "emblem:8:5", "emblem:12:34"}
	for _, s := range ok {
		if !validClanIcon(s) {
			t.Errorf("validClanIcon(%q) = false, want true", s)
		}
	}

	bad := []string{
		"res://assets/ui/profile_menu/icon_clan.svg",
		"emblem:1",
		"emblem:1:2:3",
		"emblem:a:b",
		"emblem:123:1",
		" emblem:1:1",
		"emblem:1:1\n",
	}
	for _, s := range bad {
		if validClanIcon(s) {
			t.Errorf("validClanIcon(%q) = true, want false", s)
		}
	}
}
