# -*- coding: utf-8 -*-
"""
Fits a recoloured skin onto the shared rig canvas of its base item.

All in-game art shares one canvas so one mesh / one transform fits every skin:
  characters  assets/player_characters/<id>/{Body,Head,LeftArm,RightArm}.png  1024x1024
  weapons     assets/player_weapons/<id>.png                                  1280x640, barrel right

A skin that was drawn at another size/zoom (e.g. 1254x1254, straight arms, or a
vertical weapon) would break the Polygon2D UVs. For every part this finds the
silhouette of the base part and of the skin part, then scales, rotates and moves
the skin part so its silhouette lands on the base one.

Originals are copied to tools/rig/source/<id>/ (ignored by Godot) before the
normalised files are written, and the script always reads from that copy, so it
can be re-run safely.

usage:
  python tools/rig/normalize_skin.py character skin_default_red skin_default
  python tools/rig/normalize_skin.py weapon    ak47_fire        ak47
Writes a JSON report to tools/rig/out/normalize_<id>.json.
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

CHAR_DIR = 'assets/player_characters'
WEAPON_DIR = 'assets/player_weapons'
SOURCE_DIR = 'tools/rig/source'
OUT_DIR = 'tools/rig/out'
PARTS = ['Body', 'Head', 'LeftArm', 'RightArm']
ALPHA = 20


def shape(img):
    """centroid, principal angle (deg), length along / across that axis."""
    a = np.array(img)[:, :, 3] > ALPHA
    ys, xs = np.nonzero(a)
    pts = np.stack([xs, ys], 1).astype(float)
    c = pts.mean(0)
    cov = np.cov((pts - c).T)
    vals, vecs = np.linalg.eigh(cov)
    major = vecs[:, 1]
    ang = float(np.degrees(np.arctan2(major[1], major[0])))
    proj = (pts - c) @ major
    perp = (pts - c) @ vecs[:, 0]
    return {
        'centroid': c.tolist(),
        'angle': ang,
        'length': float(proj.max() - proj.min()),
        'width': float(perp.max() - perp.min()),
        'bbox': [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
    }


def fit(src, ref, canvas, rotate):
    s, r = shape(src), shape(ref)
    rot = 0.0
    if rotate:
        rot = r['angle'] - s['angle']
        rot = (rot + 90.0) % 180.0 - 90.0      # axis has no direction: smallest turn
    if rotate:
        scale = r['length'] / s['length']
    else:
        bw = lambda b: b[2] - b[0]
        bh = lambda b: b[3] - b[1]
        scale = (bw(r['bbox']) / bw(s['bbox']) + bh(r['bbox']) / bh(s['bbox'])) / 2.0

    img = src.resize((max(1, round(src.width * scale)), max(1, round(src.height * scale))),
                     Image.LANCZOS)
    if rot:
        # PIL turns counter-clockwise for positive angles; image y points down
        img = img.rotate(-rot, resample=Image.BICUBIC, expand=True)
    moved = shape(img)
    dx = r['centroid'][0] - moved['centroid'][0]
    dy = r['centroid'][1] - moved['centroid'][1]
    out = Image.new('RGBA', canvas, (0, 0, 0, 0))
    out.alpha_composite(img, (round(dx), round(dy)))
    result = shape(out)
    return out, {'scale': scale, 'rotation_deg': rot, 'offset': [dx, dy],
                 'ref': r['bbox'], 'result': result['bbox']}


def backup(src_path, dst_path):
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    if not os.path.exists(dst_path):
        shutil.copy2(src_path, dst_path)
    return Image.open(dst_path).convert('RGBA')


def ensure_gdignore():
    os.makedirs(SOURCE_DIR, exist_ok=True)
    marker = os.path.join(SOURCE_DIR, '.gdignore')
    if not os.path.exists(marker):
        open(marker, 'w').close()


def character(skin, base):
    report = {}
    for part in PARTS:
        live = os.path.join(CHAR_DIR, skin, part + '.png')
        src = backup(live, os.path.join(SOURCE_DIR, skin, part + '.png'))
        ref = Image.open(os.path.join(CHAR_DIR, base, part + '.png')).convert('RGBA')
        out, info = fit(src, ref, ref.size, rotate=part.endswith('Arm'))
        out.save(live)
        report[part] = info
    return report


def weapon(skin, base):
    live = os.path.join(WEAPON_DIR, skin + '.png')
    src = backup(live, os.path.join(SOURCE_DIR, skin + '.png'))
    ref = Image.open(os.path.join(WEAPON_DIR, base + '.png')).convert('RGBA')
    s, r = shape(src), shape(ref)
    # a vertical weapon is first stood on its side so the axis-fit only has to
    # correct a small angle; which end is the muzzle is decided by comparing
    # the silhouette mass of both halves with the base weapon
    if abs(abs(s['angle']) - 90.0) < 45.0:
        src = src.rotate(90, expand=True)
    if heavy_end(src) != heavy_end(ref):
        src = src.transpose(Image.ROTATE_180)
    out, info = fit(src, ref, ref.size, rotate=True)
    out.save(live)
    return {'weapon': info}


def heavy_end(img):
    """'left' or 'right': which half of the silhouette holds more pixels."""
    a = np.array(img)[:, :, 3] > ALPHA
    ys, xs = np.nonzero(a)
    mid = (xs.min() + xs.max()) / 2.0
    return 'left' if (xs < mid).sum() > (xs >= mid).sum() else 'right'


def main():
    kind, skin, base = sys.argv[1:4]
    ensure_gdignore()
    report = character(skin, base) if kind == 'character' else weapon(skin, base)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, 'normalize_%s.json' % skin)
    json.dump(report, open(path, 'w', encoding='utf-8'), indent=2)
    print('wrote', path)


if __name__ == '__main__':
    main()
