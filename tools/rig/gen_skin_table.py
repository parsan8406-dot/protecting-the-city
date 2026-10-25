# -*- coding: utf-8 -*-
"""Writes the per-skin arm swing table into scripts/CharacterSkin.gd."""
import json
import re

ang = json.load(open('tools/rig/out/arm_angles.json', encoding='utf-8'))
PATH = 'scripts/CharacterSkin.gd'

rows = ',\n'.join('\t"%s": Vector2(%.5f, %.5f),' % (k, v[0], v[1])
                  for k, v in sorted(ang.items())).replace(',,', ',')
block = ('const ARM_SWING := {\n%s\n}\n' % '\n'.join(
    '\t"%s": Vector2(%.5f, %.5f),' % (k, v[0], v[1]) for k, v in sorted(ang.items()))
).replace(',\n}', ',\n}')

src = open(PATH, encoding='utf-8').read()
marker = re.compile(r'const ARM_SWING := \{.*?\n\}\n', re.S)
if marker.search(src):
    src = marker.sub(block, src)
else:
    raise SystemExit('ARM_SWING block not found in ' + PATH)
open(PATH, 'w', encoding='utf-8', newline='\n').write(src)
print('updated', PATH, '(%d skins)' % len(ang))
