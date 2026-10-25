import re, subprocess, sys, shutil, os
SRC = 'tools/rig/build_rig.py'
base = open(SRC, encoding='utf-8').read()
out_dir = sys.argv[1]
for tag, y in (('A_726', 726.0), ('B_650', 650.0), ('C_575', 575.0)):
    s = re.sub(r'BODY_CUT_Y = [0-9.]+', 'BODY_CUT_Y = %.1f' % y, base)
    open(SRC, 'w', encoding='utf-8', newline='\n').write(s)
    subprocess.run([sys.executable, 'tools/rig/build_rig.py'], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, 'tools/rig/patch_scenes.py'], check=True, stdout=subprocess.DEVNULL)
    shutil.copy('tools/rig/out/rig.json', os.path.join(out_dir, 'rig_%s.json' % tag))
    subprocess.run(['F:/Files/New folder/Godot_v4.7.1-stable_mono_win64/Godot.exe',
                    '--path', os.getcwd(), '--script', 'res://tools/rig_shot.gd', '--',
                    os.path.join(out_dir, 'v_%s.png' % tag)], check=True)
    print('rendered', tag)
open(SRC, 'w', encoding='utf-8', newline='\n').write(base)
