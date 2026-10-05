import bpy,json
r=bpy.data.objects['Player_Cuboid_Rig'];print('AXES='+json.dumps({n:{'head':list(r.data.bones[n].head_local),'tail':list(r.data.bones[n].tail_local),'axes':[list(r.data.bones[n].matrix_local.to_3x3().col[i]) for i in range(3)],'mode':r.pose.bones[n].rotation_mode} for n in ['Neck','Head','Chest']}))
