package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// loadDotEnv متغیرهای محرمانه (کلید گوگل، ...) را از فایل .env می‌خواند.
//
// اول کنارِ فایل اجرایی سرور، بعد پوشه‌ی جاری. هر خط KEY=VALUE است؛ خطِ خالی
// و خطی که با # شروع شود نادیده گرفته می‌شود. متغیری که از قبل در محیط سیستم
// ست شده دست نمی‌خورد — پس روی سرور واقعی می‌شود بدون فایل، با متغیر محیطی کار کرد.
// خودِ فایل در .gitignore است.
func loadDotEnv() {
	candidates := []string{}
	if exe, err := os.Executable(); err == nil {
		candidates = append(candidates, filepath.Join(filepath.Dir(exe), ".env"))
	}
	candidates = append(candidates, ".env")

	for _, path := range candidates {
		f, err := os.Open(path)
		if err != nil {
			continue
		}
		n := applyDotEnv(bufio.NewScanner(f))
		f.Close()
		fmt.Printf("🔑 %d setting(s) loaded from %s\n", n, path)
		return
	}
}

func applyDotEnv(sc *bufio.Scanner) int {
	loaded := 0
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(strings.TrimPrefix(key, "export "))
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if key == "" {
			continue
		}
		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		if os.Setenv(key, value) == nil {
			loaded++
		}
	}
	return loaded
}
