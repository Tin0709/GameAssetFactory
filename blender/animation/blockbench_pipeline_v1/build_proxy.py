"""Generate exact rest proxy input; create/save through Blockbench's own API."""
import json,uuid,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
rig=json.loads((HERE/'rig_inspection.json').read_text())
def uid(n):return str(uuid.uuid5(uuid.NAMESPACE_URL,'gaf-blockbench-v1/'+n))
def bb(v):return [16*v[0],16*v[2],-16*v[1]]
bones=[dict(name=b['name'],uuid=uid(b['name']),parent=b['parent'],origin=bb(b['head']),rotation=[0,0,0],blender_rest=b['matrix'],mode=b['mode'],locked=b['name'].startswith('ForeArm.')) for b in rig['bones']]
cubes=[]
for i,n in enumerate(['Head','Chest','UpperArm.L','UpperArm.R','Leg.L','Leg.R']):
 names=[n,n.replace('UpperArm','ForeArm')] if n.startswith('UpperArm') else [n]
 vs=[bb(v) for v,w in zip(rig['vertices'],rig['weights']) if w[0][0] in names]
 cubes.append(dict(name=n.replace('UpperArm','FullArm'),uuid=uid('cube/'+n),bone=n,**{'from':[min(v[j] for v in vs) for j in range(3)],'to':[max(v[j] for v in vs) for j in range(3)]},origin=next(b['origin'] for b in bones if b['name']==n),color=i))
contract={'schema':'gaf.blockbench.contract.v1','units_per_meter':16,'blender_to_blockbench':[[16,0,0,0],[0,0,16,0],[0,-16,0,0],[0,0,0,1]],'rig_sha256':rig['manifest']['rig_sha256'],'bones':bones,'cubes':cubes,'rest_policy':'Exact Blender rest pose; every pose channel is zero at neutral. Showcase neutral shoulder offsets are intentionally overridden by full-channel Actions.'}
contract['sha256']=hashlib.sha256(json.dumps(contract,sort_keys=True,separators=(',',':')).encode()).hexdigest()
(HERE/'bridge_contract.json').write_text(json.dumps(contract,indent=2))
js='''(()=>{const c=CONTRACT;newProject(Formats.free);Project.name='GAF_Player_Rigid_Proxy_v001';Project.texture_width=16;Project.texture_height=16;
const groups={};for(const b of c.bones){groups[b.name]=new Group({name:b.name,origin:b.origin,rotation:b.rotation,locked:b.locked},b.uuid).addTo(b.parent?groups[b.parent]:'root').init();}
for(const q of c.cubes)new Cube({name:q.name,from:q.from,to:q.to,origin:q.origin,color:q.color},q.uuid).addTo(groups[q.bone]).init();
const specs=[['BB_Neutral_Test_v001',{}],['BB_RightArm_Test_v001',{'UpperArm.R':[-55,0,-12]}],['BB_LeftArm_Test_v001',{'UpperArm.L':[-35,0,18]}],['BB_HeadTurn_Test_v001',{'Head':[0,35,0]}],['BB_Rifle_Ready_Pose_v001',{'UpperArm.R':[-65,-8,-12],'UpperArm.L':[-60,12,24]}]];
for(const [name,pose] of specs){const a=new Animation({name,length:1,loop:'once',snapping:30}).add();for(const [bone,v] of Object.entries(pose)){const ba=a.getBoneAnimator(groups[bone]);for(const t of [0,.5,1])ba.addKeyframe({channel:'rotation',time:t,interpolation:'linear',data_points:[{x:t===0&& !name.includes('Rifle')?0:v[0],y:t===0&&!name.includes('Rifle')?0:v[1],z:t===0&&!name.includes('Rifle')?0:v[2]}]});}}
Modes.options.animate.select();Animation.all[0].select();Timeline.setTime(0);Animator.preview();Canvas.updateAll();return Codecs.project.compile({raw:true});})()'''.replace('CONTRACT',json.dumps(contract))
(HERE/'create_proxy_in_blockbench.js').write_text(js)
print('contract',contract['sha256'],'13 groups, 6 rigid cuboids')
