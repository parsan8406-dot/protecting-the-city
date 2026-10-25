# -*- coding: utf-8 -*-
"""Renders a check sheet: the generated mesh + bones drawn on top of real skins."""
import json, os, sys
import numpy as np
import cv2
from PIL import Image

BASE = 'assets/player_characters'
rig = json.load(open('tools/rig/out/rig.json', encoding='utf-8'))
PARTS = ['Body', 'LeftArm', 'RightArm']
COL = {'Body': (0, 200, 255), 'LeftArm': (0, 255, 120), 'RightArm': (255, 120, 0)}

# canvas coords for every joint, so we can draw the skeleton on the art
J = rig['joints']
CHAIN = [('hips', 'spine'), ('spine', 'RClav'), ('RClav', 'RArmUpper'),
         ('RArmUpper', 'RForearm'), ('RForearm', 'RHand'), ('RHand', 'RHandTip'),
         ('spine', 'LClav'), ('LClav', 'LArmUpper'),
         ('LArmUpper', 'LForearm'), ('LForearm', 'LHand'), ('LHand', 'LHandTip')]


def sheet(skin_list, path, weights_of=None):
    tiles = []
    for skin in skin_list:
        img = np.zeros((1024, 1024, 4), np.uint8)
        comp = Image.new('RGBA', (1024, 1024), (24, 24, 28, 255))
        for p in ['Body', 'Head', 'LeftArm', 'RightArm']:
            comp.alpha_composite(Image.open(os.path.join(BASE, skin, p + '.png')).convert('RGBA'))
        img = np.array(comp)[:, :, :3][:, :, ::-1].copy()

        for part in PARTS:
            d = rig['parts'][part]
            pts = np.array(d['points'])
            if weights_of and part in weights_of[0]:
                bone = weights_of[1]
                w = np.array(d['bones'][bone])
                for (x, y), wv in zip(pts, w):
                    c = (0, int(255 * wv), int(255 * (1 - wv)))
                    cv2.circle(img, (int(x), int(y)), 6, c, -1)
            for t in d['triangles']:
                a, b, c = pts[t[0]], pts[t[1]], pts[t[2]]
                for p, q in ((a, b), (b, c), (c, a)):
                    cv2.line(img, (int(p[0]), int(p[1])), (int(q[0]), int(q[1])), COL[part], 1)
            nb = len(pts) - d['internal_vertex_count']
            for x, y in pts[:nb]:
                cv2.circle(img, (int(x), int(y)), 4, (255, 255, 255), -1)

        for a, b in CHAIN:
            cv2.line(img, tuple(J[a]), tuple(J[b]), (255, 0, 255), 5)
        for k, v in J.items():
            cv2.circle(img, tuple(v), 9, (255, 255, 0), -1)
        cv2.putText(img, skin, (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3)
        tiles.append(img)
    out = np.hstack(tiles)
    h = 620
    out = cv2.resize(out, (int(out.shape[1] * h / out.shape[0]), h))
    cv2.imwrite(path, out)
    print('->', path, out.shape)


if __name__ == '__main__':
    dest = sys.argv[1]
    sheet(['skin_default', 'skin_devil', 'skin_engineer', 'skin_roman'], dest)
