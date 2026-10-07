"""Offline asset/control route checks; does not claim browser interaction QA."""
from pathlib import Path
from html.parser import HTMLParser
import json,subprocess,shutil
OUT=Path(__file__).resolve().parent/'weapon_hold_r10wh2_review'
class Page(HTMLParser):
    def __init__(self):super().__init__();self.ids=set();self.attrs=[];self.scripts=[];self.in_script=False
    def handle_starttag(self,tag,attrs):
        a=dict(attrs);self.attrs.append(a)
        if 'id' in a:self.ids.add(a['id'])
        if tag=='script':self.in_script=True
    def handle_endtag(self,tag):
        if tag=='script':self.in_script=False
    def handle_data(self,data):
        if self.in_script:self.scripts.append(data)
p=Page();p.feed((OUT/'index.html').read_text(encoding='utf-8'));missing=[]
for attr,expected in [('data-angle',{'Front','FrontThreeQuarter','SupportThreeQuarter','Side','Rear'}),('data-version',{'A','B'}),('data-class',{'Pistol','Rifle','Shotgun'}),('data-mode',{'Hold','AimAround','Move','Turn','Sprint'}),('data-show',{'Hold','AimAround'})]:
    assert {a[attr] for a in p.attrs if attr in a}==expected,attr
for a in p.attrs:
    for k in ['src','href','poster']:
        if k in a:
            assert not a[k].startswith(('http:','https:','file:')),a[k]
            if not (OUT/a[k]).is_file():missing.append(a[k])
for cat in ['Pistol','Rifle','Shotgun']:
    for view in ['Front','FrontThreeQuarter','SupportThreeQuarter','Side','Rear']:
        for tag in ['A','B']:
            for mode,f in [('Hold',25),('AimAround',73),('AimAround',217)]:
                name=f'{cat}_{mode}_f{f}_{tag}_{view}.png'
                if not (OUT/name).is_file():missing.append(name)
    for mode in ['Hold','AimAround','Move','Turn','Sprint']:
        for suffix in ['_24fps.mp4','_ordered.jpg']:
            name=cat+'_'+mode+suffix
            if not (OUT/name).is_file():missing.append(name)
for mode in ['Hold','AimAround']:
    name='Showcase_'+mode+'_24fps.mp4'
    if not (OUT/name).is_file():missing.append(name)
# Pure JS syntax compilation is independent of any browser or URL permission.
node=shutil.which('node');syntax=None
if node:
    check=subprocess.run([node,'-e',"let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{new(require('vm').Script)(s);console.log('syntax ok')})"],input='\n'.join(p.scripts),text=True,capture_output=True)
    assert check.returncode==0,check.stderr;syntax=True
result={'passed':not missing,'missing':sorted(set(missing)),'angle_controls':5,'weapon_controls':3,'motion_controls':5,'image_routes_checked':90,'javascript_syntax_checked':syntax,'browser_interaction_tested':False,'browser_limitation':'In-app URL policy blocks file://; native media and local page delivered.'}
(OUT/'page_validation.json').write_text(json.dumps(result,indent=2));assert result['passed'],result;print(json.dumps(result))
