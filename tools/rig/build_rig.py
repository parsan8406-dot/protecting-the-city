# -*- coding: utf-8 -*-
"""
Rebuilds the Polygon2D "vectors" (mesh + skin weights) and the Skeleton2D of the
player rig from the character art in assets/player_characters/.

Every skin folder ships four 1024x1024 layers registered on the SAME canvas
(Body / Head / LeftArm / RightArm).  We take the UNION of all skins per layer,
so one single mesh contains every character -> all of them share exactly the
same form, and swapping a skin never changes the silhouette or the deformation.

Output: tools/rig/out/rig.json  (consumed by patch_scenes.py)
"""
import os, glob, json
import numpy as np
import cv2
from PIL import Image
from scipy.spatial import Delaunay

BASE = 'assets/player_characters'
CANVAS = 1024
ALPHA_THR = 16
PAD = 3                                          # safety dilation (px)

# ---------------------------------------------------------------- transform
# canvas(u,v) -> player-local:  PL = C - K * (canvas - 512)
# (the container Sprite2D keeps its 180 deg rotation, which is why it negates)
# C.x is picked so the art's own axis of symmetry (AXIS) lands on x = 0.
K = 0.158
AXIS = 501.0
HEAD_SCALE = 0.62
C = (-K * (512.0 - AXIS), 31.5)


def mir(u):
    """Mirror a canvas x across the character's axis."""
    return 2 * AXIS - u


def to_pl(u, v):
    return (C[0] - K * (u - 512.0), C[1] - K * (v - 512.0))


def rel_pl(child, parent):
    a, b = to_pl(*child), to_pl(*parent)
    return (a[0] - b[0], a[1] - b[1])


# ---------------------------------------------------------------- joints (canvas px)
# The art is drawn as seen from the FRONT (LeftArm.png sits on the canvas-left),
# but the game looks at the character from BEHIND. So each arm layer is moved -
# translated, never mirrored, which would flip the hand - to the opposite
# shoulder. That puts the left arm on the player's left, palms facing inwards,
# and the wrists able to meet on the weapon instead of pointing away.
SHOULDER_SRC = {'LeftArm': 388.0, 'RightArm': 614.0}
SHOULDER_SPREAD = 30.0          # extra gap between the shoulders, canvas px per side
ARM_SCALE = 0.86                # arms are drawn oversized; shrunk about the shoulder

# The torso is drawn as a full front view (neck at the top, belt at the bottom),
# and canvas-down is the direction the character faces. Left as-is the belt ends
# up pointing forwards, which reads as a standing figure rather than a top-down
# one. So the body is cut off along an arc that bulges forward at the sternum and
# falls away at the shoulders, then faded out over the last stretch, leaving the
# shoulders and the forearms reading clearly in front of them.
BODY_CUT_Y = 650.0              # how far forward the cut reaches on the axis
BODY_CUT_DEPTH = 96.0           # how much further back it sits at the shoulders
BODY_CUT_W = 235.0              # half-width the depth is measured over
BODY_CUT_FADE = 115.0           # length of the alpha fade behind the cut

# Where the weapon sits today, so it can follow the shortened arms (canvas px is
# derived from these, and the result is written back absolutely -> idempotent).
GUN_Y0 = -30.0
MUZZLE_Y0 = -120.0
GUN_X = 4.0
MUZZLE_X = -4.0
ARM_SHIFT = {'LeftArm': SHOULDER_SRC['RightArm'] - SHOULDER_SRC['LeftArm'] + SHOULDER_SPREAD,
             'RightArm': SHOULDER_SRC['LeftArm'] - SHOULDER_SRC['RightArm'] - SHOULDER_SPREAD}

# Joints as drawn in each layer's own source canvas.
J_SRC = {
    'LArmRoot':  (388, 410),
    'LArmUpper': (382, 470),
    'LForearm':  (376, 645),
    'LHand':     (330, 800),
    'LHandTip':  (300, 890),
}
for _k in ('ArmRoot', 'ArmUpper', 'Forearm', 'Hand', 'HandTip'):
    _u, _v = J_SRC['L' + _k]
    J_SRC['R' + _k] = (mir(_u), _v)

# ArmRoot sits exactly on the shoulder: it is the pivot that swings the whole
# arm so the hands meet in front of the head (per skin, see arm_angles.py).
# Because every arm vertex is weighted to its descendants only, that rotation is
# perfectly rigid - the arm keeps its shape.
J = {
    'hips':  (AXIS, 790),
    'spine': (AXIS, 565),
    'neck':  (AXIS, 580),
    'LClav': (mir(464) + SHOULDER_SPREAD, 470),  # left arm hangs off the canvas-right shoulder
    'RClav': (464 - SHOULDER_SPREAD, 470),
}
for _side, _part in (('L', 'LeftArm'), ('R', 'RightArm')):
    for _k in ('ArmRoot', 'ArmUpper', 'Forearm', 'Hand', 'HandTip'):
        _u, _v = J_SRC[_side + _k]
        J[_side + _k] = (_u + ARM_SHIFT[_part], _v)


# ---------------------------------------------------------------- masks
def skins():
    return sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(BASE + '/*/'))


def body_cut_y(x):
    """Front edge of the torso: furthest forward on the axis, receding sideways."""
    t = (np.asarray(x, np.float64) - AXIS) / BODY_CUT_W
    return BODY_CUT_Y - BODY_CUT_DEPTH * t * t


def body_alpha(pts):
    """1 over the torso, ramping to 0 at the cut so it dissolves instead of
    ending in a hard slice."""
    cut = body_cut_y(pts[:, 0])
    return 1.0 - smoothstep(0.0, 1.0, (pts[:, 1] - (cut - BODY_CUT_FADE)) / BODY_CUT_FADE)


def union_mask(part):
    m = np.zeros((CANVAS, CANVAS), np.uint8)
    for s in skins():
        a = np.array(Image.open(os.path.join(BASE, s, part + '.png')).convert('RGBA'))[:, :, 3]
        m |= (a > ALPHA_THR).astype(np.uint8)
    # close pinholes / thin gaps between the different poses, then pad outwards
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    m = cv2.dilate(m, np.ones((2 * PAD + 1, 2 * PAD + 1), np.uint8))
    return m


# ---------------------------------------------------------------- outline
def outline(mask, target_pts):
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)
    c = cnts[0]
    peri = cv2.arcLength(c, True)
    lo, hi = 0.0005, 0.05
    best = cv2.approxPolyDP(c, 0.002 * peri, True).reshape(-1, 2)
    for _ in range(60):
        mid = (lo + hi) / 2
        ap = cv2.approxPolyDP(c, mid * peri, True).reshape(-1, 2)
        best = ap
        if len(ap) > target_pts:
            lo = mid
        else:
            hi = mid
        if len(ap) == target_pts:
            break
    return densify(best.astype(np.float64), 70.0), cnts


def densify(poly, max_edge):
    """Split long outline edges. Keeps the Delaunay triangulation conforming to
    the boundary (no orphan corners) and gives the skin a smoother falloff."""
    out = []
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        out.append(a)
        d = float(np.hypot(*(b - a)))
        k = int(d // max_edge)
        for s in range(1, k + 1):
            t = s / (k + 1.0)
            out.append(a + (b - a) * t)
    return np.array(out, np.float64)


# ---------------------------------------------------------------- interior grid
def interior(poly, mask, step, margin):
    inside = cv2.erode(mask, np.ones((2 * margin + 1, 2 * margin + 1), np.uint8))
    cpoly = poly.astype(np.float32).reshape(-1, 1, 2)
    x0, y0 = poly.min(axis=0)
    x1, y1 = poly.max(axis=0)
    pts = []
    y = y0 + step / 2
    row = 0
    while y < y1:
        x = x0 + step / 2 + (step / 2 if row % 2 else 0)   # staggered -> nicer triangles
        while x < x1:
            iy, ix = int(round(y)), int(round(x))
            if 0 <= iy < CANVAS and 0 <= ix < CANVAS and inside[iy, ix]:
                if cv2.pointPolygonTest(cpoly, (float(x), float(y)), True) > margin * 0.6:
                    pts.append((x, y))
            x += step
        y += step * 0.87
        row += 1
    return np.array(pts, np.float64).reshape(-1, 2)


# ---------------------------------------------------------------- triangulation
def triangulate(pts, poly):
    tri = Delaunay(pts)
    cpoly = poly.astype(np.float32).reshape(-1, 1, 2)
    keep, rejected = [], []
    for t in tri.simplices:
        a, b, c = pts[t[0]], pts[t[1]], pts[t[2]]
        cen = (a + b + c) / 3.0
        if cv2.pointPolygonTest(cpoly, (float(cen[0]), float(cen[1])), False) < 0:
            continue
        tt = [int(t[0]), int(t[1]), int(t[2])]
        # drop needle triangles: they cause shading / deformation artefacts
        area = abs((b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])) / 2.0
        # a mid-edge sample must stay inside too (guards concave notches)
        ok = area >= 4.0
        if ok:
            for p, q in ((a, b), (b, c), (c, a)):
                m = (p + q) / 2.0
                if cv2.pointPolygonTest(cpoly, (float(m[0]), float(m[1])), False) < -1.0:
                    ok = False
                    break
        (keep if ok else rejected).append(tt)

    # no vertex may be left without a triangle, otherwise the mesh tears open
    # at that corner -- put the least-bad rejected triangle back for each one.
    covered = set(i for t in keep for i in t)
    for v in range(len(pts)):
        if v in covered:
            continue
        cands = [t for t in rejected if v in t]
        if not cands:
            continue
        best = max(cands, key=lambda t: abs(
            (pts[t[1]][0] - pts[t[0]][0]) * (pts[t[2]][1] - pts[t[0]][1]) -
            (pts[t[2]][0] - pts[t[0]][0]) * (pts[t[1]][1] - pts[t[0]][1])))
        keep.append(best)
        covered.update(best)
    return keep


# ---------------------------------------------------------------- weights
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def body_weights(pts):
    """Torso: hips <-> spine blended along the canvas y axis. Deliberately stiff
    so the silhouette never bends out of shape."""
    y = pts[:, 1]
    w_spine = 1.0 - smoothstep(460.0, 700.0, y)
    return {'Bone2D': 1.0 - w_spine, 'Bone2D/Bone2D': w_spine}


def arm_weights(pts, side):
    """Upper arm -> forearm -> hand, blended along canvas y.  Every skin puts its
    shoulder at y~400 and its hand at y~900, so a y parametrisation stays
    anatomically correct for all of them at once."""
    # wide blend bands on purpose: the weight gradient is what shears the mesh,
    # so spreading it keeps every triangle close to its rest shape.
    y = pts[:, 1]
    a = smoothstep(J[side + 'Forearm'][1] - 115, J[side + 'Forearm'][1] + 115, y)  # upper -> fore
    b = smoothstep(J[side + 'Hand'][1] - 100, J[side + 'Hand'][1] + 100, y)        # fore  -> hand
    w_up = 1.0 - a
    w_fo = a * (1.0 - b)
    w_ha = a * b
    base = 'Bone2D/Bone2D/Bone2D%s/%sArmRoot/%sArmUpper' % (
        '2' if side == 'R' else '3', side, side)
    return {
        base: w_up,
        base + '/%sForearm' % side: w_fo,
        base + '/%sForearm/%sHand' % (side, side): w_ha,
    }


# ---------------------------------------------------------------- build
def build_part(part, target_pts, step, margin, wfn, shift=0.0, cut=False, afn=None):
    mask = union_mask(part)
    if cut:
        yy, xx = np.mgrid[0:CANVAS, 0:CANVAS]
        mask[yy > body_cut_y(xx)] = 0
    poly, cnts = outline(mask, target_pts)
    inner = interior(poly, mask, step, margin)
    pts = np.vstack([poly, inner]) if len(inner) else poly
    tris = triangulate(pts, poly)
    used = set(i for t in tris for i in t)
    orphan = [i for i in range(len(pts)) if i not in used]
    w = wfn(pts)
    tot = np.zeros(len(pts))
    for v in w.values():
        tot += v
    for key in w:
        w[key] = np.where(tot > 0, w[key] / np.maximum(tot, 1e-9), 0.0)
    print('  %-9s contours=%d boundary=%3d internal=%3d tris=%3d orphan=%d bbox=%s'
          % (part, len(cnts), len(poly), len(inner), len(tris), len(orphan),
             (int(poly[:, 0].min()), int(poly[:, 0].max()),
              int(poly[:, 1].min()), int(poly[:, 1].max()))))
    if orphan:
        print('     WARNING orphan vertices:', orphan)
    # `uv` samples the layer where it was drawn; `points` is where it is drawn on
    # screen. The two differ by the shoulder swap, which is a pure translation.
    d = {
        'points': [[round(float(p[0]) + shift, 2), round(float(p[1]), 2)] for p in pts],
        'uv': [[round(float(p[0]), 2), round(float(p[1]), 2)] for p in pts],
        'internal_vertex_count': int(len(inner)),
        'triangles': tris,
        'bones': {k: [round(float(x), 6) for x in v] for k, v in w.items()},
    }
    if afn is not None:
        d['alpha'] = [round(float(a), 4) for a in afn(pts)]
    return d


def main():
    print('skins:', len(skins()))
    out = {'K': K, 'C': list(C), 'joints': J, 'parts': {}}
    out['parts']['Body'] = build_part('Body', 34, 78, 12, body_weights,
                                      cut=True, afn=body_alpha)
    out['parts']['LeftArm'] = build_part('LeftArm', 40, 88, 12,
                                         lambda p: arm_weights(p, 'L'), ARM_SHIFT['LeftArm'])
    out['parts']['RightArm'] = build_part('RightArm', 40, 88, 12,
                                          lambda p: arm_weights(p, 'R'), ARM_SHIFT['RightArm'])

    hm = union_mask('Head')
    ys, xs = np.nonzero(hm)
    out['head_bbox'] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]

    # bone rest positions, relative to their parent, in player-local units
    chain = [
        ('Bone2D', 'hips', None),
        ('Bone2D/Bone2D', 'spine', 'hips'),
    ]
    for side, clav in (('R', 'Bone2D2'), ('L', 'Bone2D3')):
        p = 'Bone2D/Bone2D/' + clav
        chain.append((p, side + 'Clav', 'spine'))
        p += '/%sArmRoot' % side
        chain.append((p, side + 'ArmRoot', side + 'Clav'))
        for seg, parent in (('ArmUpper', 'ArmRoot'), ('Forearm', 'ArmUpper'),
                            ('Hand', 'Forearm'), ('HandTip', 'Hand')):
            p += '/%s%s' % (side, seg)
            chain.append((p, side + seg, side + parent))
    bones = {}
    for path, j, parent in chain:
        p = to_pl(*J[j]) if parent is None else rel_pl(J[j], J[parent])
        bones[path] = [round(p[0], 4), round(p[1], 4)]
    out['bones'] = bones

    # head sprite: pivot sits on the neck, texture centre back on the canvas centre
    nx, ny = J['neck']
    # The hair is drawn very large relative to the torso; scaled down about the
    # neck so the head reads in proportion with the body in-game.
    out['head'] = {'position': [nx - 512.0, ny - 512.0], 'offset': [512.0 - nx, 512.0 - ny],
                   'scale': HEAD_SCALE}
    out['container'] = {'position': list(C), 'scale': K}
    out['axis'] = AXIS
    out['arm_scale'] = ARM_SCALE
    out['arm_angles'] = json.load(open('tools/rig/out/arm_angles.json', encoding='utf-8'))

    # The weapon follows the shortened arms so the grip stays inside the fists.
    def pl_y_to_canvas(y):
        return 512.0 + (C[1] - y) / K

    def shrink(y):
        v = 410.0 + (pl_y_to_canvas(y) - 410.0) * ARM_SCALE     # scaled about the shoulder
        return round(C[1] - K * (v - 512.0), 2)

    out['weapon'] = {'gun': [GUN_X, shrink(GUN_Y0)], 'muzzle': [MUZZLE_X, shrink(MUZZLE_Y0)]}

    os.makedirs('tools/rig/out', exist_ok=True)
    with open('tools/rig/out/rig.json', 'w', encoding='utf-8') as f:
        json.dump(out, f)
    print('bones (player-local, relative to parent):')
    for k, v in bones.items():
        print('   %-58s %s' % (k, v))
    print('head', out['head'])
    print('-> tools/rig/out/rig.json')


if __name__ == '__main__':
    main()
