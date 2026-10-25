#!/usr/bin/env python3
"""
ساخت داده‌ی زمین‌های بازی.

خروجی: یک JSON برای هر زمین (هم گودوت و هم سرور Go همین فایل‌ها را می‌خوانند)

  arena_map.json      زمینِ پیش‌فرض — حالت‌های تیمی (عملیات ضربت و بقیه)
  arena_revenge.json  زمینِ «عملیات انتقام» — دو نفره، با ریسپاون
  arena_banish.json   زمینِ «عملیات حذف شیطان» — راهروهای رو به مرکز

دو جور چیدمان داریم (MapSpec.layout):

  "rooms"   شبکه‌ی اتاق: دیوارهای داخلی زمین را به اتاق‌های cols×rows تقسیم
            می‌کنند و هر دیوارِ بینِ دو اتاق یا یک درِ خروجی دارد یا کلاً
            برداشته شده تا دو اتاق یکی شوند (سالن).

  "arena"   حیاطِ وسط + راهرو: وسطِ نقشه یک میدانِ چهاردیواری است (جای
            شیطان) با چهار دروازه، و از هر دروازه یک راهروی مستقیم تا
            بیرون کشیده شده. بیرونِ حیاط اتاقِ بسته‌ای وجود ندارد — فقط
            میدانِ باز با دیوارهای بلندِ مستقیم که همه رو به مرکز خوابیده‌اند.
            یعنی بازیکن از هر جای نقشه که بایستد، امتدادِ دیوارها او را به
            سمتِ شیطان می‌برد.

روش کار:
  1. اندازه‌ی جهانی از روی نسبت تصویر بک‌گراند حساب می‌شود (عرض ثابت WORLD_W).
     همه‌ی زمین‌ها یک اندازه‌اند تا یک بک‌گراند برای همه جا بیفتد.
  2. چیدمانِ اتاق‌ها ساخته می‌شود: اول یک درختِ پوشا روی گرافِ اتاق‌ها تا هیچ
     اتاقی بن‌بست نشود، بعد چند درِ اضافه برای حلقه (بن‌بست در بازی تیراندازی
     یعنی مرگ) و چند دیوارِ حذف‌شده برای اینکه همه‌ی اتاق‌ها هم‌اندازه نباشند
  3. ۴ تا ۵ مانعِ پناه‌گیری در هر اتاق (build_obstacles) — با این شرط که
     بازیکن هنوز از هر در و هر اتاق به همه‌جا برسد
  4. دیوارها هم به‌صورت مستطیل (کلاینت، برای move_and_slide) و هم داخل گریدِ
     بیتی (سرور، برای اعتبارسنجی حرکت و خطِ دید) نوشته می‌شوند — این دو باید
     همیشه یکی باشند وگرنه تیر از دیواری رد می‌شود که کلاینت نشانش می‌دهد
  5. نقاط شروع فقط جایی گذاشته می‌شوند که دایره‌ی بازیکن واقعاً جا شود، و با
     flood fill بررسی می‌شود که همه‌شان به هم راه دارند

بذرِ هر زمین ثابت است تا نقشه بازتولیدپذیر بماند: با یک بذر، همیشه یک نقشه.

اجرا:  python tools/build_arena.py                 (همه‌ی زمین‌ها)
       python tools/build_arena.py --map revenge   (فقط یکی)
       python tools/build_arena.py --preview       (یک PNG از چیدمان هم می‌سازد)

توجه: بعد از اجرا سرور Go را دوباره بیلد کن — JSONها با go:embed داخل باینری
  می‌روند، پس تا بیلد نشود سرور نقشه‌ی قدیمی را دارد:
      cd gun_game_server && go build
"""
import base64, json, os, random, sys
from collections import deque
from dataclasses import dataclass, field

import numpy as np
from PIL import Image
from scipy import ndimage

Image.MAX_IMAGE_PIXELS = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG = os.path.join(ROOT, "assets", "Background.png")
RES_DIR = os.path.join(ROOT, "resources")
# نسخه‌ی دوم کنار سرور تا با go:embed داخل باینری برود (هر دو از یک منبع ساخته می‌شوند)
SRV_DIR = os.path.join(ROOT, "gun_game_server")
PREVIEW_DIR = os.path.join(ROOT, "graphify-out")

WORLD_W = 2000           # عرض زمین در واحد جهانی؛ ارتفاع از نسبت تصویر می‌آید
CELL = 8                 # اندازه‌ی هر خانه‌ی گرید (واحد جهانی)
BORDER = 64              # ضخامت دیوارهای دور زمین (بیرون از کادر کشیده می‌شوند)

MIN_DOOR = 90            # چکِ ایمنی: هیچ دری نباید از این باریک‌تر باشد
PLAYER_R = 30.0          # شعاعِ بازیکن برای اعتبارسنجی نقاط شروع


@dataclass
class MapSpec:
    """پارامترهای یک زمین. هر زمین یک فایل JSON مستقل می‌شود."""
    key: str                  # نامِ فایل: arena_<key>.json (برای پیش‌فرض: arena_map.json)
    ## برچسبِ ترمینال. عمداً ASCII است: کنسولِ ویندوز اینجا cp1252 است و روی
    ## حرفِ فارسی می‌ترکد (همان دلیلی که پیامِ آخرِ main هم ASCII است).
    title: str
    seed: int
    room_cols: int
    room_rows: int
    wall_t: int = 24          # ضخامت دیوارِ داخلی (مضرب CELL)
    ## عرضِ درها. بازیکن روی کلاینت شعاع ۲۹.۳ دارد (قطر ~۵۹). تنگ‌ترین در ۹۶
    ## است — یعنی ~۱۸ واحد فاصله از هر طرف؛ کمتر از این با جوی‌استیکِ موبایل
    ## عملاً دیوار است، بازیکن مدام گیر می‌کند.
    door_widths: tuple = (96, 96, 136, 136, 136, 200, 200)
    extra_door_chance: float = 0.62  # درِ اضافه روی یال‌های خارج از درختِ پوشا
    open_wall_chance: float = 0.28   # دیوارِ کاملاً حذف‌شده: دو اتاق یکی می‌شوند
    jitter: float = 0.05             # جابه‌جاییِ خطوطِ تقسیم (کسری از عرض/ارتفاع)
    light_zones: int = 5             # چند کانونِ نور روی زمینِ تاریک
    ## موانعِ پناه‌گیریِ هر اتاق: (کمینه، بیشینه). مانع مربع است چون بافت‌هایش
    ## مربع‌اند (assets/themes/*/obstacle_*.png).
    obstacles_per_room: tuple = (4, 5)
    obstacle_size: tuple = (40, 64)   # بازه‌ی ضلع (واحد جهانی)
    ## چه سهمی از موانع پشت به دیوار باشند. مانعِ چسبیده به دیوار از فضای
    ## راه‌رفتنِ کمتری می‌خورد (یک طرفش همان حاشیه‌ی دیوار است)؛ در اتاق‌های
    ## کوچک این فرقِ «تنگ» و «قابلِ بازی» است.
    obstacle_hug: float = 0.7
    ## فایلِ خروجی. برای زمینِ پیش‌فرض عمداً همان نامِ قدیمی می‌ماند تا مسیرها
    ## و go:embedِ موجود نشکنند.
    filename: str = ""

    ## --- چیدمان ---
    ## "rooms" شبکه‌ی اتاق (پیش‌فرض) | "arena" حیاطِ وسط و راهروهای رو به مرکز
    layout: str = "rooms"
    ## (نصفِ عرض، نصفِ ارتفاعِ) حیاطِ وسط — فقط برای layout="arena"
    plaza: tuple = (320, 250)
    ## دهانه‌ی هر دروازه‌ی حیاط. عرضِ راهروها هم همین است.
    gate_width: int = 200
    ## چند نقطه‌ی شروع در هر اتاق/میدان. نقشه‌ی اتاقی اتاق‌های زیادی دارد پس
    ## یکی کافی است؛ نقشه‌ی «arena» فقط چهار میدان دارد و به نقاطِ بیشتری
    ## نیاز دارد، وگرنه ریسپاونِ امن (RespawnSafeDistance) جایی برای انتخاب
    ## ندارد و هر بار همان چند نقطه تکرار می‌شود.
    spawns_per_room: int = 1

    def out_name(self) -> str:
        return self.filename or f"arena_{self.key}.json"

    @property
    def door_end_margin(self) -> int:
        """چقدر از دو سرِ یک دیوار در نگذاریم — در نباید به دیوارِ عمود بچسبد،
        وگرنه گوشه‌ی تیزی می‌سازد که بازیکن پشتش گیر می‌کند."""
        return self.wall_t + 34


MAPS: dict[str, MapSpec] = {
    # زمینِ پیش‌فرضِ حالت‌های تیمی. اعداد دست نخورده‌اند: با همین بذر باید
    # دقیقاً همان نقشه‌ی قبلی دربیاید.
    "map": MapSpec(
        key="map", title="default arena (team modes)",
        seed=20260906, room_cols=4, room_rows=3,
        filename="arena_map.json",
    ),
    # «عملیات انتقام»: دو در دو، دو دقیقه، با ریسپاون.
    #
    # چرا این‌طور چیده شده: در حالتِ حذفی گوشه گرفتن و صبر کردن جواب می‌دهد،
    # ولی این‌جا مرگ موقتی است و برنده کسی است که بیشتر بزند. پس زمین باید
    # جریان داشته باشد نه بن‌بست:
    #   - اتاق‌های کمتر و بزرگ‌تر (۳×۲) → میدانِ باز برای درگیریِ سریع
    #   - درهای پهن‌تر و حلقه‌های بیشتر → همیشه یک راهِ دور زدن هست
    #   - ستون‌های پناه‌گیری وسطِ اتاق‌ها → میدانِ باز بدونِ پناه یعنی هر کس
    #     اول دید، برنده است؛ ستون‌ها به بازیکنِ ضعیف‌تر فرصتِ نزدیک شدن می‌دهند
    "revenge": MapSpec(
        key="revenge", title="revenge deathmatch (2v2, respawn)",
        seed=20260908, room_cols=3, room_rows=2,
        wall_t=24,
        door_widths=(136, 168, 168, 200, 240),
        extra_door_chance=0.85, open_wall_chance=0.18,
        jitter=0.04, light_zones=4,
        obstacle_size=(56, 104),
    ),
    # «عملیات حذف شیطان»: سه در سه، شیطان وسطِ نقشه.
    #
    # چرا اتاق ندارد: هدفِ این حالت یک نقطه‌ی مشخص است، نه گشتنِ نقشه. با
    # شبکه‌ی اتاق، بازیکن وارد یک اتاق می‌شد و هیچ سرنخی نداشت که مرکز کدام
    # طرف است. این‌جا به‌جایش:
    #   - حیاطِ چهاردیواریِ وسط با چهار دروازه → «آن‌جا یک چیزی هست»
    #   - از هر دروازه یک راهروی مستقیم تا بیرون → راهِ آماده به سمتِ مرکز
    #   - دیوارهای بلندِ بیرونی همه هم‌راستا با مسیرِ مرکز → حتی وقتی داخلِ
    #     راهرو نیستی، خطِ دیوارها چشمت را به سمتِ وسط می‌برد
    # دیوارِ ضخیم‌تر (۳۲) چون این دیوارها بلندند و باید از دور دیده شوند.
    # اعداد عمداً «بازتر از حدِ لازم»اند. اولین نسخه با دروازه‌ی ۲۰۰ و دو
    # ردیف تیغه در هر میدان ساخته شد و بازخورد این بود که «دیوار زیاد است».
    # در حالتی که کلِ هدفش رسیدن به یک نقطه‌ی مشخص است، هر دیوارِ اضافه یک
    # دورزدنِ اضافه است — و دورزدن یعنی گم شدن. پس:
    #   دروازه و راهرو ۲۶۰ (از قطرِ بازیکن ~۵۹ چهار برابر پهن‌تر)
    #   یک ردیف تیغه در هر میدان به‌جای دو
    #   موانعِ کمتر و کوچک‌تر
    "banish": MapSpec(
        key="banish", title="demon hunt (3v3, centre arena)",
        seed=20260910, room_cols=0, room_rows=0,
        layout="arena",
        wall_t=32,
        plaza=(340, 262), gate_width=260,
        light_zones=5,
        spawns_per_room=4,
        obstacles_per_room=(2, 3),
        obstacle_size=(48, 80),
        obstacle_hug=0.45,
    ),
}


def world_size() -> tuple[int, int]:
    """اندازه‌ی جهانی: عرض ثابت، ارتفاع از روی نسبت تصویر بک‌گراند."""
    with Image.open(BG) as im:
        w, h = im.size
    world_h = int(round(WORLD_W * h / w))
    # به مضرب CELL گرد می‌شود تا گرید بدون باقی‌مانده جا شود
    world_h = int(round(world_h / CELL) * CELL)
    print(f"background {w}x{h} -> world {WORLD_W}x{world_h}")
    return WORLD_W, world_h


def border_rects(world_w: int, world_h: int):
    """چهار دیوار دور زمین. بیرون از کادر گذاشته می‌شوند تا روی بک‌گراند نیفتند."""
    b = BORDER
    return [
        [-b, -b, world_w + 2 * b, b],            # بالا
        [-b, world_h, world_w + 2 * b, b],       # پایین
        [-b, 0, b, world_h],                     # چپ
        [world_w, 0, b, world_h],                # راست
    ]


def snap(v: float) -> int:
    """گرد کردن به مضربِ CELL — دیوار باید دقیقاً روی مرزِ خانه‌های گرید بنشیند،
    وگرنه مستطیلِ کلاینت و گریدِ سرور نیم‌خانه با هم اختلاف پیدا می‌کنند."""
    return int(round(v / CELL) * CELL)


# ============================ چیدمانِ اتاق‌ها ============================

def spanning_tree(rng: random.Random, edges: list) -> set:
    """یک درختِ پوشای تصادفی روی گرافِ اتاق‌ها (union-find).

    هر یالِ درخت حتماً در می‌گیرد، پس هیچ اتاقی از بقیه بریده نمی‌ماند —
    این تنها چیزی است که «همه‌جا قابل رفتن است» را تضمین می‌کند.
    """
    parent = {}

    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    shuffled = list(edges)
    rng.shuffle(shuffled)
    tree = set()
    for e in shuffled:
        ra, rb = find(e[0]), find(e[1])
        if ra != rb:
            parent[ra] = rb
            tree.add(e)
    return tree


def build_rooms(world_w: int, world_h: int, rng: random.Random, spec: MapSpec):
    """دیوارهای داخلی + فهرستِ درها + مستطیلِ اتاق‌ها را می‌سازد."""
    cols, rows, wall_t = spec.room_cols, spec.room_rows, spec.wall_t
    jitter = spec.jitter
    # خطوطِ تقسیم عمداً یکنواخت نیستند: با تقسیمِ مساوی زمین شبیه جدولِ شطرنج
    # می‌شود، نه یک ساختمان. جیتر باعث می‌شود بعضی اتاق‌ها بزرگ و بعضی تنگ
    # دربیایند. دامنه‌ی جیتر کوچک نگه داشته شده تا هیچ بندی برای درش تنگ نشود.
    xs = [snap(world_w * (i / cols + (rng.uniform(-jitter, jitter) if 0 < i < cols else 0)))
          for i in range(cols + 1)]
    ys = [snap(world_h * (j / rows + (rng.uniform(-jitter, jitter) if 0 < j < rows else 0)))
          for j in range(rows + 1)]
    xs[0], ys[0] = 0, 0
    xs[-1], ys[-1] = world_w, world_h
    half = wall_t // 2

    # یال‌های گرافِ اتاق‌ها: ("v", i, r) دیوارِ عمودی بین اتاق (i-1,r) و (i,r)
    #                        ("h", j, c) دیوارِ افقی  بین اتاق (c,j-1) و (c,j)
    edges = []
    for i in range(1, cols):
        for r in range(rows):
            edges.append(("v", i, r))
    for j in range(1, rows):
        for c in range(cols):
            edges.append(("h", j, c))

    def rooms_of(e):
        kind, a, b = e
        if kind == "v":
            return ((a - 1, b), (a, b))
        return ((b, a - 1), (b, a))

    room_edges = [(rooms_of(e)[0], rooms_of(e)[1]) for e in edges]
    tree = spanning_tree(rng, room_edges)

    walls, doors = [], []
    for e in edges:
        ra, rb = rooms_of(e)
        in_tree = (ra, rb) in tree

        if not in_tree and rng.random() < spec.open_wall_chance:
            continue  # دیوار کلاً برداشته می‌شود: دو اتاق یک سالن می‌شوند

        has_door = in_tree or rng.random() < spec.extra_door_chance

        kind, a, b = e
        if kind == "v":
            cx = xs[a]
            lo, hi = ys[b], ys[b + 1]
            span_rect = [cx - half, lo, wall_t, hi - lo]
        else:
            cy = ys[a]
            lo, hi = xs[b], xs[b + 1]
            span_rect = [lo, cy - half, hi - lo, wall_t]

        if not has_door:
            walls.append(span_rect)
            continue

        width = rng.choice(spec.door_widths)
        room = (hi - lo) - 2 * spec.door_end_margin
        # اگر بندِ دیوار برای این عرضِ در جا ندارد، به تنگ‌ترین در برگرد
        if room < width:
            width = max(MIN_DOOR, min(width, room))
        centre = snap(rng.uniform(lo + spec.door_end_margin + width / 2,
                                  hi - spec.door_end_margin - width / 2))
        d_lo = snap(centre - width / 2)
        d_hi = snap(centre + width / 2)

        if kind == "v":
            if d_lo > lo:
                walls.append([cx - half, lo, wall_t, d_lo - lo])
            if hi > d_hi:
                walls.append([cx - half, d_hi, wall_t, hi - d_hi])
            doors.append({"axis": "v", "x": cx, "y0": d_lo, "y1": d_hi,
                          "width": d_hi - d_lo})
        else:
            if d_lo > lo:
                walls.append([lo, cy - half, d_lo - lo, wall_t])
            if hi > d_hi:
                walls.append([d_hi, cy - half, hi - d_hi, wall_t])
            doors.append({"axis": "h", "y": cy, "x0": d_lo, "x1": d_hi,
                          "width": d_hi - d_lo})

    rooms = []
    for r in range(rows):
        for c in range(cols):
            rooms.append([xs[c], ys[r], xs[c + 1] - xs[c], ys[r + 1] - ys[r]])

    walls = [w for w in walls if w[2] > 0 and w[3] > 0]
    return walls, doors, rooms


# ==================== چیدمانِ «حیاطِ وسط» (زمینِ شیطان) ====================
#
# همه‌چیز حولِ یک نقطه چیده می‌شود: مرکزِ نقشه، جایی که شیطان می‌ایستد.
#
#   • حیاط     مستطیلی دورِ مرکز با چهار دروازه (بالا/پایین/چپ/راست). این
#              تنها «اتاقِ» نقشه است و عمداً هم هست: بازیکن باید ببیند که
#              یک‌جا چهاردیواری شده، یعنی آن‌جا چیزی هست.
#   • راهرو    از هر دروازه دو دیوارِ موازی تا بیرون. راهرو دقیقاً به دروازه
#              می‌رسد، پس ایستادن در دهانه‌اش یعنی دیدنِ خودِ شیطان.
#   • تیغه‌ها  دیوارهای بلندِ مستقیمِ بیرونِ حیاط، همه هم‌راستا با راهروها
#              (افقی در میدانِ چپ/راست، عمودی در بالا/پایین). یعنی امتدادِ
#              هر دیواری که می‌بینی به مرکز می‌رسد.
#
# هیچ فضای بسته‌ای ساخته نمی‌شود: بیرونِ حیاط یک حلقه‌ی کاملاً باز است و
# هر تیغه شکاف دارد، پس چکِ اتصالِ build_map همیشه باید سبز باشد.


def _hwall(x0: float, x1: float, y: float, t: int, gap=None):
    """دیوارِ افقی روی خطِ y بینِ x0 و x1، با یک شکافِ اختیاری (x_lo, x_hi).

    خروجی: (مستطیل‌ها، توصیفِ در یا None). شکاف به‌عنوان «در» برمی‌گردد تا
    کفش مثل بقیه‌ی درگاه‌ها روشن شود و مانع جلویش گذاشته نشود.
    """
    x0, x1, y = snap(x0), snap(x1), snap(y)
    half = t // 2
    if x1 <= x0:
        return [], None
    if gap is None:
        return [[x0, y - half, x1 - x0, t]], None
    g0, g1 = snap(max(gap[0], x0)), snap(min(gap[1], x1))
    rects = []
    if g0 > x0:
        rects.append([x0, y - half, g0 - x0, t])
    if x1 > g1:
        rects.append([g1, y - half, x1 - g1, t])
    door = {"axis": "h", "y": y, "x0": g0, "x1": g1, "width": g1 - g0}
    return rects, door


def _vwall(y0: float, y1: float, x: float, t: int, gap=None):
    """همتای عمودیِ _hwall."""
    y0, y1, x = snap(y0), snap(y1), snap(x)
    half = t // 2
    if y1 <= y0:
        return [], None
    if gap is None:
        return [[x - half, y0, t, y1 - y0]], None
    g0, g1 = snap(max(gap[0], y0)), snap(min(gap[1], y1))
    rects = []
    if g0 > y0:
        rects.append([x - half, y0, t, g0 - y0])
    if y1 > g1:
        rects.append([x - half, g1, t, y1 - g1])
    door = {"axis": "v", "x": x, "y0": g0, "y1": g1, "width": g1 - g0}
    return rects, door


def build_arena_layout(world_w: int, world_h: int, rng: random.Random, spec: MapSpec):
    """چیدمانِ حیاط + راهرو. خروجی مثل build_rooms است، به‌علاوه‌ی نورِ مرکز."""
    t = spec.wall_t
    cx, cy = snap(world_w * 0.5), snap(world_h * 0.5)
    pw, ph = spec.plaza
    gate = spec.gate_width
    g2 = gate // 2

    left, right = snap(cx - pw), snap(cx + pw)
    top, bottom = snap(cy - ph), snap(cy + ph)

    walls: list = []
    doors: list = []

    def add(pair):
        rects, door = pair
        walls.extend(rects)
        if door is not None:
            doors.append(door)

    # --- ۱) دیوارهای حیاط، هرکدام با یک دروازه‌ی وسط ---
    add(_hwall(left, right, top, t, (cx - g2, cx + g2)))
    add(_hwall(left, right, bottom, t, (cx - g2, cx + g2)))
    add(_vwall(top, bottom, left, t, (cy - g2, cy + g2)))
    add(_vwall(top, bottom, right, t, (cy - g2, cy + g2)))

    # --- ۲) راهروی هر دروازه ---
    #
    # هر راهرو دو دیوارِ موازی است که دقیقاً روی لبه‌های دروازه می‌نشینند، پس
    # از دهانه‌ی راهرو خطِ دید تا وسطِ حیاط باز است. هر دیوار یک شکافِ کناری
    # دارد تا راهرو تونلِ بن‌بست‌مانند نشود و بشود وسطش وارد/خارج شد.
    side_gap = snap(gate * 0.62)          # پهنای شکافِ کناری

    def corridor(axis: str, from_v: float, to_v: float, mid: float):
        """راهرو بینِ from_v و to_v روی محورِ axis، با محورِ میانیِ mid."""
        lo, hi = min(from_v, to_v), max(from_v, to_v)
        span = hi - lo
        for side in (-1, 1):
            line = mid + side * g2
            # شکاف را روی نقطه‌ی تصادفیِ میانی می‌گذاریم، نه دقیقاً وسط، تا
            # دو دیوارِ راهرو قرینه‌ی هم نباشند
            c = lo + span * rng.uniform(0.42, 0.68)
            gap = (c - side_gap * 0.5, c + side_gap * 0.5)
            if axis == "h":
                add(_hwall(lo, hi, line, t, gap))
            else:
                add(_vwall(lo, hi, line, t, gap))

    reach_x = snap(world_w * 0.10)        # راهروهای چپ/راست تا این فاصله از لبه
    reach_y = snap(world_h * 0.09)
    corridor("h", reach_x, left, cy)                      # غرب
    corridor("h", right, world_w - reach_x, cy)           # شرق
    corridor("v", reach_y, top, cx)                       # شمال
    corridor("v", bottom, world_h - reach_y, cx)          # جنوب

    # --- ۳) تیغه‌های بیرونی ---
    #
    # دیوارهای بلندِ افقی در میدانِ چپ و راست، دقیقاً هم‌راستا با راهروی
    # همان میدان. این‌ها میدانِ باز را به چند نوارِ بلند تقسیم می‌کنند که
    # همه به سمتِ حیاط می‌روند — همان «دیوارِ بلندی که راه را نشان می‌دهد».
    #
    # میدانِ بالا و پایین تیغه ندارند: خودشان از قبل نوارِ باریکِ رو به
    # مرکزند و تیغه فقط تنگشان می‌کرد.
    #
    # PLAZA_CLEAR: تیغه‌ها به دیوارِ حیاط نمی‌چسبند. با چسبیدن، بینِ تیغه و
    # حیاط یک نوارِ باریک می‌ماند که برای عبور تنگ است ولی برای گرید باز —
    # یعنی دقیقاً همان «جیبِ بسته»ای که چکِ اتصال ردش می‌کند.
    PLAZA_CLEAR = 104

    def blades(lines: list, lo: float, hi: float):
        for line in lines:
            span = hi - lo
            c = lo + span * rng.uniform(0.35, 0.65)
            w = snap(rng.uniform(150, 210))
            add(_hwall(lo, hi, line, t, (c - w * 0.5, c + w * 0.5)))

    # یک تیغه در بالای راهرو و یکی در پایینش، و نه بیشتر. هدفِ تیغه نشان
    # دادنِ جهت است، نه ساختنِ هزارتو: دو خطِ بلندِ افقی کافی است تا چشم
    # به سمتِ حیاط کشیده شود، و میدان بینشان کاملاً باز می‌ماند.
    #
    # فاصله از لبه‌ی حیاط انتخاب شده تا نوارِ بینِ تیغه و راهرو به‌اندازه‌ی
    # یک لاینِ پهن باز بماند.
    blade_ys = [snap(top - 150), snap(bottom + 150)]
    blade_ys = [y for y in blade_ys if 100 < y < world_h - 100]
    blades(blade_ys, snap(world_w * 0.07), left - PLAZA_CLEAR)
    blades(blade_ys, right + PLAZA_CLEAR, snap(world_w * 0.93))

    # --- ۴) میدان‌ها ---
    #
    # این‌ها «اتاق» به معنیِ نقشه‌ی اتاقی نیستند؛ فقط ناحیه‌بندی‌اند برای
    # نقطه‌ی شروعِ تیمی (TeamSpawn سرور دورترین جفت را برمی‌دارد → چپ و
    # راست)، کانون‌های نور و پخشِ موانع.
    #
    # خودِ حیاط عمداً بینشان نیست: آن‌جا جای شیطان است و نه بازیکن باید
    # آن تو ظاهر شود و نه مانعی باید جلوی او را بگیرد.
    rooms = [
        [0, 0, left, world_h],                              # میدانِ غرب (تیم ۱)
        [right, 0, world_w - right, world_h],               # میدانِ شرق (تیم ۲)
        [left, 0, right - left, top],                       # میدانِ شمال
        [left, bottom, right - left, world_h - bottom],     # میدانِ جنوب
    ]

    walls = [w for w in walls if w[2] > 0 and w[3] > 0]
    # نورِ خودِ حیاط: مرکز باید از دور هم پیدا باشد
    plaza_light = [cx, cy, int(max(pw, ph) * 1.15)]
    return walls, doors, rooms, [plaza_light]


# ============================ گرید و اعتبارسنجی ============================

def rasterize(grid: np.ndarray, rects: list) -> None:
    """مستطیل‌ها را داخل گریدِ بیتی پر می‌کند — این همان چیزی است که سرور
    می‌بیند. خانه‌ای که هر بخشی از دیوار رویش بیفتد بسته حساب می‌شود."""
    rows, cols = grid.shape
    for x, y, w, h in rects:
        cx0 = max(0, int(np.floor(x / CELL)))
        cy0 = max(0, int(np.floor(y / CELL)))
        cx1 = min(cols, int(np.ceil((x + w) / CELL)))
        cy1 = min(rows, int(np.ceil((y + h) / CELL)))
        if cx1 > cx0 and cy1 > cy0:
            grid[cy0:cy1, cx0:cx1] = True


def circle_free(grid: np.ndarray, x: float, y: float, r: float) -> bool:
    """آیا دایره‌ای به این شعاع اینجا جا می‌شود؟ همان منطقِ CircleBlocked سرور."""
    rows, cols = grid.shape
    cx0, cx1 = int(np.floor((x - r) / CELL)), int(np.floor((x + r) / CELL))
    cy0, cy1 = int(np.floor((y - r) / CELL)), int(np.floor((y + r) / CELL))
    for cy in range(cy0, cy1 + 1):
        for cx in range(cx0, cx1 + 1):
            if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
                return False          # بیرونِ گرید = بسته (مثل سرور)
            if not grid[cy, cx]:
                continue
            nx = min(max(x, cx * CELL), (cx + 1) * CELL)
            ny = min(max(y, cy * CELL), (cy + 1) * CELL)
            if (x - nx) ** 2 + (y - ny) ** 2 < r * r:
                return False
    return True


def reachable_mask(grid: np.ndarray, start_cell) -> np.ndarray:
    """flood fill روی خانه‌های باز، از یک خانه‌ی شروع."""
    rows, cols = grid.shape
    seen = np.zeros_like(grid)
    q = deque([start_cell])
    seen[start_cell[1], start_cell[0]] = True
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < cols and 0 <= ny < rows and not seen[ny, nx] and not grid[ny, nx]:
                seen[ny, nx] = True
                q.append((nx, ny))
    return seen


def pick_light_zones(grid: np.ndarray, rooms: list, count: int):
    """چند لکه‌ی بزرگِ روشن روی زمینِ تاریک.

    زمین عمداً تاریک است و فقط همین چند کانون نور دارند؛ بقیه‌ی نقشه در
    سایه می‌ماند. کانون‌ها با نمونه‌برداریِ «دورترین نقطه» بینِ مرکزِ اتاق‌ها
    انتخاب می‌شوند تا در یک گوشه جمع نشوند و کلِ زمین چند جزیره‌ی روشن
    داشته باشد.

    شعاع از اندازه‌ی خودِ اتاق می‌آید: اتاقِ بزرگ کانونِ پهن‌تر می‌گیرد.
    """
    cands = []
    for rx, ry, rw, rh in rooms:
        cx, cy = int(rx + rw * 0.5), int(ry + rh * 0.5)
        if not circle_free(grid, cx, cy, 40.0):
            continue
        radius = int(max(230.0, min(430.0, max(rw, rh) * 0.62)))
        cands.append((cx, cy, radius))
    if not cands:
        return []

    chosen = [max(cands, key=lambda c: c[2])]     # از بزرگ‌ترین اتاق شروع کن
    while len(chosen) < min(count, len(cands)):
        best, best_d = None, -1.0
        for c in cands:
            if c in chosen:
                continue
            d = min((c[0] - q[0]) ** 2 + (c[1] - q[1]) ** 2 for q in chosen)
            if d > best_d:
                best, best_d = c, d
        if best is None:
            break
        chosen.append(best)
    return chosen


def pick_spawns(grid: np.ndarray, rooms: list, world_w: int, world_h: int,
                per_room: int = 1):
    """نقاطِ شروع — per_room تا در هر اتاق/میدان.

    برخلاف نسخه‌ی قبل، هر نقطه واقعاً چک می‌شود که دایره‌ی بازیکن آنجا جا
    بشود — با دیوارهای داخلی، مرکزِ هندسیِ اتاق لزوماً آزاد نیست.

    per_room برای نقشه‌هایی است که اتاقِ کم و بزرگ دارند (زمینِ شیطان: فقط
    چهار میدان). با یکی‌درمیان، RespawnSpawn سرور عملاً انتخابی نداشت و
    همه بعد از هر مرگ در همان چند نقطه ظاهر می‌شدند.
    """
    chosen = []
    for rx, ry, rw, rh in rooms:
        # اول مرکز، بعد شبکه‌ای از نقاطِ داخلی به‌عنوان جایگزین. شبکه با
        # per_room بزرگ‌تر ریزتر می‌شود تا واقعاً همان‌قدر نقطه پیدا شود.
        cands = [(rx + rw * 0.5, ry + rh * 0.5)]
        steps = (0.30, 0.70) if per_room <= 1 else (0.22, 0.40, 0.60, 0.78)
        for fx in steps:
            for fy in steps:
                cands.append((rx + rw * fx, ry + rh * fy))
        placed = 0
        for px, py in cands:
            if placed >= per_room:
                break
            p = (int(round(px)), int(round(py)))
            if not circle_free(grid, p[0], p[1], PLAYER_R + 8):
                continue
            if any((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 < 150 ** 2 for q in chosen):
                continue
            chosen.append(p)
            placed += 1
    return chosen


## حداقل فاصله‌ی آزاد بینِ یک مانع و هر چیزِ دیگر، اگر به آن نچسبیده باشد.
## قطرِ بازیکن ~۵۹ است؛ شکافِ باریک‌تر از این نه راه است نه دیوار — فقط جایی
## است که بازیکن با جوی‌استیک تویش گیر می‌کند. پس مانع یا کاملاً به دیوار
## می‌چسبد یا دستِ‌کم این‌قدر از آن فاصله دارد.
LANE = 66
## فاصله‌ی مانع از مرکزِ هر در — جلوی در باید باز بماند
DOOR_CLEAR = 118


## شعاع‌هایی که اتصال با آن‌ها سنجیده می‌شود: حرکتِ سرور (playerRadius=۲۵)،
## مسیریابیِ بات (botClearance=۲۹) و بازیکنِ کلاینت (~۳۰). جیبی که فقط در یکی
## از این‌ها بسته است هم جیب است: باتی که آنجا گیر کند راهی پیدا نمی‌کند.
CSPACE_RADII = (25.0, 29.0, PLAYER_R)


def _disk(r: float) -> np.ndarray:
    """آفست‌هایی که دایره‌ای به شعاعِ r در مرکزِ یک خانه به آن‌ها می‌خورد —
    دقیقاً همان سنجشِ CircleBlocked سرور (فاصله تا مستطیلِ خانه، نه تا مرکزش)."""
    k = int(np.ceil(r / CELL)) + 1
    out = np.zeros((2 * k + 1, 2 * k + 1), dtype=bool)
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            nx = min(max(0.5, dx), dx + 1) - 0.5
            ny = min(max(0.5, dy), dy + 1) - 0.5
            out[dy + k, dx + k] = (nx * nx + ny * ny) * CELL * CELL < r * r
    return out


_DISKS = {r: _disk(r) for r in CSPACE_RADII}


def _cspace(grid: np.ndarray, r: float) -> np.ndarray:
    """فضای پیکربندیِ یک دایره: خانه‌ی آزادِ این گرید یعنی مرکزِ دایره واقعاً
    می‌تواند آنجا باشد. بیرونِ گرید بسته است (مثل سرور)."""
    return ndimage.binary_dilation(grid, structure=_DISKS[r], border_value=1)


def _connected(grid: np.ndarray, must_reach: list) -> bool:
    """برای هر شعاع: همه‌ی نقاطِ must_reach در یک تکه‌اند و آن تکه کلِ فضای
    آزاد است — هیچ جیبِ بسته‌ای پشتِ مانع نمانده. اتصالِ چهارجهته، که از
    هشت‌جهته‌ی A* سخت‌گیرتر است."""
    for r in CSPACE_RADII:
        free = ~_cspace(grid, r)
        labels, n = ndimage.label(free)
        if n != 1:
            return False
        for x, y in must_reach:
            cx, cy = int(x // CELL), int(y // CELL)
            if not (0 <= cy < labels.shape[0] and 0 <= cx < labels.shape[1]):
                return False
            if labels[cy, cx] == 0:
                return False      # خودِ نقطه برای این دایره بسته شده
    return True


def _side_gaps_ok(grid: np.ndarray, cx0: int, cy0: int, cx1: int, cy1: int) -> bool:
    """از هر ضلعِ مانع رو به بیرون نگاه می‌کند: هر ردیف/ستون یا به چیزی چسبیده
    (فاصله‌ی صفر) یا دستِ‌کم LANE باز است. بیرونِ گرید = دیوارِ مرزی."""
    rows, cols = grid.shape
    lane = int(np.ceil(LANE / CELL))

    def gap(cx, cy, dx, dy):
        for d in range(lane):
            x, y = cx + dx * d, cy + dy * d
            if x < 0 or y < 0 or x >= cols or y >= rows or grid[y, x]:
                return d
        return lane

    for cy in range(cy0, cy1):
        for g in (gap(cx0 - 1, cy, -1, 0), gap(cx1, cy, 1, 0)):
            if 0 < g < lane:
                return False
    for cx in range(cx0, cx1):
        for g in (gap(cx, cy0 - 1, 0, -1), gap(cx, cy1, 0, 1)):
            if 0 < g < lane:
                return False
    return True


def _rect_point_dist2(px, py, pw, ph, x, y) -> float:
    nx = min(max(x, px), px + pw)
    ny = min(max(y, py), py + ph)
    return (x - nx) ** 2 + (y - ny) ** 2


def build_obstacles(grid: np.ndarray, rooms: list, doors: list, spec: MapSpec):
    """موانعِ پناه‌گیری — spec.obstacles_per_room (کمینه، بیشینه) در هر اتاق.

    جای موانع با قرعه پیدا می‌شود و هر نامزد پیش از پذیرفته شدن این‌ها را رد
    می‌کند:
      - کاملاً داخلِ اتاق و روی هیچ دیواری نیفتد
      - از هر ضلع یا به دیوار بچسبد یا دستِ‌کم LANE فاصله بدهد
      - جلوی هیچ دری نایستد (DOOR_CLEAR از مرکزِ در)
      - حلقه‌ی ظاهر شدنِ تیمی دورِ مرکزِ اتاق باز بماند: TeamSpawn سرور
        بازیکن‌ها را روی دایره‌ای به شعاعِ ربعِ ضلعِ کوچکِ اتاق می‌چیند
      - بعد از گذاشتنش، بازیکن هنوز از هر اتاق و هر در به همه‌جا برسد

    نصفِ نامزدها «چسبیده به دیوار»اند: در اتاق‌های کوچکِ زمینِ پیش‌فرض
    (۳۸۴×۳۲۰) جای خالیِ کافی برای پنج مانعِ آزاد با راهِ عبور از هر طرف نیست،
    ولی مانعی که پشت به دیوار دارد جیبِ باریک نمی‌سازد و پناهِ خوبی هم هست.

    بذرِ جدا دارد تا چیدمانِ اتاق‌ها و درها با اضافه شدنِ موانع عوض نشود.
    grid را همان‌جا به‌روز می‌کند و فهرستِ موانع را برمی‌گرداند.
    """
    lo_n, hi_n = spec.obstacles_per_room
    if hi_n <= 0:
        return []
    rng = random.Random(spec.seed * 31 + 7)
    lo_s, hi_s = spec.obstacle_size

    door_pts = []
    for d in doors:
        if d["axis"] == "v":
            door_pts.append((float(d["x"]), (d["y0"] + d["y1"]) * 0.5))
        else:
            door_pts.append(((d["x0"] + d["x1"]) * 0.5, float(d["y"])))
    room_centres = [(rx + rw * 0.5, ry + rh * 0.5) for rx, ry, rw, rh in rooms]
    must_reach = door_pts + room_centres

    obstacles = []
    per_room = []
    for rx, ry, rw, rh in rooms:
        cx, cy = rx + rw * 0.5, ry + rh * 0.5
        ring = max(min(rw, rh) * 0.25, 60.0)
        spawn_clear = ring + PLAYER_R + 10
        top = min(hi_s, max(lo_s, min(rw, rh) * 0.22))
        target = rng.randint(lo_n, hi_n)
        placed = 0
        for _attempt in range(600):
            if placed >= target:
                break
            s = snap(rng.uniform(lo_s, top))
            if rng.random() < spec.obstacle_hug:
                # چسبیده به یکی از چهار ضلعِ اتاق: جا به‌جا به سمتِ همان ضلع
                # سُر می‌خورد تا به اولین خانه‌ی بسته (دیوار) بخورد
                side = rng.randrange(4)
                if side in (0, 1):
                    px = snap(rng.uniform(rx, rx + rw - s))
                    py = snap(ry + rh * 0.5 - s * 0.5)
                    step = (0, -CELL) if side == 0 else (0, CELL)
                else:
                    px = snap(rx + rw * 0.5 - s * 0.5)
                    py = snap(rng.uniform(ry, ry + rh - s))
                    step = (-CELL, 0) if side == 2 else (CELL, 0)
                for _ in range(int(max(rw, rh) // CELL)):
                    nx, ny = px + step[0], py + step[1]
                    x0, y0 = nx // CELL, ny // CELL
                    x1, y1 = (nx + s) // CELL, (ny + s) // CELL
                    if x0 < 0 or y0 < 0 or x1 > grid.shape[1] or y1 > grid.shape[0] \
                            or grid[y0:y1, x0:x1].any():
                        break
                    px, py = nx, ny
            else:
                px = snap(rng.uniform(rx, rx + rw - s))
                py = snap(rng.uniform(ry, ry + rh - s))

            if px < rx or py < ry or px + s > rx + rw or py + s > ry + rh:
                continue
            cx0, cy0, cx1, cy1 = px // CELL, py // CELL, (px + s) // CELL, (py + s) // CELL
            if grid[cy0:cy1, cx0:cx1].any():
                continue
            if _rect_point_dist2(px, py, s, s, cx, cy) < spawn_clear ** 2:
                continue
            if any(_rect_point_dist2(px, py, s, s, dx, dy) < DOOR_CLEAR ** 2 for dx, dy in door_pts):
                continue
            if not _side_gaps_ok(grid, cx0, cy0, cx1, cy1):
                continue
            grid[cy0:cy1, cx0:cx1] = True
            if not _connected(grid, must_reach):
                grid[cy0:cy1, cx0:cx1] = False
                continue
            obstacles.append([px, py, s, s])
            placed += 1
        per_room.append(placed)

    print(f"obstacles per room: {per_room}")
    short = [i for i, n in enumerate(per_room) if n < lo_n]
    if short:
        raise SystemExit(f"rooms {short} got fewer than {lo_n} obstacles — relax the spec")
    return obstacles


# ============================ خروجی ============================

def pack_bits(grid: np.ndarray) -> str:
    """بسته‌بندی گرید به بیت (سطر-محور، کم‌ارزش‌ترین بیت اول) و سپس base64."""
    return base64.b64encode(np.packbits(grid.reshape(-1), bitorder="little")).decode()


def save_preview(spec: MapSpec, walls, doors, spawns, world_w, world_h) -> None:
    """PNG کوچکِ چیدمان — فقط برای نگاه کردن، بازی از آن استفاده نمی‌کند."""
    from PIL import ImageDraw
    scale = 0.5
    im = Image.new("RGB", (int(world_w * scale), int(world_h * scale)), (16, 12, 16))
    d = ImageDraw.Draw(im)
    for x, y, w, h in walls:
        d.rectangle([x * scale, y * scale, (x + w) * scale, (y + h) * scale],
                    fill=(214, 170, 74))
    for dr in doors:
        if dr["axis"] == "v":
            d.line([dr["x"] * scale, dr["y0"] * scale, dr["x"] * scale, dr["y1"] * scale],
                   fill=(70, 200, 120), width=3)
        else:
            d.line([dr["x0"] * scale, dr["y"] * scale, dr["x1"] * scale, dr["y"] * scale],
                   fill=(70, 200, 120), width=3)
    for sx, sy in spawns:
        d.ellipse([sx * scale - 5, sy * scale - 5, sx * scale + 5, sy * scale + 5],
                  fill=(240, 80, 80))
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    path = os.path.join(PREVIEW_DIR, f"arena_{spec.key}_preview.png")
    im.save(path)
    print("preview ->", path)


def build_map(spec: MapSpec, world_w: int, world_h: int, preview: bool) -> None:
    """یک زمین را می‌سازد، اعتبارسنجی می‌کند و در دو مسیر می‌نویسد."""
    print(f"\n=== {spec.out_name()} — {spec.title} ===")
    rng = random.Random(spec.seed)
    cols, rows = world_w // CELL, world_h // CELL

    grid = np.zeros((rows, cols), dtype=bool)
    extra_lights: list = []
    if spec.layout == "arena":
        walls, doors, rooms, extra_lights = build_arena_layout(world_w, world_h, rng, spec)
    else:
        walls, doors, rooms = build_rooms(world_w, world_h, rng, spec)
    rasterize(grid, walls)
    obstacles = build_obstacles(grid, rooms, doors, spec)

    lights = pick_light_zones(grid, rooms, spec.light_zones) + extra_lights
    spawns = pick_spawns(grid, rooms, world_w, world_h, spec.spawns_per_room)
    if not spawns:
        raise SystemExit("no valid spawn point found — layout is too tight")

    # --- چکِ اتصال: همه‌ی نقاط شروع باید به هم راه داشته باشند ---
    s0 = spawns[0]
    seen = reachable_mask(grid, (s0[0] // CELL, s0[1] // CELL))
    for p in spawns[1:]:
        if not seen[p[1] // CELL, p[0] // CELL]:
            raise SystemExit(f"spawn {p} is walled off from {s0} — layout is broken")
    open_cells = int((~grid).sum())
    reach = int(seen.sum())
    if reach < open_cells * 0.98:
        raise SystemExit(
            f"only {reach}/{open_cells} open cells reachable — layout has a sealed pocket")

    # --- چکِ عرضِ در ---
    narrow = [d for d in doors if d["width"] < MIN_DOOR]
    if narrow:
        raise SystemExit(f"{len(narrow)} door(s) narrower than {MIN_DOOR}: {narrow[:3]}")

    rects = border_rects(world_w, world_h) + walls + obstacles
    blocked = 100.0 * grid.sum() / grid.size
    widths = sorted({d["width"] for d in doors})
    print(f"grid {cols}x{rows} cell={CELL}  blocked={blocked:.1f}%")
    print(f"rooms={len(rooms)}  interior walls={len(walls)} obstacles={len(obstacles)}  "
          f"doors={len(doors)} widths={widths}")
    print(f"reachable {reach}/{open_cells} open cells  spawns={len(spawns)}")
    print(f"light zones={len(lights)} radii={[r for _, _, r in lights]}")

    data = {
        "version": 3,
        "generated_by": "tools/build_arena.py",
        "map": spec.key,
        "world": {"width": world_w, "height": world_h},
        "grid": {"cell": CELL, "cols": cols, "rows": rows, "bits": pack_bits(grid)},
        "boundary": [[0, 0], [world_w, 0], [world_w, world_h], [0, world_h]],
        "rects": rects,
        # فقط برای کلاینت: درها و کانون‌های نور. سرور این کلیدها را نمی‌خواند
        # (arenaFile در arena.go فقط world/grid/spawns/rooms را decode می‌کند).
        "doors": doors,
        # فقط برای کلاینت: کدام مستطیل‌ها مانع‌اند (با بافتِ مانع کشیده می‌شوند،
        # نه بافتِ دیوار). همین‌ها داخلِ rects و گرید هم هستند.
        "obstacles": obstacles,
        "lights": [[x, y, r] for x, y, r in lights],
        "rooms": rooms,
        "spawns": [list(p) for p in spawns],
    }
    for directory in (RES_DIR, SRV_DIR):
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, spec.out_name())
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, separators=(",", ":"))
        print("wrote", path, os.path.getsize(path), "bytes")

    if preview:
        save_preview(spec, walls + obstacles, doors, spawns, world_w, world_h)


def main():
    args = sys.argv[1:]
    preview = "--preview" in args
    wanted = list(MAPS)
    if "--map" in args:
        i = args.index("--map")
        if i + 1 >= len(args) or args[i + 1] not in MAPS:
            raise SystemExit(f"--map must be one of: {', '.join(MAPS)}")
        wanted = [args[i + 1]]

    world_w, world_h = world_size()
    for key in wanted:
        build_map(MAPS[key], world_w, world_h, preview)

    # پیامِ آخر عمداً ASCII است: کنسولِ ویندوز اینجا cp1252 است و روی نشانه‌ی
    # یونیکد می‌ترکد — و آن هم بعد از نوشتنِ فایل‌ها، پس اسکریپت «موفق ولی
    # خطادار» تمام می‌شد
    print("\nNOTE: rebuild the Go server so the new maps go into its binary:")
    print("   cd gun_game_server && go build")


if __name__ == "__main__":
    main()
