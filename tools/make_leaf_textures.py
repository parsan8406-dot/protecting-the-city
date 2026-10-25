"""برگ‌های باد: از assets/Leaf.png دو بافتِ کوچکِ ذره می‌سازد.

فایلِ اصلی ۱۲۵۴x۱۲۵۴ است و بیشترش خالی — برای یک ذره‌ی ۴۰ پیکسلی روی گوشی
هم حافظه‌ی گرافیکی را هدر می‌دهد هم حجمِ APK را. اینجا به کادرِ خودِ برگ
بریده و کوچک می‌شود:

  assets/leaf_a.png  برگِ کامل            (لایه‌ی جلو)
  assets/leaf_b.png  آینه‌شده و باریک‌تر  (لایه‌ی عقب — تنوعِ ظاهری)

برگ خاکستریِ خنثی است و رنگش در بازی با color_ramp از تمِ زمین می‌آید
(ThemeArt.leaf_colors)، پس اینجا رنگ دست نمی‌خورد.

اجرا:  python tools/make_leaf_textures.py
"""
from PIL import Image

SRC = "assets/Leaf.png"
MAX_SIDE = 96          # بزرگ‌ترین ضلعِ خروجی
ALPHA_CUT = 8          # کمتر از این آلفا = خالی

im = Image.open(SRC).convert("RGBA")
box = im.split()[3].point(lambda a: 255 if a > ALPHA_CUT else 0).getbbox()
leaf = im.crop(box)
w, h = leaf.size

k = MAX_SIDE / max(w, h)
a = leaf.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
a.save("assets/leaf_a.png")

# نسخه‌ی دوم: آینه + ۲۵٪ باریک‌تر، تا دو لایه‌ی باد یک شکل نباشند
bw = max(1, round(a.width * 0.75))
b = a.transpose(Image.FLIP_LEFT_RIGHT).resize((bw, a.height), Image.LANCZOS)
b.save("assets/leaf_b.png")

print("leaf_a.png", a.size, " leaf_b.png", b.size)
