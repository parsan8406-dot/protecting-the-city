<#
.SYNOPSIS
    دو نسخه‌ی بازی را همزمان با دو اکانت متفاوت بالا می‌آورد تا بشود مولتی‌پلیر را دیباگ کرد.

.DESCRIPTION
    هاب سرور یک دنیای مشترک است: هرکس به ws://localhost:8080/ws وصل شود و join بفرستد
    در همان آرنا می‌افتد. پس فقط کافی است دو نسخه با --username متفاوت اجرا شوند.
    (اگر هر دو با یک یوزرنیم بالا بیایند، سرور آن‌ها را یک بازیکن می‌بیند چون
    h.players با username کلید می‌خورد و دومی اولی را بازنویسی می‌کند.)

.PARAMETER PlayerA
    یوزرنیم نسخه‌ی اول. پیش‌فرض DebugA

.PARAMETER PlayerB
    یوزرنیم نسخه‌ی دوم. پیش‌فرض DebugB

.PARAMETER Menu
    از منوی اصلی شروع کن به‌جای پریدن مستقیم توی آرنا.

.PARAMETER Godot
    مسیر اجرایی گودوت. اگر ندهی خودش می‌گردد.

.EXAMPLE
    .\tools\debug_two_clients.ps1
    .\tools\debug_two_clients.ps1 -PlayerA Ali -PlayerB Reza
    .\tools\debug_two_clients.ps1 -Menu
#>
[CmdletBinding()]
param(
    [string]$PlayerA = "DebugA",
    [string]$PlayerB = "DebugB",
    [switch]$Menu,
    [string]$Godot
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot

# ---- پیدا کردن اجرایی گودوت ----
if (-not $Godot) {
    $candidates = @(
        "F:\Files\New folder\Godot4.7.2\Godot_v4.7.2-stable_win64.exe",
        "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe"
    )
    # مسیری که خود ادیتور آخرین بار استفاده کرده
    $meta = Join-Path $projectRoot ".godot\editor\project_metadata.cfg"
    if (Test-Path $meta) {
        $line = Select-String -Path $meta -Pattern '^executable_path="(.+)"$' | Select-Object -First 1
        if ($line) { $candidates = @($line.Matches[0].Groups[1].Value) + $candidates }
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += $cmd.Source }

    $Godot = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "اجرایی گودوت پیدا نشد. با -Godot مسیرش را بده."
}

# ---- هشدار اگر سرور بالا نیست ----
$listening = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
    Write-Warning "چیزی روی پورت 8080 گوش نمی‌دهد. اول سرور را بالا بیاور: cd gun_game_server; go run ."
}

# ---- چیدمان پنجره‌ها کنار هم ----
# صفحه 1536x864 است و پنجره‌ی بازی 1152x648؛ دو تا در اندازه‌ی اصلی جا نمی‌شوند،
# پس کوچک‌ترشان می‌کنیم تا هر دو همزمان دیده شوند.
$w = 750
$h = 422
$y = 90
$positions = @("0,$y", "770,$y")

$common = @(
    "--path", $projectRoot,
    "--resolution", "${w}x${h}"
)
if (-not $Menu) { $common += "--autostart" }

$players = @($PlayerA, $PlayerB)
$procs = @()

for ($i = 0; $i -lt $players.Count; $i++) {
    $argsList = $common + @("--position", $positions[$i], "--username=$($players[$i])")
    Write-Host "▶ launching '$($players[$i])'  ($($positions[$i]))" -ForegroundColor Cyan
    $procs += Start-Process -FilePath $Godot -ArgumentList $argsList -PassThru
    Start-Sleep -Milliseconds 700   # فاصله تا join ها روی هم نیفتند
}

Write-Host ""
Write-Host "دو نسخه بالا آمد:" -ForegroundColor Green
foreach ($p in $procs) { Write-Host "   PID $($p.Id)" }
Write-Host ""
$ids = ($procs | ForEach-Object { $_.Id }) -join ","
Write-Host "برای بستن هر دو:" -ForegroundColor Yellow
Write-Host "   Stop-Process -Id $ids"
