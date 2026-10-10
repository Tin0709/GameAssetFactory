"""Evaluate isolated copies of original source compositions, not Godot playback."""
import bpy,math,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
def run():
    s=bpy.data.scenes['RUN_EXPRESSIVE_REVIEW'];bpy.context.window.scene=s
    result={}
    for tag,P in [('Baseline_Walk',16),('Baseline_Sprint',13),('Test',18)]:
        r=bpy.data.objects['RUN_'+tag+'_Rig'];rows=[]
        for i in range(P*16):
            f=1+i/16;s.frame_set(int(f),subframe=f%1);bpy.context.view_layer.update();vals={}
            for n in ['Leg.R','Leg.L','UpperArm.R','UpperArm.L']:
                p=r.pose.bones[n];v=p.tail-p.head;vals[n]=math.degrees(math.atan2(-v.y,-v.z))
                if n.startswith('UpperArm'):vals[n+'_outward']=math.degrees(math.atan2(abs(v.x),math.hypot(v.y,v.z)))
            vals['head_pitch']=math.degrees(r.pose.bones['Head'].matrix.to_euler().x)
            vals['head_yaw']=math.degrees(r.pose.bones['Head'].matrix.to_euler().z)
            vals['hips_z']=r.pose.bones['Hips'].head.z
            rows.append(vals)
        result[tag]={'ranges':{n:[min(x[n] for x in rows),max(x[n] for x in rows)] for n in rows[0]},'max_leg_split_deg':max(abs(x['Leg.R']-x['Leg.L']) for x in rows),'period_seconds':P/(30 if tag=='Test' else 24),'source_action':r.animation_data.action.name,'nla_actions':[strip.action.name for t in r.animation_data.nla_tracks for strip in t.strips]}
    (OUT/'baseline_metrics.json').write_text(json.dumps(result,indent=2));return result
