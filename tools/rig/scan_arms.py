# -*- coding: utf-8 -*-
"""Renders every skin through the real CharacterSkin path and reports whether the
two arm layers form a clean arch or pass through each other."""
import os, subprocess
import numpy as np
from PIL import Image

GODOT = r"F:\Files\New folder\Godot_v4.7.1-stable_mono_win64\godot.exe"
PROJ = os.path.abspath(os.path.dirname(__file__) + "/../..")
OUT = os.path.join(PROJ, "tools", "rig", "out")
SKINS = sorted(d for d in os.listdir(os.path.join(PROJ, "assets/player_characters"))
               if os.path.isdir(os.path.join(PROJ, "assets/player_characters", d)))


def score(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(int)
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    red = (r > 60) & (r > b + 25) & (r > g + 25)
    blue = (b > 60) & (b > r + 25)
    if red.sum() < 50 or blue.sum() < 50:
        return None
    ys = np.concatenate([np.nonzero(red)[0], np.nonzero(blue)[0]])
    y0, y1 = ys.min(), ys.max()
    left_is_red = np.nonzero(red)[1].mean() < np.nonzero(blue)[1].mean()
    inner, outer = (red, blue) if left_is_red else (blue, red)
    gaps = []
    for f in np.linspace(0.05, 0.95, 13):
        y = int(y0 + (y1 - y0) * f)
        a, c = np.nonzero(inner[y])[0], np.nonzero(outer[y])[0]
        gaps.append(c.min() - a.max() if len(a) and len(c) else np.nan)
    ok = np.array([v for v in gaps if not np.isnan(v)])
    return dict(order="LeftArm" if left_is_red else "RightArm",
                neg=int((ok < 0).sum()), min_gap=float(ok.min()), gaps=gaps)


def main():
    env = dict(os.environ, RIG_REST_ONLY="1", SHOW_GUN="0", RIG_CELL="560",
               RIG_SCALE="3.6", RIG_TINT="1")
    env.pop("ARM_TRIAL", None)
    print("%-16s %-10s %5s %8s   gaps (wrist -> shoulder)" % ("skin", "screen-L", "neg", "min_gap"))
    for skin in SKINS:
        p = os.path.join(OUT, "scan_%s.png" % skin)
        env["RIG_SKINS"] = skin
        subprocess.run([GODOT, "--path", PROJ, "--script", "res://tools/rig_shot.gd", "--", p],
                       env=env, capture_output=True)
        s = score(p)
        if s is None:
            print("%-16s <no arms detected>" % skin); continue
        flag = "  <-- arms cross" if s["neg"] else ""
        print("%-16s %-10s %5d %8.0f   %s%s" % (
            skin, s["order"], s["neg"], s["min_gap"],
            " ".join("%4.0f" % v for v in s["gaps"]), flag))


if __name__ == "__main__":
    main()
