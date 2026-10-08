import bpy,json,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
SRC=OUT.parents[2]/'characters/player/cuboid/player_combat_strafe_r14_pass2_study.blend'
with bpy.data.libraries.load(str(SRC),link=False) as (a,b):
    b.objects=['R12_Hold_Unarmed_Rig','R11_R12_Hold_Unarmed_R9W1_Author_Mesh']
objects=b.objects
for o in objects:bpy.context.scene.collection.objects.link(o)
r=objects[0];m=objects[1]
data={'rig':r.name,'mesh':m.name,'rig_transform':[list(row) for row in r.matrix_world], 'mesh_transform':[list(row) for row in m.matrix_world], 'parent':m.parent.name if m.parent else None,'bones':{b.name:{'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None} for b in r.data.bones},'mods':[{'name':x.name,'type':x.type,'target':getattr(x,'object',None).name if getattr(x,'object',None) else None} for x in m.modifiers], 'groups':{g.name:len([v for v in m.data.vertices if any(x.group==g.index and x.weight>.999 for x in v.groups)]) for g in m.vertex_groups},'bounds':[[min(v.co[i] for v in m.data.vertices),max(v.co[i] for v in m.data.vertices)] for i in range(3)],'materials':[x.name for x in m.data.materials], 'actions':[x.name for x in bpy.data.actions],'constraints':[(p.name,[c.type for c in p.constraints]) for p in r.pose.bones if p.constraints]}
(OUT/'.validation').mkdir(exist_ok=True)
(OUT/'.validation/source_probe.json').write_text(json.dumps(data,indent=2))
print(json.dumps(data))
