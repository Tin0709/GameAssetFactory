"""One-variable elbow-plane experiment in the connected live W3 study.

No Action creation, weapon edits, mesh edits, or persistent constraints.
"""
from living_r9w2_common import *
OUT=BASE/'living_r9w3_review'
s=bpy.data.scenes['R9W3_DIAGNOSIS'];bpy.context.window.scene=s
r=bpy.data.objects['R9W3_Probe_Rig'];w=gun(s)
m=next(o for o in s.objects if o.type=='MESH' and 'Author_Mesh' in o.name)
boxes=boxes_for(r,m,0);inset=boxes_for(r,m,.005)

def orbit_right(pose,gm,angle,fit=False):
    apply_pose(r,pose)
    up=r.pose.bones['UpperArm.R'];fo=r.pose.bones['ForeArm.R']
    target=fo.matrix@Vector((0,.2625,0));shoulder=up.head.copy()
    axis=(target-shoulder).normalized()
    pole=shoulder+Quaternion(axis,math.radians(angle))@(fo.head-shoulder)
    local_target=gm.inverted()@target
    for iteration in range(20 if fit else 1):
        arm(r,'R',gm@local_target,pole,gm.to_3x3()@Vector((1,0,0)))
        if not fit:break
        error=patch_contact(r,gm,'R')['signed_m']-.0008
        if abs(error)<.00002:break
        local_target.x+=max(-.003,min(.003,error))
    return list(local_target)

rows=[]
for frame in [187,191.5,196,73,217]:
    sample(r,s,bpy.data.actions['LongGunAimAround_LeftRight_V2'],frame)
    pose={p.name:p.matrix_basis.copy() for p in r.pose.bones}
    gm=w.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
    for angle in [0,-3,3,-6,6,-9,9,-12,12,-15,15]:
        target=orbit_right(pose,gm,angle)
        rows.append({'frame':frame,'angle':angle,'target':target,
            'stock_full':contact(r,w,'UpperArm.R',boxes,lambda a:a[:,1]<-.05),
            'stock_inset':contact(r,w,'UpperArm.R',inset,lambda a:a[:,1]<-.05),
            'right_surface':patch_contact(r,gm,'R'),
            'right_forearm':contact(r,w,'ForeArm.R',inset),
            'elbow':list(r.pose.bones['ForeArm.R'].head)})
(OUT/'orbit_probe.json').write_text(json.dumps(rows,indent=2))
result={'experiment':'right elbow-plane orbit; fixed grip-center and rifle',
    'at_event':[x for x in rows if x['frame']==191.5]}
