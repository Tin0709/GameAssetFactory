"""Width-only rest-space edit of R11 character instances, in a separate blend."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
BASE=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid')
SOURCE=BASE/'player_weapon_hold_r11_study.blend';DEST=BASE/'player_weapon_hold_r11_slim_arm_study.blend'
OUT=BASE/'slim_arm_width_review';OUT.mkdir(exist_ok=True)
assert Path(bpy.data.filepath)==SOURCE and not bpy.data.is_dirty
assert not DEST.exists(),'Do not overwrite a previous study'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
design=json.loads((BASE/'weapon_hold_r11_review/design.json').read_text())
parts=['UpperArm.R','ForeArm.R','UpperArm.L','ForeArm.L']
def h(x):return hashlib.sha256(repr(x).encode()).hexdigest()
def curves(a):return [c for l in a.layers for s in l.strips for b in s.channelbags for c in b.fcurves]
def action_signature(a):
 return h([(c.data_path,c.array_index,[(list(k.co),list(k.handle_left),list(k.handle_right),k.interpolation,k.handle_left_type,k.handle_right_type) for k in c.keyframe_points],[(m.type,str(m.bl_rna.identifier)) for m in c.modifiers]) for c in curves(a)])
def rig_signature(o):
 return h([(b.name,list(b.head_local),list(b.tail_local),[list(row) for row in b.matrix_local],b.parent.name if b.parent else None,b.use_deform) for b in o.data.bones])
def mesh_signature(o,include_positions=True):
 return h(([list(v.co) for v in o.data.vertices] if include_positions else [],[list(p.vertices) for p in o.data.polygons],[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices],[[list(uv.uv) for uv in l.data] for l in o.data.uv_layers],[s.material.name if s.material else None for s in o.material_slots],[p.material_index for p in o.data.polygons]))
def affected(o):return o.type=='MESH' and o.name.startswith('R11_') and all(o.vertex_groups.get(n) for n in parts)
actors=[o for o in bpy.data.objects if affected(o)]
assert len(actors)==18
protection={'source_file_sha256':source_hash,'actions':{a.name:action_signature(a) for a in bpy.data.actions},'rigs':{o.name:rig_signature(o) for o in bpy.data.objects if o.type=='ARMATURE'},'other_meshes':{o.name:mesh_signature(o) for o in bpy.data.objects if o.type=='MESH' and not affected(o)},'topology_weights_uv_materials':{o.name:mesh_signature(o,False) for o in actors},'object_transforms':{o.name:h((list(o.location),list(o.rotation_euler),list(o.rotation_quaternion),list(o.scale),[list(x) for x in o.matrix_parent_inverse])) for o in bpy.data.objects}}
(OUT/'preservation.json').write_text(json.dumps(protection,indent=2))
def rig_for(m):return next(md.object for md in m.modifiers if md.type=='ARMATURE')
def part_data(m,n):
 r=rig_for(m);idx=m.vertex_groups[n].index;T=r.data.bones[n].matrix_local.inverted()@r.matrix_world.inverted()@m.matrix_world
 vs=[v for v in m.data.vertices if any(g.group==idx and g.weight>.9999 for g in v.groups)]
 pts=[T@v.co for v in vs];lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
 return T,vs,lo,hi
def dimensions(m):
 d={}
 for n in parts:
  T,vs,lo,hi=part_data(m,n);d[n]={'width':hi.x-lo.x,'length':hi.y-lo.y,'depth':hi.z-lo.z,'vertices':len(vs),'bounds':[list(lo),list(hi)]}
 return d
before={m.name:dimensions(m) for m in actors}
for d in before.values():
 for p in d.values():assert abs(p['width']-p['depth'])<1e-6 and abs(p['length']-.3375)<1e-6
# Measure and render using the existing poses, cameras and weapon placements.
shots=[]
show=bpy.data.scenes['R11_SHOWCASE_HOLD'];shots.append((show,show.camera,25,'three_weapon_showcase'))
for cat,d in design['categories'].items():
 s=bpy.data.scenes[d['scene']]
 for view in ['ReferenceAngle','FrontReference','UnderReference']:
  shots.append((s,bpy.data.objects[d['cameras'][view]],25,cat+'_'+view))
def render_shots(tag):
 metadata={}
 for s,c,f,name in shots:
  bpy.context.window.scene=s;s.camera=c;s.frame_set(f);bpy.context.view_layer.update()
  original=(s.render.image_settings.file_format,s.render.image_settings.media_type,s.render.filepath)
  s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=str(OUT/(tag+'_'+name+'.png'))
  deps=bpy.context.evaluated_depsgraph_get()
  metadata[name]={'camera':c.name,'camera_matrix':[list(row) for row in c.evaluated_get(deps).matrix_world],'frame':f,'evaluated_transforms':{o.name:[list(row) for row in o.evaluated_get(deps).matrix_world] for o in s.objects if o.type in ['ARMATURE','MESH','EMPTY']},'bone_matrices':{o.name:{p.name:[list(row) for row in p.matrix] for p in o.pose.bones} for o in s.objects if o.type=='ARMATURE'},'resolution':[s.render.resolution_x,s.render.resolution_y,s.render.resolution_percentage]}
  bpy.ops.render.render(write_still=True)
  s.render.image_settings.media_type=original[1];s.render.image_settings.file_format=original[0];s.render.filepath=original[2]
 return metadata
before_views=render_shots('before')
# Save a separate file before touching vertices. All original files stay unchanged.
bpy.ops.wm.save_as_mainfile(filepath=str(DEST),check_existing=False)
changes={}
for m in actors:
 assert m.data.users==1,'Unexpected shared mesh; isolate before editing'
 original_positions={v.index:v.co.copy() for v in m.data.vertices};changed=set()
 for n in parts:
  T,vs,lo,hi=part_data(m,n);width=hi.x-lo.x;depth=hi.z-lo.z;factor=(depth*3/4)/width;center=(lo.x+hi.x)/2
  inv=T.inverted()
  for v in vs:
   assert v.index not in changed,'Overlapping rigid-part assignment'
   p=T@v.co;p.x=center+(p.x-center)*factor;v.co=inv@p;changed.add(v.index)
  changes.setdefault(m.name,{})[n]={'factor':factor,'target_width':depth*3/4,'rest_width_axis_mesh':list((T.inverted().to_3x3()@Vector((1,0,0))).normalized())}
 m.data.update()
 for v in m.data.vertices:
  if v.index not in changed:assert (v.co-original_positions[v.index]).length==0
 assert len(changed)==32
after={m.name:dimensions(m) for m in actors}
for n,d in after.items():
 for part,p in d.items():
  old=before[n][part]
  assert abs(p['width']-old['depth']*.75)<1e-6
  assert abs(p['length']-old['length'])<1e-6 and abs(p['depth']-old['depth'])<1e-6
after_views=render_shots('after')
assert json.dumps(before_views,sort_keys=True)==json.dumps(after_views,sort_keys=True),'Comparison poses or placement changed'
assert all(action_signature(bpy.data.actions[n])==v for n,v in protection['actions'].items())
assert all(rig_signature(bpy.data.objects[n])==v for n,v in protection['rigs'].items())
assert all(mesh_signature(bpy.data.objects[n])==v for n,v in protection['other_meshes'].items())
assert all(mesh_signature(bpy.data.objects[n],False)==v for n,v in protection['topology_weights_uv_materials'].items())
assert all(h((list(o.location),list(o.rotation_euler),list(o.rotation_quaternion),list(o.scale),[list(x) for x in o.matrix_parent_inverse]))==protection['object_transforms'][o.name] for o in bpy.data.objects)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
report={'source':str(SOURCE),'study':str(DEST),'source_file_unchanged':True,'before':before,'after':after,'adjustments':changes,'width_axis':'Each arm bone local X, transformed through rest matrices into mesh space. Local Y is length; local Z is depth. No posed/global scaling.','full_arm_before_wld_m':[.225,.675,.225],'full_arm_after_wld_m':[.16875,.675,.225],'full_arm_proportions_before':[4,12,4],'full_arm_proportions_after':[3,12,4],'edited_R11_mesh_instances':len(actors),'vertices_changed_per_mesh':32,'shell_note':'R11 arm consists of two rigid cuboids per side, 8 vertices each. Sleeve/skin/terminal hand design is UV-painted on the same cuboids; no separate sleeve shell or oversized hand found. Entire cross-section narrowed consistently.','uv_note':'Existing UV coordinates, material assignments and texture retained; width-only compression preserves the clothing/skin layout. No UV edits needed.','unchanged_actions':len(protection['actions']),'unchanged_rigs':len(protection['rigs']),'unchanged_other_meshes':len(protection['other_meshes']),'topology_weights_uv_materials_unchanged':True,'bones_rest_joint_positions_lengths_unchanged':True,'object_scales_and_transforms_unchanged':True,'comparison_pose_camera_weapon_placement_exactly_equal':True,'comparison_shots':list(before_views),'review_pending':True,'Godot_files_modified':False}
(OUT/'report.json').write_text(json.dumps(report,indent=2));(OUT/'comparison_transforms.json').write_text(json.dumps(before_views,indent=2))
bpy.context.window.scene=show;show.frame_set(25)
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST),check_existing=False)
result={k:report[k] for k in ['study','full_arm_before_wld_m','full_arm_after_wld_m','edited_R11_mesh_instances','source_file_unchanged','comparison_pose_camera_weapon_placement_exactly_equal','unchanged_actions','unchanged_rigs','review_pending']}
