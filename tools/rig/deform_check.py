# -*- coding: utf-8 -*-
"""
Replays the extreme pose of every animation on the CPU with the exact same
skinning maths Godot uses, and reports how much the mesh actually deforms.

The whole point of the rig is that the character keeps ONE form: the numbers
below must stay small (a couple of percent), otherwise arms/torso are shearing.
"""
import json
import numpy as np

rig = json.load(open('tools/rig/out/rig.json', encoding='utf-8'))
K, C = rig['K'], rig['C']
BONES = rig['bones']            # path -> [x, y] relative to parent, player-local


def to_pl(p):
    return np.array([C[0] - K * (p[0] - 512.0), C[1] - K * (p[1] - 512.0)])


def xform(pos=(0, 0), rot=0.0, scale=(1, 1)):
    c, s = np.cos(rot), np.sin(rot)
    m = np.eye(3)
    m[0, 0] = c * scale[0]; m[0, 1] = -s * scale[1]
    m[1, 0] = s * scale[0]; m[1, 1] = c * scale[1]
    m[0, 2] = pos[0]; m[1, 2] = pos[1]
    return m


def parent_of(path):
    return path.rsplit('/', 1)[0] if '/' in path else None


def globals_for(pose):
    """pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}"""
    out = {}
    for path, rest in BONES.items():
        p = pose.get(path, {})
        local = xform(p.get('pos', rest), p.get('rot', 0.0), p.get('scale', (1, 1)))
        par = parent_of(path)
        out[path] = (out[par] @ local) if par in out else local
    return out


REST_G = globals_for({})
SKIN = {p: REST_G[p] for p in BONES}
SKIN_INV = {p: np.linalg.inv(m) for p, m in SKIN.items()}


def deform(points_canvas, weights, pose):
    g = globals_for(pose)
    v = np.column_stack([np.array([to_pl(p) for p in points_canvas]),
                         np.ones(len(points_canvas))])
    acc = np.zeros((len(points_canvas), 2))
    for path, w in weights.items():
        m = g[path] @ SKIN_INV[path]
        acc += np.array(w)[:, None] * (v @ m[:2].T)
    return acc


def rest_pos(points_canvas):
    return np.array([to_pl(p) for p in points_canvas])


# ------------------------------------------------------------ peak poses
HIPS = 'Bone2D'
SPINE = 'Bone2D/Bone2D'
RCLAV = SPINE + '/Bone2D2'
LCLAV = SPINE + '/Bone2D3'
RUP, LUP = RCLAV + '/RArmRoot/RArmUpper', LCLAV + '/LArmRoot/LArmUpper'
RFO, LFO = RUP + '/RForearm', LUP + '/LForearm'
RHA, LHA = RFO + '/RHand', LFO + '/LHand'
hr = BONES[HIPS]

POSES = {
    'idle peak': {
        HIPS: {'pos': (hr[0], hr[1] + 1.1), 'rot': 0.006},
        SPINE: {'rot': -0.009, 'scale': (1.02, 1.025)},
        RCLAV: {'rot': -0.014}, LCLAV: {'rot': 0.014},
        RUP: {'rot': -0.02}, LUP: {'rot': 0.02},
        RFO: {'rot': 0.015}, LFO: {'rot': -0.015},
        RHA: {'rot': -0.009}, LHA: {'rot': 0.009},
    },
    'walk peak': {
        HIPS: {'pos': (hr[0] + 1.6, hr[1] + 0.9), 'rot': 0.035},
        SPINE: {'rot': -0.022, 'scale': (1.012, 0.99)},
        RCLAV: {'rot': -0.03}, LCLAV: {'rot': -0.03},
        RUP: {'rot': -0.018}, LUP: {'rot': -0.018},
        RFO: {'rot': 0.014}, LFO: {'rot': 0.014},
    },
    'shoot peak': {
        HIPS: {'pos': (hr[0], hr[1] + 4.4)},
        SPINE: {'scale': (1.018, 0.985)},
        RUP: {'rot': -0.022}, LUP: {'rot': 0.022},
        RFO: {'rot': -0.03}, LFO: {'rot': 0.03},
        RHA: {'rot': 0.016}, LHA: {'rot': -0.016},
    },
}


def report():
    print('%-10s %-9s %8s %8s %8s' % ('pose', 'part', 'max move', 'edge %', 'area %'))
    for pname, pose in POSES.items():
        for part, d in rig['parts'].items():
            pts = d['points']
            rest = rest_pos(pts)
            new = deform(pts, d['bones'], pose)
            move = np.hypot(*(new - rest).T)
            e_rest, e_new, a_rest, a_new = [], [], [], []
            for t in d['triangles']:
                for i, j in ((0, 1), (1, 2), (2, 0)):
                    e_rest.append(np.hypot(*(rest[t[i]] - rest[t[j]])))
                    e_new.append(np.hypot(*(new[t[i]] - new[t[j]])))
                def area(P):
                    a, b, c = P[t[0]], P[t[1]], P[t[2]]
                    return abs((b[0]-a[0])*(c[1]-a[1]) - (c[0]-a[0])*(b[1]-a[1])) / 2
                a_rest.append(area(rest)); a_new.append(area(new))
            e_rest, e_new = np.array(e_rest), np.array(e_new)
            a_rest, a_new = np.array(a_rest), np.array(a_new)
            ok = a_rest > 1e-6
            print('%-10s %-9s %8.2f %8.2f %8.2f' % (
                pname, part, move.max(),
                100 * np.abs(e_new / np.maximum(e_rest, 1e-9) - 1).max(),
                100 * np.abs(a_new[ok] / a_rest[ok] - 1).max()))
    print('\n(max move is in player-local units; the whole character is ~135 tall)')


if __name__ == '__main__':
    report()
