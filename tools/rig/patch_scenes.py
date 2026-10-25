# -*- coding: utf-8 -*-
"""
Writes the rig produced by build_rig.py into the two scenes that own a player
rig (secense/World.tscn -> "Player", secense/player_s.tscn -> "PlayerOther").

It rewrites, in place:
  * the container Sprite2D transform,
  * the Body / LeftArm / RightArm Polygon2D meshes (polygon, uv, polygons,
    bones, internal_vertex_count) and the Head sprite,
  * every Bone2D rest pose of the Skeleton2D,
  * the RESET / idle / walk / shoot animations.

Existing `material` and `texture` references are kept as they are.
"""
import json, os, re, sys

RIG = json.load(open('tools/rig/out/rig.json', encoding='utf-8'))
BONE_ORDER = list(RIG['bones'].keys())

TARGETS = [
    ('secense/player_s.tscn', ''),        # rig lives at the scene root
    ('secense/World.tscn', 'Player/'),    # rig lives under the Player node
]


# ------------------------------------------------------------------ helpers
def fmt(v):
    s = ('%.4f' % float(v)).rstrip('0').rstrip('.')
    return s if s not in ('', '-0') else '0'


def vec2(p):
    return 'Vector2(%s, %s)' % (fmt(p[0]), fmt(p[1]))


def packed_v2(points):
    return 'PackedVector2Array(%s)' % ', '.join(
        '%s, %s' % (fmt(p[0]), fmt(p[1])) for p in points)


def packed_f32(vals):
    return 'PackedFloat32Array(%s)' % ', '.join(fmt(v) for v in vals)


def polygons_str(tris):
    return '[%s]' % ', '.join('PackedInt32Array(%d, %d, %d)' % tuple(t) for t in tris)


def bones_str(bones):
    parts = []
    for path in BONE_ORDER:
        if path in bones:
            parts.append('"%s", %s' % (path, packed_f32(bones[path])))
    return '[%s]' % ', '.join(parts)


# ------------------------------------------------------------------ tscn blocks
def split_blocks(text):
    """Splits a .tscn into [(header_line, body_text)] chunks."""
    lines = text.split('\n')
    blocks, cur = [], ['', []]
    for ln in lines:
        if ln.startswith('[') and ln.rstrip().endswith(']'):
            blocks.append(cur)
            cur = [ln, []]
        else:
            cur[1].append(ln)
    blocks.append(cur)
    return blocks


def join_blocks(blocks):
    out = []
    for head, body in blocks:
        if head:
            out.append(head)
        out.extend(body)
    return '\n'.join(out)


def props(body):
    """Returns {name: raw_value} for `name = value` lines of a block."""
    d = {}
    for ln in body:
        m = re.match(r'^([a-zA-Z_][\w/]*)\s*=\s*(.*)$', ln)
        if m:
            d[m.group(1)] = m.group(2)
    return d


def node_header(name, ntype, parent, extra):
    h = '[node name="%s" type="%s"' % (name, ntype)
    if parent is not None:
        h += ' parent="%s"' % parent
    return h + extra + ']'


# ------------------------------------------------------------------ builders
def build_part_body(part, old):
    p = props(old)
    d = RIG['parts'][part]
    out = []
    if 'material' in p:
        out.append('material = ' + p['material'])
    out.append('position = ' + vec2([-512, -512]))
    if 'texture' in p:
        out.append('texture = ' + p['texture'])
    out.append('skeleton = ' + p.get('skeleton', 'NodePath("../../Body")'))
    out.append('polygon = ' + packed_v2(d['points']))
    out.append('uv = ' + packed_v2(d.get('uv', d['points'])))
    out.append('polygons = ' + polygons_str(d['triangles']))
    if 'alpha' in d:
        # per-vertex alpha: fades the torso out along the cut instead of a hard edge
        out.append('vertex_colors = PackedColorArray(%s)'
                   % ', '.join('1, 1, 1, %s' % fmt(a) for a in d['alpha']))
    out.append('bones = ' + bones_str(d['bones']))
    out.append('internal_vertex_count = %d' % d['internal_vertex_count'])
    out.append('')
    return out


def build_head_body(old):
    p = props(old)
    out = []
    if 'material' in p:
        out.append('material = ' + p['material'])
    out.append('position = ' + vec2(RIG['head']['position']))
    out.append('scale = ' + vec2([RIG['head'].get('scale', 1.0)] * 2))
    out.append('offset = ' + vec2(RIG['head']['offset']))
    if 'texture' in p:
        out.append('texture = ' + p['texture'])
    out.append('')
    return out


def build_container_body(old):
    p = props(old)
    out = []
    if 'material' in p:
        out.append('material = ' + p['material'])
    out.append('position = ' + vec2(RIG['container']['position']))
    out.append('rotation = 3.1415927')
    out.append('scale = ' + vec2([RIG['container']['scale']] * 2))
    out.append('')
    return out


def build_bone_body(path):
    x, y = RIG['bones'][path]
    out = ['position = ' + vec2([x, y])]
    # NOTE: `rest` stays un-rotated on purpose. The difference between rest and
    # the live rotation is exactly the rigid swing applied to the arm.
    if path in ARM_ROT:
        if abs(ARM_ROT[path]) > 1e-6:
            out.append('rotation = ' + fmt(ARM_ROT[path]))
        s = RIG.get('arm_scale', 1.0)
        if abs(s - 1.0) > 1e-6:
            out.append('scale = ' + vec2([s, s]))
    out.append('rest = Transform2D(1, 0, 0, 1, %s, %s)' % (fmt(x), fmt(y)))
    out.append('')
    return out


# ------------------------------------------------------------------ animations
REST = RIG['bones']
HEAD_POS = RIG['head']['position']

HIPS = 'Body/Bone2D'
SPINE = 'Body/Bone2D/Bone2D'
RCLAV = SPINE + '/Bone2D2'
LCLAV = SPINE + '/Bone2D3'
RUP = RCLAV + '/RArmRoot/RArmUpper'
RFO = RUP + '/RForearm'
RHA = RFO + '/RHand'
LUP = LCLAV + '/LArmRoot/LArmUpper'
LFO = LUP + '/LForearm'
LHA = LFO + '/LHand'
HEAD = 'Sprite2D/Head'

hips_rest = REST['Bone2D']


def v2(x, y):
    return 'Vector2(%s, %s)' % (fmt(x), fmt(y))


def track(path, prop, times, values, interp=2):
    return {'path': '%s:%s' % (path, prop), 'times': times,
            'values': values, 'interp': interp}


def anim_reset():
    return ('RESET', 0.001, 0, [
        track(HIPS, 'position', [0], [v2(*hips_rest)], 1),
        track(HIPS, 'rotation', [0], ['0'], 1),
        track(SPINE, 'rotation', [0], ['0'], 1),
        track(SPINE, 'scale', [0], [v2(1, 1)], 1),
        track(RCLAV, 'rotation', [0], ['0'], 1),
        track(LCLAV, 'rotation', [0], ['0'], 1),
        track(RUP, 'rotation', [0], ['0'], 1),
        track(RFO, 'rotation', [0], ['0'], 1),
        track(RHA, 'rotation', [0], ['0'], 1),
        track(LUP, 'rotation', [0], ['0'], 1),
        track(LFO, 'rotation', [0], ['0'], 1),
        track(LHA, 'rotation', [0], ['0'], 1),
        track(HEAD, 'rotation', [0], ['0'], 1),
        track(HEAD, 'position', [0], [v2(*HEAD_POS)], 1),
    ])


def anim_idle():
    """Slow breathing. Everything is mirrored left/right so the silhouette
    stays symmetric and nothing shears out of shape."""
    L = 2.8
    hx, hy = hips_rest
    return ('idle', L, 1, [
        # the whole torso rocks back a hair while breathing in
        track(HIPS, 'position', [0, 1.2, L], [v2(hx, hy), v2(hx, hy + 1.1), v2(hx, hy)]),
        track(HIPS, 'rotation', [0, 0.7, 1.4, 2.1, L], ['0', '0.006', '0', '-0.006', '0']),
        track(SPINE, 'rotation', [0, 0.7, 1.4, 2.1, L], ['0', '-0.009', '0', '0.009', '0']),
        track(SPINE, 'scale', [0, 1.2, L], [v2(1, 1), v2(1.02, 1.025), v2(1, 1)]),
        track(RCLAV, 'rotation', [0, 1.2, L], ['0', '-0.014', '0']),
        track(LCLAV, 'rotation', [0, 1.2, L], ['0', '0.014', '0']),
        track(RUP, 'rotation', [0, 0.95, 1.9, L], ['0', '-0.02', '0.011', '0']),
        track(RFO, 'rotation', [0, 0.95, 1.9, L], ['0', '0.015', '-0.008', '0']),
        track(RHA, 'rotation', [0, 0.95, 1.9, L], ['0', '-0.009', '0.005', '0']),
        track(LUP, 'rotation', [0, 0.95, 1.9, L], ['0', '0.02', '-0.011', '0']),
        track(LFO, 'rotation', [0, 0.95, 1.9, L], ['0', '-0.015', '0.008', '0']),
        track(LHA, 'rotation', [0, 0.95, 1.9, L], ['0', '0.009', '-0.005', '0']),
        track(HEAD, 'rotation', [0, 0.7, 1.4, 2.1, L], ['0', '0.012', '0', '-0.012', '0']),
        track(HEAD, 'position', [0, 1.2, L],
              [v2(*HEAD_POS), v2(HEAD_POS[0], HEAD_POS[1] - 7), v2(*HEAD_POS)]),
    ])


def anim_walk():
    """Two footsteps per loop: the torso rocks side to side, the arms
    counter-rotate just enough to keep the weapon steady."""
    L = 0.62
    hx, hy = hips_rest
    q = L / 4.0
    return ('walk', L, 1, [
        track(HIPS, 'position', [0, q, 2 * q, 3 * q, L],
              [v2(hx, hy), v2(hx + 1.6, hy + 0.9), v2(hx, hy),
               v2(hx - 1.6, hy + 0.9), v2(hx, hy)]),
        track(HIPS, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '0.035', '0', '-0.035', '0']),
        track(SPINE, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '-0.022', '0', '0.022', '0']),
        track(SPINE, 'scale', [0, q, 2 * q, 3 * q, L],
              [v2(1, 1), v2(1.012, 0.99), v2(1, 1), v2(1.012, 0.99), v2(1, 1)]),
        track(RCLAV, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '-0.03', '0', '0.03', '0']),
        track(LCLAV, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '-0.03', '0', '0.03', '0']),
        track(RUP, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '-0.018', '0', '0.018', '0']),
        track(LUP, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '-0.018', '0', '0.018', '0']),
        track(RFO, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '0.014', '0', '-0.014', '0']),
        track(LFO, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '0.014', '0', '-0.014', '0']),
        track(HEAD, 'rotation', [0, q, 2 * q, 3 * q, L],
              ['0', '-0.028', '0', '0.028', '0']),
        track(HEAD, 'position', [0, q, 2 * q, 3 * q, L],
              [v2(*HEAD_POS), v2(HEAD_POS[0] - 9, HEAD_POS[1]), v2(*HEAD_POS),
               v2(HEAD_POS[0] + 9, HEAD_POS[1]), v2(*HEAD_POS)]),
    ])


def anim_shoot():
    """Recoil: the body is shoved backwards for two frames, the elbows splay
    outwards to absorb it, then everything settles back."""
    hx, hy = hips_rest
    return ('shoot', 0.24, 0, [
        # the kick is a rigid shove of the whole torso, not a squash of the mesh
        track(HIPS, 'position', [0, 0.04, 0.12, 0.24],
              [v2(hx, hy), v2(hx, hy + 4.4), v2(hx, hy + 1.2), v2(hx, hy)]),
        track(SPINE, 'scale', [0, 0.04, 0.24],
              [v2(1, 1), v2(1.018, 0.985), v2(1, 1)]),
        track(RUP, 'rotation', [0, 0.04, 0.24], ['0', '-0.022', '0']),
        track(LUP, 'rotation', [0, 0.04, 0.24], ['0', '0.022', '0']),
        track(RFO, 'rotation', [0, 0.05, 0.24], ['0', '-0.03', '0']),
        track(LFO, 'rotation', [0, 0.05, 0.24], ['0', '0.03', '0']),
        track(RHA, 'rotation', [0, 0.05, 0.24], ['0', '0.016', '0']),
        track(LHA, 'rotation', [0, 0.05, 0.24], ['0', '-0.016', '0']),
        track(HEAD, 'position', [0, 0.04, 0.12, 0.24],
              [v2(*HEAD_POS), v2(HEAD_POS[0], HEAD_POS[1] - 26),
               v2(HEAD_POS[0], HEAD_POS[1] - 7), v2(*HEAD_POS)]),
    ])


ANIMS = [anim_reset(), anim_idle(), anim_walk(), anim_shoot()]
ANIM_ID = {'RESET': 'Animation_reset_arm', 'idle': 'Animation_idle_arm',
           'walk': 'Animation_walk_arm', 'shoot': 'Animation_shoot_arm'}


def anim_subresource(name, length, loop, tracks):
    out = ['[sub_resource type="Animation" id="%s"]' % ANIM_ID[name],
           'resource_name = "%s"' % name,
           'length = %s' % fmt(length)]
    if loop:
        out.append('loop_mode = 1')
    for i, t in enumerate(tracks):
        out += [
            'tracks/%d/type = "value"' % i,
            'tracks/%d/imported = false' % i,
            'tracks/%d/enabled = true' % i,
            'tracks/%d/path = NodePath("%s")' % (i, t['path']),
            'tracks/%d/interp = %d' % (i, t['interp']),
            'tracks/%d/loop_wrap = true' % i,
            'tracks/%d/keys = {' % i,
            '"times": PackedFloat32Array(%s),' % ', '.join(fmt(x) for x in t['times']),
            '"transitions": PackedFloat32Array(%s),' % ', '.join('1' for _ in t['times']),
            '"update": 0,',
            '"values": [%s]' % ', '.join(t['values']),
            '}',
        ]
    out.append('')
    return out


def anim_library():
    return ['[sub_resource type="AnimationLibrary" id="AnimationLibrary_arm"]',
            '_data = {',
            ',\n'.join('&"%s": SubResource("%s")' % (n, ANIM_ID[n])
                       for n, _, _, _ in ANIMS),
            '}',
            '']


# ------------------------------------------------------------------ patch
BONE_NODES = [
    ('Bone2D', 'Body', 'Bone2D'),
    ('Bone2D', 'Body/Bone2D', 'Bone2D/Bone2D'),
]
for _side, _clav in (('R', 'Bone2D2'), ('L', 'Bone2D3')):
    _key = 'Bone2D/Bone2D/' + _clav
    BONE_NODES.append((_clav, 'Body/Bone2D/Bone2D', _key))
    for _seg in ('ArmRoot', 'ArmUpper', 'Forearm', 'Hand', 'HandTip'):
        BONE_NODES.append(('%s%s' % (_side, _seg), 'Body/' + _key, _key + '/%s%s' % (_side, _seg)))
        _key += '/%s%s' % (_side, _seg)

# skin_default's own inward swing, so the scene already looks right in the editor
DEFAULT_ARM = RIG['arm_angles'].get('skin_default', [0.0, 0.0])
ARM_ROT = {'Bone2D/Bone2D/Bone2D3/LArmRoot': DEFAULT_ARM[0],
           'Bone2D/Bone2D/Bone2D2/RArmRoot': DEFAULT_ARM[1]}


def patch(path, prefix):
    text = open(path, encoding='utf-8').read()
    blocks = split_blocks(text)

    def find(pred):
        for i, (head, body) in enumerate(blocks):
            if head and pred(head):
                return i
        return -1

    def node(name, parent):
        pat = '[node name="%s" type=' % name
        want = 'parent="%s"' % parent if parent else None
        for i, (head, body) in enumerate(blocks):
            if head and head.startswith(pat):
                if want is None:
                    if 'parent=' not in head:
                        return i
                elif want in head:
                    return i
        return -1

    root = prefix.rstrip('/')            # '' for player_s.tscn, 'Player' for World.tscn
    sprite_parent = root if root else '.'

    # --- container Sprite2D --------------------------------------------------
    i = node('Sprite2D', sprite_parent)
    assert i >= 0, 'container Sprite2D not found in ' + path
    blocks[i][1] = build_container_body(blocks[i][1])

    # --- meshes --------------------------------------------------------------
    part_parent = prefix + 'Sprite2D'
    for part in ('Body', 'LeftArm', 'RightArm'):
        i = node(part, part_parent)
        assert i >= 0, '%s not found in %s' % (part, path)
        blocks[i][1] = build_part_body(part, blocks[i][1])
    i = node('Head', part_parent)
    assert i >= 0, 'Head not found in ' + path
    blocks[i][1] = build_head_body(blocks[i][1])

    # Draw order is the child order: the head has to sit on top of the arms.
    idx = [node(n, part_parent) for n in ('Body', 'Head', 'LeftArm', 'RightArm')]
    assert min(idx) >= 0 and sorted(idx) == list(range(min(idx), min(idx) + 4)), \
        'the four part nodes are not contiguous in ' + path
    by_name = {n: blocks[node(n, part_parent)] for n in ('Body', 'Head', 'LeftArm', 'RightArm')}
    blocks[min(idx):min(idx) + 4] = [by_name[n] for n in ('Body', 'LeftArm', 'RightArm', 'Head')]

    # --- skeleton ------------------------------------------------------------
    # Rebuild the whole bone list: the hierarchy changed (the clavicles now hang
    # off the spine instead of the hips), so nodes have to be re-emitted in order.
    skel = node('Body', sprite_parent)
    assert skel >= 0, 'Skeleton2D not found in ' + path
    old_bone_idx = [i for i, (h, b) in enumerate(blocks)
                    if h and h.startswith('[node name=') and 'type="Bone2D"' in h
                    and ('parent="%sBody' % prefix) in h]
    assert old_bone_idx, 'no Bone2D nodes found in ' + path
    lo, hi = min(old_bone_idx), max(old_bone_idx)
    assert list(range(lo, hi + 1)) == old_bone_idx, 'bone nodes are not contiguous'
    # keep the editor-assigned unique_id of each old bone node
    old_ids = []
    for i in old_bone_idx:
        m = re.search(r'(\sunique_id=\S+?)\]', blocks[i][0])
        old_ids.append(m.group(1) if m else '')
    while len(old_ids) < len(BONE_NODES):
        old_ids.append('')
    new_bones = []
    for (name, parent, key), extra in zip(BONE_NODES, old_ids):
        new_bones.append([node_header(name, 'Bone2D', prefix + parent, extra),
                          build_bone_body(key)])
    blocks[lo:hi + 1] = new_bones

    # --- weapon --------------------------------------------------------------
    # The gun and its muzzle flash ride along with the shortened arms so the grip
    # stays inside the fists. Values are absolute, so re-running is idempotent.
    for name, key in (('gun', 'gun'), ('MuzzleFlash', 'muzzle')):
        i = node(name, sprite_parent)
        if i < 0:
            continue
        body = blocks[i][1]
        want = 'position = ' + vec2(RIG['weapon'][key])
        for n, ln in enumerate(body):
            if ln.startswith('position ='):
                body[n] = want
                break
        else:
            body.insert(0, want)

    # --- animations ----------------------------------------------------------
    anim_blocks = []
    for name, length, loop, tracks in ANIMS:
        lines = anim_subresource(name, length, loop, tracks)
        anim_blocks.append([lines[0], lines[1:]])
    lib = anim_library()
    anim_blocks.append([lib[0], lib[1:]])

    old_anim_idx = [i for i, (h, b) in enumerate(blocks)
                    if h and (h.startswith('[sub_resource type="Animation"')
                              or h.startswith('[sub_resource type="AnimationLibrary"'))]
    assert old_anim_idx, 'no animation sub-resources in ' + path
    lo, hi = min(old_anim_idx), max(old_anim_idx)
    assert list(range(lo, hi + 1)) == old_anim_idx, 'animation sub-resources not contiguous'
    blocks[lo:hi + 1] = anim_blocks

    out = join_blocks(blocks)
    out = re.sub(r'\n{3,}', '\n\n', out)
    open(path, 'w', encoding='utf-8', newline='\n').write(out)
    print('patched', path)


if __name__ == '__main__':
    for p, prefix in TARGETS:
        patch(p, prefix)
