# -*- coding: utf-8 -*-
"""Renders skin_sniper with several shoulder-offset/rotation pairs and scores each
by how cleanly the two arms form a "Λ": the gap between them must grow
monotonically from the wrists down to the shoulders and never go negative
(negative = the two arm layers pass through each other)."""
import os, subprocess, sys
import numpy as np
from PIL import Image

GODOT = r"F:\Files\New folder\Godot_v4.7.1-stable_mono_win64\godot.exe"
PROJ = r"F:\Files\Parsa\Projencts\GameProjects\gun-game"
OUT = os.path.join(PROJ, "tools", "rig", "out")

# (outward px, rotL rad, rotR rad) — from the shoulder-offset solver
# arms swapped back onto their own shoulders (screen left <-> right):
# outward is negative, i.e. -(256 + extra spread).  See swap_solver.py
TRIALS = [
    (-256, -0.19359,  0.18957),
    (-276, -0.24226,  0.23824),
    (-296, -0.29152,  0.28750),
    (-316, -0.34150,  0.33747),
    (-336, -0.39238,  0.38834),
]


def render(skin, trial, path):
    env = dict(os.environ, RIG_SKINS=skin, RIG_REST_ONLY="1", SHOW_GUN="0",
               RIG_CELL="560", RIG_SCALE="3.6", RIG_TINT="1")
    if trial is None:
        env.pop("ARM_TRIAL", None)
    else:
        env["ARM_TRIAL"] = "%g,%g,%g" % trial
    subprocess.run([GODOT, "--path", PROJ, "--script", "res://tools/rig_shot.gd", "--", path],
                   env=env, capture_output=True)


def score(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(int)
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    red = (r > 60) & (r > b + 25) & (r > g + 25)
    blue = (b > 60) & (b > r + 25)
    if red.sum() == 0 or blue.sum() == 0:
        return None
    ys = np.concatenate([np.nonzero(red)[0], np.nonzero(blue)[0]])
    y0, y1 = ys.min(), ys.max()
    # whichever arm sits further left on screen is the "near" one for the gap
    inner, outer = (red, blue) if np.nonzero(red)[1].mean() < np.nonzero(blue)[1].mean() else (blue, red)
    gaps = []
    for f in np.linspace(0.05, 0.95, 13):
        y = int(y0 + (y1 - y0) * f)
        lr, br = np.nonzero(inner[y])[0], np.nonzero(outer[y])[0]
        gaps.append(br.min() - lr.max() if len(lr) and len(br) else np.nan)
    gaps = np.array(gaps, float)
    ok = gaps[~np.isnan(gaps)]
    drops = np.diff(ok)
    return dict(gaps=gaps, min_gap=ok.min(),
                n_negative=int((ok < 0).sum()),
                monotonic=float((drops >= 0).mean()))


def main():
    os.makedirs(OUT, exist_ok=True)
    ref = os.path.join(OUT, "sweep_default.png")
    render("skin_default", None, ref)
    rows = [("default (reference)", score(ref))]
    for t in TRIALS:
        p = os.path.join(OUT, "sweep_sniper_%d.png" % abs(t[0]))
        render("skin_sniper", t, p)
        rows.append(("sniper swap extra=%3dpx" % (-t[0] - 256), score(p)))
    print("%-28s %8s %5s %9s   gaps (wrist -> shoulder)" % ("trial", "min_gap", "neg", "monotonic"))
    for name, s in rows:
        if s is None:
            print("%-28s  <no arms detected>" % name); continue
        print("%-28s %8.0f %5d %8.0f%%   %s" % (
            name, s["min_gap"], s["n_negative"], 100 * s["monotonic"],
            " ".join("%4.0f" % v for v in s["gaps"])))


if __name__ == "__main__":
    main()
