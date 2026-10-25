"""خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد.

شکلِ مرجع: چند خطِ کشیده که با هم می‌روند و سرشان توی یک مارپیچ می‌پیچد —
همان چیزی که در نقاشی‌ها «باد» را نشان می‌دهد. اینجا سفیدِ خالص کشیده
می‌شود و رنگ/محوی‌اش در بازی با modulate می‌آید (scripts/wind.gd)، پس یک
بافت برای همه‌ی تم‌ها کافی است.

کانالِ قرمز «کجای خط» را نگه می‌دارد (۰ ته، ۱ نوکِ مارپیچ) و آلفا شکل را.
شیدرِ shaders/wind_swirl.gdshader با همین کانال خط را از ته به نوک می‌کشد
و بعد از ته جمع می‌کند، پس وزش کشیده و پیچیده می‌شود نه اینکه یک عکسِ
ثابت روی صفحه سُر بخورد.

  assets/wind_swirl_1.png
  assets/wind_swirl_2.png
  assets/wind_swirl_3.png

هر بافت یکی-دو رشته دارد و رشته‌ها عمداً هم‌شکل نیستند تا سه وزشِ پشتِ هم
کپیِ هم به نظر نرسند. نوکِ هر رشته نازک می‌شود تا خط «شروع و پایانِ بریده»
نداشته باشد.

اجرا:  python tools/make_wind_swirls.py
"""
import math

from PIL import Image, ImageDraw

W, H = 512, 256          # اندازه‌ی نهایی
SS = 4                   # چند برابر بزرگ‌تر می‌کشیم و بعد کوچک می‌کنیم (ضدِ پله)
BASE_Y = H * 0.5


def smoothstep(a: float, b: float, x: float) -> float:
    if b <= a:
        return 0.0 if x < a else 1.0
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def strand(length, amp, phase, r0, turns, spin, y0):
    """یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود."""
    pts = []
    n = 240
    for i in range(n):
        t = i / (n - 1)
        pts.append((t * length, y0 + amp * math.sin(t * math.pi * 1.1 + phase)))

    # مارپیچ از همان نقطه‌ی پایانی و با همان جهت ادامه پیدا می‌کند
    x_end, y_end = pts[-1]
    cx, cy = x_end, y_end + spin * r0
    th0 = -spin * math.pi * 0.5
    m = 190
    for i in range(1, m + 1):
        u = i / m
        th = th0 + spin * u * turns * 2.0 * math.pi
        r = r0 * math.exp(-1.15 * u)
        pts.append((cx + r * math.cos(th), cy + r * math.sin(th)))
    return pts


def draw_strand(d_alpha, d_par, pts, w_max):
    """شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par."""
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        f = i / (n - 1)
        # نازک در دو سر، پرتر در یک‌سومِ اول، و باریک‌شونده تا نوکِ مارپیچ
        w = w_max * smoothstep(0.0, 0.16, f) * (1.0 - 0.82 * smoothstep(0.30, 1.0, f))
        if w <= 0.15:
            continue
        r = w * SS * 0.5
        d_alpha.ellipse([x * SS - r, y * SS - r, x * SS + r, y * SS + r], fill=255)
        # کانالِ پارامتر کمی پهن‌تر کشیده می‌شود تا موقعِ کوچک‌کردنِ تصویر،
        # لبه‌ی خط با صفرِ پس‌زمینه مخلوط نشود و نوکِ خط نپرد
        rp = r + 2.0 * SS
        d_par.ellipse([x * SS - rp, y * SS - rp, x * SS + rp, y * SS + rp],
                      fill=1 + int(round(f * 254)))


## [طول, دامنه, فاز, شعاعِ مارپیچ, دور, جهتِ پیچش, جابه‌جاییِ عمودی, ضخامت]
VARIANTS = [
    [  # یک رشته‌ی بلند با پیچِ رو به بالا و یک رشته‌ی کوتاهِ همراه
        (300, 16, 0.0, 36, 1.55, 1, 0, 5.4),
        (196, 11, 2.3, 21, 1.30, 1, 46, 3.6),
    ],
    [  # دسته‌ی سه‌تایی، پیچ‌ها در دو جهت — شبیه‌ترین به تصویرِ مرجع
        (322, 13, 0.6, 33, 1.70, -1, -30, 5.0),
        (250, 18, 0.0, 26, 1.45, 1, 14, 4.2),
        (150, 9, 1.4, 16, 1.15, 1, 56, 2.8),
    ],
    [  # یک وزشِ تکِ کشیده و کم‌پیچ — برای وزش‌های ملایم‌تر
        (352, 21, 0.3, 30, 1.35, -1, 6, 4.6),
        (168, 12, 2.8, 18, 1.10, -1, -42, 3.0),
    ],
]


def build(spec, path):
    img = Image.new("L", (W * SS, H * SS), 0)
    par = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(img)
    dp = ImageDraw.Draw(par)
    for length, amp, phase, r0, turns, spin, dy, w in spec:
        pts = strand(length, amp, phase, r0, turns, spin, BASE_Y + dy)
        draw_strand(d, dp, pts, w)
    alpha = img.resize((W, H), Image.LANCZOS)
    # پارامتر با BOX کوچک می‌شود نه LANCZOS: لانچوس روی لبه‌ها بالا/پایین
    # می‌زند و «کجای خط» را جابه‌جا می‌کند
    param = par.resize((W, H), Image.BOX)

    # قرمز = کجای خط، سبز/آبی بی‌کاربرد، آلفا = شکل. رنگ از modulate می‌آید.
    rgba = Image.merge("RGBA", (param, param, param, alpha))
    rgba.save(path)
    box = alpha.point(lambda a: 255 if a > 6 else 0).getbbox()
    print(path, "bbox", box)


for i, spec in enumerate(VARIANTS, start=1):
    build(spec, "assets/wind_swirl_%d.png" % i)
