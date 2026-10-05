import bpy,json
from mathutils import Vector
r=bpy.data.objects['Player_Cuboid_Rig']
print('AUDIT='+json.dumps({'file':bpy.data.filepath,'actions':[a.name for a in bpy.data.actions],'bones':{n:{'head':list(r.data.bones[n].head_local),'tail':list(r.data.bones[n].tail_local),'axes':[list(r.data.bones[n].matrix_local.to_3x3().col[i]) for i in range(3)],'mode':r.pose.bones[n].rotation_mode} for n in ['Arm.L','Arm.R','Leg.L','Leg.R']}}))
