import numpy as np, glob, os, json, cv2
from PIL import Image

BASE = 'assets/player_characters'
PARTS = ['Body','Head','LeftArm','RightArm']
skins = sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(BASE+'/*/'))
print('skins:', skins)

def mask(path, thr=16):
    return (np.array(Image.open(path).convert('RGBA'))[:,:,3] > thr)

union = {}
for part in PARTS:
    m = np.zeros((1024,1024), bool)
    for s in skins:
        m |= mask(os.path.join(BASE,s,part+'.png'))
    union[part] = m

os.makedirs('tools/rig/out', exist_ok=True)
np.save('tools/rig/out/union.npy', np.stack([union[p] for p in PARTS]))

for part in PARTS:
    m = union[part]
    ys, xs = np.nonzero(m)
    print('=== %s bbox x[%d,%d] y[%d,%d] area=%d' % (part, xs.min(), xs.max(), ys.min(), ys.max(), m.sum()))
    for y0 in range(ys.min()//48*48, ys.max()+1, 48):
        band = m[y0:y0+48]
        if not band.any(): continue
        bx = np.nonzero(band.any(axis=0))[0]
        print('   y=%4d  x[%4d,%4d] w=%4d  px=%6d' % (y0, bx.min(), bx.max(), bx.max()-bx.min(), band.sum()))
