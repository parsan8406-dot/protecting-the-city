"""پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند.

  python tools/strip_white_bg.py            # هر چهار لوگوی assets/ui/modes
  python tools/strip_white_bg.py a.png b.png

فقط سفیدی‌ای پاک می‌شود که به لبه‌ی تصویر وصل است — سفیدیِ داخلِ لوگو
(جمجمه، اسلحه، پرچم) دست نمی‌خورد. تصویری که از قبل شفاف است رد می‌شود.
خروجی JSON روی stdout.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
DEFAULT = [ROOT / "assets/ui/modes" / f"{n}.png" for n in ("strike", "revenge", "banish", "citypoint")]
MAX_SIDE = 512
WHITE = 232          # حداقلِ کمترین کانالِ رنگ برای «سفید»


def strip(path: Path) -> dict:
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    border = np.concatenate([alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]])
    if (border < 20).mean() > 0.5:
        return {"file": str(path), "skipped": "already transparent"}

    whiteness = rgb.min(axis=2)
    light = whiteness >= WHITE
    labels, _ = ndimage.label(light)
    edge_ids = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, edge_ids[edge_ids > 0])

    # لبه‌ی نرم: حلقه‌ی دورِ پس‌زمینه به نسبتِ سفیدی‌اش نیمه‌شفاف می‌شود
    ring = ndimage.binary_dilation(bg, iterations=2) & ~bg
    soft = np.clip((whiteness - 170.0) / (WHITE - 170.0), 0.0, 1.0)
    alpha[bg] = 0.0
    alpha[ring] *= 1.0 - soft[ring]
    a[..., 3] = alpha

    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    box = out.getbbox()
    if box:
        out = out.crop(box)
    out.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)
    out.save(path, optimize=True)
    return {"file": str(path), "size": out.size, "removed_px": int(bg.sum())}


if __name__ == "__main__":
    files = [Path(p) for p in sys.argv[1:]] or DEFAULT
    print(json.dumps([strip(f) if f.exists() else {"file": str(f), "error": "missing"}
                      for f in files], ensure_ascii=False, indent=1))
