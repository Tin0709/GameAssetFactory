from pathlib import Path
from html.parser import HTMLParser
import re,json,subprocess
OUT=Path('C:/Users/ADMIN/Desktop/GameAssetFactory/blender/characters/player/cuboid/weapon_hold_r11_review')
class Assets(HTMLParser):
    def __init__(self):super().__init__();self.paths=[];self.ids=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if a.get('id'):self.ids.append(a['id'])
        for key in ['src','href']:
            if a.get(key):self.paths.append(a[key])
h=(OUT/'index.html').read_text(encoding='utf-8');a=Assets();a.feed(h)
assert len(a.ids)==len(set(a.ids))
assert all((OUT/p).is_file() for p in a.paths)
for c in ['Pistol','Rifle','Shotgun']:
    for t in ['A','B']:
        for v in ['FrontReference','ReferenceAngle','ReverseTop','UnderReference','FrontThreeQuarter','Front','Side','Overhead']:assert (OUT/f'{c}_{t}_{v}.png').is_file()
for m in ['Hold','Move','AimAround','Sprint','Turn']:assert (OUT/f'{m}_24fps.mp4').is_file()
scripts=re.findall(r'<script>(.*?)</script>',h,re.S);p=OUT/'page_script_check.js';p.write_text('\n'.join(scripts),encoding='utf-8')
r=subprocess.run(['C:/Program Files/nodejs/node.exe','--check',str(p)],capture_output=True,text=True);assert r.returncode==0,r.stderr
report={'passed':True,'static_links':len(a.paths),'AB_routes':48,'motion_routes':5,'javascript_syntax':'passed','browser_interaction':'not run; local file browser access unavailable'}
(OUT/'page_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
