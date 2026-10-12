"""Render the saved central model and genuine static character pose snapshots."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];SHOW=HERE.parent/'showcase'
sys.path.insert(0,str(SHOW));import gaf_weapon_library as lib
lib.register();bpy.ops.wm.open_mainfile(filepath=str(SHOW/'Weapon_Showcase.blend'));s=bpy.context.scene
s.render.threads_mode='FIXED';s.render.threads=8;s.cycles.samples=32
OUT=HERE/'review';OUT.mkdir(exist_ok=True)
def choose(id,mode,direction):
 s.gaf_weapon_index=next(i for i,e in enumerate(lib.entries(s)) if e['id']==id);s.gaf_fit_mode=mode;lib.activate(s);lib.view(s,direction)
def render(name):
 s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);print('RENDERED',name,flush=True)
for direction,name in [('REFERENCE','shotgun_v2_standalone'),('RIGHT','shotgun_v2_side'),('FRONT','shotgun_v2_muzzle')]:
 choose('shotgun_stylized_v2','STANDALONE',direction);render(name)
for mode,name in [('READY','shotgun_v2_held'),('HOLSTER','shotgun_v2_holster')]:
 choose('shotgun_stylized_v2',mode,'THREE_QUARTER');render(name)
choose('shotgun_stylized_v2','STANDALONE','REFERENCE');entry=lib.entries(s)[s.gaf_weapon_index]
pump=next(o for o in bpy.data.collections[entry['collection']].objects if o.type=='MESH' and 'Shotgun_V2_Pump' in o.name)
pump.location.y-=.055;bpy.context.view_layer.update();lib.view(s,'REFERENCE');render('shotgun_v2_pump_back')
pump.location.y+=.055
fit=json.loads((ROOT/'.validation/weapon_showcase_v2/fit_inspection.json').read_text())['Shotgun'];report={}
def tree(obs,group=None):
 vs=[];fs=[]
 for o in obs:
  if o.type!='MESH':continue
  offset=len(vs);vs.extend(o.matrix_world@v.co for v in o.data.vertices)
  for p in o.data.polygons:
   if group is None or all(v in group for v in p.vertices):fs.append(tuple(offset+i for i in p.vertices))
 return BVHTree.FromPolygons(vs,fs,all_triangles=False)
for mode in ['READY','HOLSTER']:
 report[mode]={}
 for id in ['shotgun_production_r13','shotgun_stylized_v2']:
  choose(id,mode,'THREE_QUARTER');entry=lib.entries(s)[s.gaf_weapon_index]
  weapon=tree(list(bpy.data.collections[entry['collection']].objects));char=list(bpy.data.collections['FIT_Shotgun_'+mode].objects)
  report[mode][id]={g:len(weapon.overlap(tree(char,set(ids)))) for g,ids in fit['group_vertices'].items() if ids}
report['note']='Static triangle-pair diagnostics only; grip contact may be expected. Not penetration depth, gameplay or mobile validation.'
(HERE/'fit_report.json').write_text(json.dumps(report,indent=2));print('FIT_REPORT',json.dumps(report))
