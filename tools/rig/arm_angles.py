# -*- coding: utf-8 -*-
"""
Each arm layer is moved to the opposite shoulder (see build_rig.ARM_SHIFT), so
the palms face inwards. After that swap the arms already point roughly at the
centre; this works out the small per-skin rotation that brings both wrists
together on the weapon, in front of the head.

The angle is applied to the ArmRoot bone, which sits on the shoulder, so it is a
rigid swing: the arm keeps its exact shape.
"""
import glob
import json
import os

import numpy as np
from PIL import Image

BASE = 'assets/player_characters'
AXIS = 501.0                      # the art's own axis of symmetry
SRC_SHOULDER = {'LeftArm': 388.0, 'RightArm': 614.0}
SPREAD = 30.0                     # must match build_rig.SHOULDER_SPREAD
ARM_SCALE = 0.86                  # must match build_rig.ARM_SCALE
SHIFT = {'LeftArm': SRC_SHOULDER['RightArm'] - SRC_SHOULDER['LeftArm'] + SPREAD,
         'RightArm': SRC_SHOULDER['LeftArm'] - SRC_SHOULDER['RightArm'] - SPREAD}
SHOULDER_Y = 410.0
GAP = 34.0                        # half the distance between the two wrists
TARGET_X = {'LeftArm': AXIS + GAP, 'RightArm': AXIS - GAP}
MAX_DEG = 30.0


def skins():
    return sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(BASE + '/*/'))


def hand_of(skin, part):
    """Centroid of the wrist/hand end of the arm, in placed (shifted) coords."""
    a = np.array(Image.open(os.path.join(BASE, skin, part + '.png')).convert('RGBA'))[:, :, 3] > 16
    ys, xs = np.nonzero(a)
    cut = ys.max() - (ys.max() - ys.min()) * 0.12
    m = ys >= cut
    return float(xs[m].mean()) + SHIFT[part], float(ys[m].mean())


def solve(part, skin):
    sx = SRC_SHOULDER[part] + SHIFT[part]
    sy = SHOULDER_Y
    hx, hy = hand_of(skin, part)
    r = float(np.hypot(hx - sx, hy - sy)) * ARM_SCALE   # arm is shrunk about the shoulder
    cur = float(np.degrees(np.arctan2(hy - sy, hx - sx)))
    c = (TARGET_X[part] - sx) / r
    c = max(-0.95, min(0.95, c))
    tgt = float(np.degrees(np.arccos(c)))          # arccos -> [0,180], sin > 0 = forwards
    d = max(-MAX_DEG, min(MAX_DEG, tgt - cur))
    nx = sx + r * np.cos(np.radians(cur + d))
    ny = sy + r * np.sin(np.radians(cur + d))
    return d, (hx, hy), (nx, ny)


def main():
    table = {}
    print('%-16s %7s %7s   %-21s %-21s' % ('skin', 'L deg', 'R deg', 'L wrist -> new', 'R wrist -> new'))
    for s in skins():
        dl, hl, nl = solve('LeftArm', s)
        dr, hr, nr = solve('RightArm', s)
        table[s] = [round(float(np.radians(dl)), 5), round(float(np.radians(dr)), 5)]
        print('%-16s %7.2f %7.2f   (%5.0f,%4.0f)->(%5.0f,%4.0f) (%5.0f,%4.0f)->(%5.0f,%4.0f)  wrist gap=%4.0f'
              % (s, dl, dr, hl[0], hl[1], nl[0], nl[1], hr[0], hr[1], nr[0], nr[1], nl[0] - nr[0]))
    os.makedirs('tools/rig/out', exist_ok=True)
    json.dump(table, open('tools/rig/out/arm_angles.json', 'w'), indent=1)
    print('\n-> tools/rig/out/arm_angles.json')


if __name__ == '__main__':
    main()
