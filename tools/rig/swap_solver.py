# -*- coding: utf-8 -*-
"""Solves ArmRoot translation + rotation for a skin whose two arm layers must be
swapped back onto their own shoulders (screen left <-> right).

The mesh is shared by every skin, so nothing here touches geometry: ArmRoot is
translated and rotated, and because every arm vertex is weighted to ArmRoot's
descendants the whole arm moves rigidly."""
import os
import numpy as np
from PIL import Image

BASE = 'assets/player_characters'
AXIS = 501.0
SRC = {'LeftArm': 388.0, 'RightArm': 614.0}
SPREAD = 30.0
SCALE = 0.86
SHIFT = {'LeftArm': SRC['RightArm'] - SRC['LeftArm'] + SPREAD,
         'RightArm': SRC['LeftArm'] - SRC['RightArm'] - SPREAD}
SHOULDER_Y = 410.0
GAP = 34.0
ART_TO_LOCAL = 0.158


def hand_of(skin, part):
    a = np.array(Image.open(os.path.join(BASE, skin, part + '.png')).convert('RGBA'))[:, :, 3] > 16
    ys, xs = np.nonzero(a)
    cut = ys.max() - (ys.max() - ys.min()) * 0.12
    m = ys >= cut
    return float(xs[m].mean()), float(ys[m].mean())


def solve(skin, part, T, target_x):
    """T = art-px translation of the mesh from its current (shifted) place."""
    sx = SRC[part] + SHIFT[part] + T
    hx, hy = hand_of(skin, part)
    r = float(np.hypot(hx - SRC[part], hy - SHOULDER_Y)) * SCALE
    cur = float(np.degrees(np.arctan2(hy - SHOULDER_Y, hx - SRC[part])))
    c = max(-0.999, min(0.999, (target_x - sx) / r))
    theta = float(np.degrees(np.arccos(c)))
    return theta - cur, sx, sx + r * np.cos(np.radians(theta)), SHOULDER_Y + r * np.sin(np.radians(theta))


def swapped(skin, extra_out):
    """LeftArm back to art-left (screen right), RightArm to art-right (screen left)."""
    TL = -SHIFT['LeftArm'] - extra_out
    TR = -SHIFT['RightArm'] + extra_out
    dL, sxL, wxL, wyL = solve(skin, 'LeftArm', TL, AXIS - GAP)
    dR, sxR, wxR, wyR = solve(skin, 'RightArm', TR, AXIS + GAP)
    return dict(outward_px=[TL, TR],
                rot=[round(float(np.radians(dL)), 5), round(float(np.radians(dR)), 5)],
                deg=[round(dL, 2), round(dR, 2)],
                shoulders=[round(sxL), round(sxR)],
                wrists=[(round(wxL), round(wyL)), (round(wxR), round(wyR))])


if __name__ == '__main__':
    print('skin_sniper — arms swapped back to their own shoulders')
    print('%6s  %-18s %-16s %-24s' % ('extra', 'rot L / R (rad)', 'deg L / R', 'wrist L -> R'))
    for d in [0, 20, 40, 60, 80]:
        r = swapped('skin_sniper', d)
        print('%6d  %8.5f %8.5f  %6.2f %6.2f   %s  shoulders=%s  local_off=%.2f' % (
            d, r['rot'][0], r['rot'][1], r['deg'][0], r['deg'][1],
            r['wrists'], r['shoulders'], (SHIFT['LeftArm'] + d) * ART_TO_LOCAL))
