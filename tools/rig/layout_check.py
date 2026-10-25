# -*- coding: utf-8 -*-
"""Simulates the in-game placement: character canvas -> player-local space,
next to the gun sprite and the collision circle, so the scale can be judged."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw

BASE = 'assets/player_characters'
rig = json.load(open('tools/rig/out/rig.json', encoding='utf-8'))
K = rig['K']
C = rig['C']

VIEW = 360           # player-local units across
PX = 3               # screen px per player-local unit
S = VIEW * PX


def pl2img(x, y):
    return (S / 2 + x * PX, S / 2 + y * PX)


def render(skin):
    img = Image.new('RGBA', (S, S), (26, 28, 32, 255))
    d = ImageDraw.Draw(img)
    # collision circle (radius 58.549)
    r = 58.549 * PX
    d.ellipse([S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r], outline=(70, 90, 120, 255), width=2)
    d.line([0, S / 2, S, S / 2], fill=(60, 60, 70, 255))
    d.line([S / 2, 0, S / 2, S], fill=(60, 60, 70, 255))

    # character: canvas -> player-local, incl. the container's 180 deg rotation
    comp = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    for p in ['Body', 'Head', 'LeftArm', 'RightArm']:
        comp.alpha_composite(Image.open(os.path.join(BASE, skin, p + '.png')).convert('RGBA'))
    comp = comp.rotate(180)
    size = int(1024 * K * PX)
    comp = comp.resize((size, size), Image.LANCZOS)
    cx, cy = pl2img(C[0], C[1])
    img.alpha_composite(comp, (int(cx - size / 2), int(cy - size / 2)))

    # gun: Sprite2D at (4,-30), rotation PI, scale 0.3
    gun = Image.open('assets/gunak47-Fighter.png').convert('RGBA').rotate(180)
    gs = (int(gun.width * 0.3 * PX), int(gun.height * 0.3 * PX))
    gun = gun.resize(gs, Image.LANCZOS)
    gx, gy = pl2img(4, -30)
    img.alpha_composite(gun, (int(gx - gs[0] / 2), int(gy - gs[1] / 2)))

    # bones
    J = rig['joints']
    def j2img(name):
        u, v = J[name]
        return pl2img(C[0] - K * (u - 512), C[1] - K * (v - 512))
    for a, b in [('hips', 'spine'), ('spine', 'RClav'), ('RClav', 'RArmUpper'),
                 ('RArmUpper', 'RForearm'), ('RForearm', 'RHand'), ('RHand', 'RHandTip'),
                 ('spine', 'LClav'), ('LClav', 'LArmUpper'),
                 ('LArmUpper', 'LForearm'), ('LForearm', 'LHand'), ('LHand', 'LHandTip')]:
        d.line([j2img(a), j2img(b)], fill=(255, 0, 255, 200), width=3)
    d.text((10, 10), skin, fill=(255, 255, 255, 255))
    return img


if __name__ == '__main__':
    skins = ['skin_default', 'skin_girl', 'skin_devil']
    out = Image.new('RGB', (S * len(skins), S))
    for i, s in enumerate(skins):
        out.paste(render(s).convert('RGB'), (i * S, 0))
    out = out.resize((out.width // 2, out.height // 2))
    out.save(sys.argv[1])
    print('->', sys.argv[1], out.size)
