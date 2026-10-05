import bpy,json
r=bpy.data.objects['Player_Cuboid_Rig']
def curves(a):
 return [c for l in a.layers for s in l.strips for bag in s.channelbags for c in bag.fcurves]
print('INSPECT='+json.dumps(dict(objects=[dict(name=o.name,type=o.type,parent=o.parent.name if o.parent else None,location=list(o.location),rotation=list(o.rotation_euler),scale=list(o.scale),modifiers=[(m.type,getattr(getattr(m,'object',None),'name',None)) for m in o.modifiers]) for o in bpy.data.objects if o==r or o.type=='MESH'],actions=[dict(name=a.name,range=list(a.frame_range),channels=[(c.data_path,c.array_index) for c in curves(a)]) for a in bpy.data.actions if a.name in ['Player_Idle','Player_Run_Blocky_V7_Final']],units=bpy.context.scene.unit_settings.scale_length)))
for p in bpy.ops.export_scene.gltf.get_rna_type().properties:
 if any(x in p.identifier for x in ['animation','frame','sampling','nla','action','armature','skin','yup','selection','deform','extra']):
  print('SETTING',p.identifier,p.default if hasattr(p,'default') else '',[(i.identifier,i.description) for i in p.enum_items] if p.type=='ENUM' else p.description)
