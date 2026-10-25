import numpy as np, glob, os
from PIL import Image
BASE='assets/player_characters'
skins=sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(BASE+'/*/'))
def m(s,p): return (np.array(Image.open(os.path.join(BASE,s,p+'.png')).convert('RGBA'))[:,:,3]>16)
for part in ['LeftArm','RightArm','Body']:
    acc=np.zeros((1024,1024),np.int32)
    for s in skins: acc+=m(s,part)
    core = acc >= int(len(skins)*0.7)
    print('=== %s core area=%d'%(part,core.sum()))
    for y in range(384,1000,24):
        row=np.nonzero(core[y])[0]
        if len(row)==0: continue
        print('  y=%4d n=%3d x[%4d,%4d] mid=%6.1f'%(y,len(row),row.min(),row.max(),(row.min()+row.max())/2))
