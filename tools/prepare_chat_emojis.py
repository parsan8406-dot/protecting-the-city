"""آماده‌سازی ایموجی‌های چت برای بازی.

عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با پس‌زمینه‌ی سفید) از پوشه‌ی
assets/chat/emojies_src خوانده می‌شوند و نسخه‌ی بازی در assets/chat/emojies
ساخته می‌شود:
  - پس‌زمینه‌ی یکدستِ متصل به لبه‌ها شفاف می‌شود (flood fill از لبه‌ها)
  - دور ایموجی بریده و مربع می‌شود
  - به SIZE×SIZE کوچک می‌شود (حجم APK)
  - نام فایل‌ها emoji_01.png, emoji_02.png, ... می‌شود (توکن چت :e01:)

پوشه‌ی src یک فایل .gdignore دارد تا Godot عکس‌های خام را ایمپورت نکند.
اگر ایموجی تازه خواستی: فایل را به emojies_src اضافه کن و دوباره اجرا کن —
ترتیب بر اساس نام فایل است و نام‌های قبلی ثابت می‌مانند فقط اگر فایل جدید
بعد از بقیه مرتب شود؛ پس به فایل‌های جدید پیشوند zz_ بده.

خروجی: JSON خلاصه روی stdout.
"""

import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "chat", "emojies_src")
DST = os.path.join(ROOT, "assets", "chat", "emojies")
SIZE = 160
PAD = 0.04  # حاشیه‌ی دور ایموجی نسبت به ضلع
TOLERANCE = 38.0  # فاصله‌ی رنگ تا پس‌زمینه که هنوز پس‌زمینه حساب شود
FEATHER = 34.0  # نرمی لبه


def process(path: str) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    arr = np.asarray(im).astype(np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3]

    if alpha.min() < 250:
        # از قبل شفاف است — فقط همان آلفا
        out_alpha = alpha
    else:
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        bg = np.median(border, axis=0)
        dist = np.sqrt(((rgb - bg) ** 2).sum(axis=-1))
        near = dist < TOLERANCE
        labels, _ = ndimage.label(near)
        edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
        edge_labels = edge_labels[edge_labels != 0]
        background = np.isin(labels, edge_labels)
        # لبه‌ی نرم: پیکسل‌های نزدیک پس‌زمینه بر اساس فاصله‌ی رنگ شفاف‌تر می‌شوند
        grown = ndimage.binary_dilation(background, iterations=3)
        band = grown & ~background
        out_alpha = np.full(alpha.shape, 255.0, dtype=np.float32)
        out_alpha[background] = 0.0
        soft = np.clip((dist - TOLERANCE * 0.5) / FEATHER, 0.0, 1.0) * 255.0
        out_alpha[band] = np.minimum(out_alpha[band], soft[band])

    result = np.dstack([rgb, out_alpha]).astype(np.uint8)
    out = Image.fromarray(result, "RGBA")

    ys, xs = np.where(out_alpha > 16)
    if len(xs) == 0:
        return out.resize((SIZE, SIZE), Image.LANCZOS)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    out = out.crop((x0, y0, x1, y1))

    side = int(max(out.width, out.height) * (1.0 + PAD * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(out, ((side - out.width) // 2, (side - out.height) // 2))
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    if not os.path.isdir(SRC):
        print(json.dumps({"error": "src folder missing", "src": SRC}))
        sys.exit(1)

    os.makedirs(DST, exist_ok=True)
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")))
    report = []
    for i, name in enumerate(files, start=1):
        out_name = "emoji_%02d.png" % i
        img = process(os.path.join(SRC, name))
        img.save(os.path.join(DST, out_name), optimize=True)
        a = np.asarray(img)[..., 3]
        edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
        report.append({
            "src": name,
            "out": out_name,
            "kb": os.path.getsize(os.path.join(DST, out_name)) // 1024,
            "opaque_ratio": round(float((a > 128).mean()), 3),
            "edge_max_alpha": int(edge.max()),
        })
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
