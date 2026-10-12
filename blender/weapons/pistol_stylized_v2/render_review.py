"""Actual saved-showcase pixels and static pose fit diagnostics."""
import bpy,sys,json
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
for direction,name in [('REFERENCE','pistol_v2_standalone'),('RIGHT','pistol_v2_side'),('FRONT','pistol_v2_muzzle')]:
 choose('pistol_stylized_v2','STANDALONE',direction);render(name)
for mode,direction,name in [('READY','THREE_QUARTER','pistol_v2_held'),('HOLSTER','THREE_QUARTER','pistol_v2_holster')]:
 choose('pistol_stylized_v2',mode,direction);render(name)
 # Closer fit detail, retaining the genuine weapon/character transforms and pose.
 e=lib.entries(s)[s.gaf_weapon_index];center,dims=lib.bounds(list(bpy.data.collections[e['collection']].objects))
 cam=s.camera;offset=cam.location-(center);rotation=cam.rotation_euler.copy()
 cam.location=center+rotation.to_matrix()@Vector((0,0,2));cam.rotation_euler=rotation
 cam.data.ortho_scale=.63 if mode=='READY' else .57
 render(name+'_detail')
choose('pistol_stylized_v2','STANDALONE','REFERENCE')
e=lib.entries(s)[s.gaf_weapon_index];slide=next(o for o in bpy.data.collections[e['collection']].objects if o.type=='MESH' and 'Pistol_V2_Slide' in o.name)
mag=next(o for o in bpy.data.collections[e['collection']].objects if o.type=='MESH' and 'Pistol_V2_Magazine' in o.name)
slide.location.y-=.018;mag.location+=Vector((0,-.035,-.11));bpy.context.view_layer.update();lib.view(s,'REFERENCE');render('pistol_v2_parts_review')
fit=json.loads((ROOT/'.validation/weapon_showcase_v2/fit_inspection.json').read_text())['Pistol'];report={}
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
 for id in ['pistol_production_r13','pistol_stylized_v2']:
  choose(id,mode,'THREE_QUARTER');entry=lib.entries(s)[s.gaf_weapon_index]
  weapon=tree(list(bpy.data.collections[entry['collection']].objects));char=list(bpy.data.collections['FIT_Pistol_'+mode].objects)
  report[mode][id]={group:len(weapon.overlap(tree(char,fit['group_vertices'][group]))) for group in fit['group_vertices']}
report['note']='Triangle-pair diagnostics in two static existing poses; grip contact is expected. No gameplay, transitions, recoil or mobile certification.'
(HERE/'fit_report.json').write_text(json.dumps(report,indent=2));print('FIT_REPORT',json.dumps(report))
