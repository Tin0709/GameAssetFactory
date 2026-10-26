"""New sparse pose curves informed by measured physical motion envelopes.

No game file is read. Values are hand-rounded semantic pose observations and
authored transitions, not recovered joint transforms or copied animation tracks.
Blade directions assume an unproven identity item mount; rigid art omits the
source's weapon shear. Strafe, movement blending and VFX gates are authored.
"""
from math import sin, cos, pi

POSE_WIDTH=17
HIP_Z=14
# yaw, lean, side lean, arm pitch/splay L/R, leg pitch L/R, head yaw/look,
# blade world heading/elevation/roll, hip offset, leg splay L/R; degrees.
def P(y,l,lp,ls,rp,rs,ll,rl,hy,hu,wy,we,wr,side=0):
    return (y,l,side,lp,ls,rp,rs,ll,rl,hy,hu,wy,we,wr,0.,5.,-5.)

READY=P(-15,-5,5,15,-20,-20,10,-10,10,5,-35,-10,-5)
IDLE=[(0,P(-15,0,0,10,-25,-25,10,-10,10,5,-35,-15,-10)),
 (.25,P(-15,0,-5,10,-20,-25,5,-10,10,0,-35,-10,-10)),
 (.5,P(-20,0,-5,10,-25,-25,5,-10,10,-2,-40,-10,-10)),
 (.75,P(-15,2,0,10,-25,-25,5,-10,10,0,-40,-15,-10))]
WALK=[(0,P(0,5,-5,3,-10,-3,-5,0,0,-2,0,-10,-5)),
 (.25,P(-2,0,-30,3,35,-3,25,-30,0,-4,0,35,-5)),
 (.5,P(0,5,-5,3,0,-3,0,-5,0,-2,0,0,-5)),
 (.75,P(2,0,40,3,-30,-3,-30,25,0,-4,3,-30,-5))]
RUN=[(0,P(0,5,-5,12,0,-15,-5,-8,0,0,-5,-25,-25)),
 (.25,P(0,8,-55,10,45,-8,15,-65,0,-4,10,30,-25)),
 (.5,P(0,7,5,12,3,-15,-7,-15,0,0,0,0,-25)),
 (.75,P(0,10,55,5,-45,-15,-65,30,0,-2,-15,-45,-35))]
AIR=[(0,P(0,-25,140,75,155,-20,65,-20,0,-5,0,35,-50)),
 (.25,P(0,-25,160,75,145,-25,55,-20,0,-5,0,40,-50)),
 (.5,P(0,-20,145,80,140,-25,60,-20,0,-10,0,45,-50)),
 (.75,P(0,-25,120,80,150,-20,75,-25,0,-10,0,40,-50))]
TAKE=[(0,P(0,35,-55,25,-50,-25,-20,-15,0,20,0,-10,-15)),
 (.25,P(0,-20,40,60,60,-45,55,-30,0,15,0,20,-35)),
 (.5,P(0,-25,85,75,130,-30,85,-35,0,5,0,45,-50)),
 (.75,P(0,-25,120,75,150,-25,75,-30,0,-5,0,40,-50)),(1,AIR[0][1])]
LAND=[(0,P(0,20,20,25,20,-20,-20,-30,0,-10,0,10,-10)),
 (.25,P(0,20,15,25,-15,-15,-20,-25,0,-20,-15,-10,-10)),
 (.5,P(-10,3,0,15,-25,-20,5,-10,10,0,-30,-10,-5)),(1,IDLE[0][1])]
# Each attack begins in an already prepared pose, as the recovered family does.
A1=[(0,P(-35,-10,105,85,-45,-65,-10,0,0,0,178,-8,-80,side=-15)),
 (.0375/(13/30),P(-35,-10,95,85,-70,-70,-10,0,0,0,173,-2,-80,side=-15)),
 (.1042/(13/30),P(10,-5,130,80,65,-65,-5,5,15,3,278,-5,-95,side=-15)),
 (.1708/(13/30),P(85,0,45,75,85,15,5,-5,20,5,454,-5,-85,side=-10)),
 (1,P(100,10,30,40,75,25,10,-10,20,3,510,-7,-90,side=5))]
A2=[(0,A1[-1][1]),
 (.1292/.4,P(75,5,40,40,75,20,0,-15,25,0,531,-5,-85)),
 (.1958/.4,P(0,-5,60,40,95,-30,-10,-5,25,2,681,15,-85)),
 (.2625/.4,P(-45,0,75,45,60,-80,-15,0,10,0,558,-2,-85)),
 (1,P(-55,-10,90,40,-20,-80,-5,0,0,-2,515,-6,-90))]
A3=[(0,A2[-1][1]),
 (.2792/(20/30),P(-80,-15,100,15,80,70,-10,10,-5,-8,710,-2,-90)),
 (.3458/(20/30),P(-20,25,90,50,80,15,-5,-30,0,-30,729,-4,-75)),
 (.4125/(20/30),P(45,10,-85,85,90,-40,-5,5,10,0,716,2,-90)),
 (1,P(45,10,-100,85,90,-40,-5,5,5,0,725,1,-90))]
# Normalize winding at seams while retaining full authored blade arcs.
def near(value,origin): return origin+((value-origin+180)%360-180)
def recovery(start,mid,blade):
    mid=list(mid);mid[11]=near(blade,start[11])
    end=list(READY);end[11]=near(end[11],mid[11])
    # Result endpoint canonicalization is handled in pose() for exact connection.
    return [(0,start),(.5,tuple(mid)),(1,tuple(end))]
R1=recovery(A1[-1][1],P(0,0,10,30,50,-45,5,-5,0,0,20,25,-80),20)
R2=recovery(A2[-1][1],P(0,0,40,35,-30,-15,5,-10,0,0,-55,-25,-30),-55)
R3=recovery(A3[-1][1],P(15,3,0,40,20,-40,5,-5,5,0,-15,-15,-20),-15)
AIR_ATTACK=[(0,P(-10,-25,160,25,170,-7,50,-40,0,-20,0,75,-90)),
 (.22,P(-10,-25,90,-10,-170,10,45,-40,0,-20,0,90,-90)),
 (.2933,P(-10,0,80,-3,135,10,20,-50,0,-25,0,15,-90)),
 (.3702,P(-5,65,-60,65,25,20,-25,-60,0,-55,0,-45,-90)),(1,READY)]

def _aux(keys,sides,legs):
    result=[]
    for i,(t,values) in enumerate(keys):
        p=list(values);p[2]=sides[i];p[15],p[16]=legs[i];result.append((t,tuple(p)))
    return result
# Quantized physical splay/side-lean observations; no generic invented ±5°
# spread on walk/run. These remain new sparse curves, not source joint tracks.
READY=tuple(list(READY[:2])+[-2]+list(READY[3:15])+[5.,-10.])
IDLE=_aux(IDLE,[-2]*4,[(5,-10)]*4)
WALK=_aux(WALK,[0]*4,[(0,0)]*4)
RUN=_aux(RUN,[0,-3,0,3],[(0,0)]*4)
AIR=_aux(AIR,[3]*4,[(0,0)]*4)
TAKE=_aux(TAKE,[0,0,2,3,3],[(0,0)]*5);TAKE[-1]=(1,AIR[0][1])
LAND=_aux(LAND,[3,2,-1,-2],[(-5,0),(-5,0),(0,-10),(5,-10)]);LAND[-1]=(1,IDLE[0][1])
A1=_aux(A1,[-10,-10,-20,-15,5],[(10,-5),(10,-5),(10,-10),(10,-15),(5,-15)])
A2=_aux(A2,[5,5,5,-5,-5],[(5,-15),(10,-5),(5,-10),(5,-5),(15,-5)]);A2[0]=(0,A1[-1][1])
A3=_aux(A3,[-5,-5,-10,-20,-20],[(15,-5),(15,5),(10,5),(25,-5),(25,-5)]);A3[0]=(0,A2[-1][1])
R1=recovery(A1[-1][1],P(0,0,10,30,50,-45,5,-5,0,0,20,25,-80),20)
R2=recovery(A2[-1][1],P(0,0,40,35,-30,-15,5,-10,0,0,-55,-25,-30),-55)
R3=recovery(A3[-1][1],P(15,3,0,40,20,-40,5,-5,5,0,-15,-15,-20),-15)
for _keys,_sides,_legs in [(R1,[5,0,-2],[(5,-15),(5,-5),(5,-10)]),
                          (R2,[-5,0,-2],[(15,-5),(5,-5),(5,-10)]),
                          (R3,[-20,3,-2],[(25,-5),(5,-5),(5,-10)])]:
    _keys[:]=_aux(_keys,_sides,_legs)
AIR_ATTACK=_aux(AIR_ATTACK,[1,1,3,2,-2],[(5,-5),(5,-10),(5,-15),(15,-25),(5,-10)]);AIR_ATTACK[-1]=(1,READY)

def _clip(duration,loop,category,source=None,window=None):
    row={'duration':duration,'loop':loop,'category':category,'evidence':
         'source duration; authored sparse pose reconstruction' if source else 'authored adapter',
         'source_name':source}
    if window:
        row['vfx_window']=window
        row['vfx_evidence']='authored window around measured fast motion; not native hit/notify'
    return row
CLIPS={
 'Idle':_clip(80/30,True,'locomotion','Player_Master_Idle'),
 'Walk':_clip(26/30,True,'locomotion','Player_Master_Walk'),
 'Run':_clip(13/30,True,'locomotion','Player_Master_Run'),
 'StrafeLeft':_clip(26/30,True,'locomotion'), 'StrafeRight':_clip(26/30,True,'locomotion'),
 'JumpTakeoff':_clip(12/30,False,'jump','Player_Jump'),
 'JumpAirborne':_clip(25/30,True,'jump','Player_Jump_Loop'),
 'JumpLanding':_clip(9/30,False,'jump','Player_Jump_Land'),
 'CombatReady':_clip(80/30,True,'ready'), 'ReadyEnter':_clip(.2,False,'transition'),
 'ReadyExit':_clip(.2,False,'transition'),
 'CombatWalk':_clip(26/30,True,'combat movement','Player_Master_Walk'),
 'CombatRun':_clip(13/30,True,'combat movement','Player_Master_Run'),
 'CombatStrafeLeft':_clip(26/30,True,'combat movement'),
 'CombatStrafeRight':_clip(26/30,True,'combat movement'),
 'Attack1':_clip(13/30,False,'attack','Player_SwordCombo_Attack1',(.055,.185)),
 'Attack2':_clip(12/30,False,'attack','Player_SwordCombo_Attack2',(.125,.285)),
 'Attack3':_clip(20/30,False,'finisher','Player_SwordCombo_Attack3',(.275,.44)),
 'Recovery1':_clip(11/30,False,'recovery','Player_SwordCombo_Attack1Recovery'),
 'Recovery2':_clip(10/30,False,'recovery','Player_SwordCombo_Attack2Recovery'),
 'Recovery3':_clip(20/30,False,'recovery','Player_SwordCombo_Attack3Recovery'),
 'AirAttack':_clip(26/30,False,'optional alternate','Player_1H_Medium_JumpAttack',(.19,.38)),
}

def _interp(keys,p,loop=False):
    if loop:
        p=p%1.
        keys=list(keys)+[(1,keys[0][1])]
    if p<=keys[0][0]:return keys[0][1]
    if p>=keys[-1][0]:return keys[-1][1]
    for i in range(1,len(keys)):
        if p>keys[i][0]:continue
        x0,a=keys[i-1];x1,b=keys[i];u=(p-x0)/(x1-x0)
        # Cubic Hermite, shape-preserving scalar tangents. No stopping at every
        # fast-motion landmark; extrema have zero slope, monotonic spans do not.
        result=[]
        for k in range(POSE_WIDTH):
            slope=(b[k]-a[k])/(x1-x0)
            before=(a[k]-keys[i-2][1][k])/(x0-keys[i-2][0]) if i>1 else slope
            after=(keys[i+1][1][k]-b[k])/(keys[i+1][0]-x1) if i+1<len(keys) else slope
            m0=0 if before*slope<=0 else 2*before*slope/(before+slope)
            m1=0 if after*slope<=0 else 2*after*slope/(after+slope)
            v=(2*u**3-3*u*u+1)*a[k]+(u**3-2*u*u+u)*(x1-x0)*m0+(-2*u**3+3*u*u)*b[k]+(u**3-u*u)*(x1-x0)*m1
            result.append(v)
        return tuple(result)
    raise AssertionError(p)

def _blade_recovery(keys,angles):
    result=[]
    for phase,triplet in zip([0,.25,.5,.75,1],angles):
        row=list(_interp(keys,phase));row[11:14]=triplet;result.append((phase,tuple(row)))
    return result
R1=_blade_recovery(R1,[(510,-7,-90),(470,30,-90),(380,25,-80),(342,5,-40),(325,-10,-5)])
R2=_blade_recovery(R2,[(515,-6,-90),(600,0,-65),(665,-25,-30),(682,-15,-5),(685,-10,-5)])
R3=_blade_recovery(R3,[(725,1,-90),(730,-3,-75),(705,-15,-20),(700,-20,-5),(685,-10,-5)])

def pose(name,time):
    row=CLIPS[name];p=max(0.,min(1.,time/row['duration']))
    if row['loop'] and p>=1:p=0.
    if name.startswith('Recovery') and p>=1:return READY
    keys={'Idle':IDLE,'Walk':WALK,'Run':RUN,'JumpTakeoff':TAKE,'JumpAirborne':AIR,
          'JumpLanding':LAND,'Attack1':A1,'Attack2':A2,'Attack3':A3,
          'Recovery1':R1,'Recovery2':R2,'Recovery3':R3,'AirAttack':AIR_ATTACK}.get(name)
    if keys:return _interp(keys,p,row['loop'])
    if name in ['ReadyEnter','ReadyExit']:
        return _interp([(0,IDLE[0][1]),(1,READY)] if name=='ReadyEnter' else [(0,READY),(1,IDLE[0][1])],p)
    if name=='CombatReady':
        result=list(READY);result[1]+=sin(p*2*pi)*1.5;return tuple(result) if p<1 else READY
    combat=name.startswith('Combat');base='Run' if name=='CombatRun' else 'Walk'
    result=list(_interp(RUN if base=='Run' else WALK,p,True))
    if 'Strafe' in name:
        sign=1 if name.endswith('Left') else -1
        phase=sin(p*2*pi)
        result[7]=result[8]=0
        result[15]=sign*25*phase+5;result[16]=-sign*25*phase-5
        result[2]=sign*3*phase;result[0]=0
    if combat:
        for k in [3,4,5,6,9,10,11,12,13]:result[k]=READY[k]
        result[3]+=sin(p*2*pi)*5
    return tuple(result)
