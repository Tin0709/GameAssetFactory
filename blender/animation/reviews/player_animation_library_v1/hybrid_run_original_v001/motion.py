"""Independently authored normalized-phase motion. No reference data loading."""
import math
HZ=1.888
SPEED=7.
FRAMES=32
FPS=60
FPS_BASE=FPS/(FRAMES*HZ)
ORIGIN=.25
DUTY=.16  # Original short rolling-contact windows, NOT native MD2 masks.
VARIANTS=[('V1_Subtle_Bounce',.025,4.,30.,.6),('V2_Balanced_Bounce',.045,7.,38.,1.),('V3_Expressive_Bounce',.065,10.,46.,1.5)]
def smooth(t):return t*t*(3-2*t)
def bounce(p):
    x=(p*2)%1
    keys=[(0.,-1.),(.12,-.65),(.32,1.),(.50,.60),(.78,-.35),(1.,-1.)]
    for (a,y),(b,z) in zip(keys,keys[1:]):
        if a<=x<=b:return y+(z-y)*smooth((x-a)/(b-a))
def hermite(a,b,va,vb,t,length):
    return (2*t**3-3*t*t+1)*a+(t**3-2*t*t+t)*length*va+(-2*t**3+3*t*t)*b+(t**3-t*t)*length*vb
def leg(p,L=.675,d=.1125):
    q=(p+.5)%1-.5
    c=-d if q>=0 else d
    R=math.hypot(L,d)
    if abs(q)<=DUTY/2:
        theta=math.asin((SPEED/HZ*q+c)/R)-math.atan2(c,L)
        return theta,0.,True,c
    edge=math.asin((SPEED/HZ*DUTY/2-d)/R)+math.atan2(d,L)
    derivative=(SPEED/HZ)/(R*math.cos(edge-math.atan2(d,L)))*(1-DUTY)
    s=((p-DUTY/2)%1)/(1-DUTY)
    keys=[(0.,edge,derivative),(.15,math.radians(52),0.),(.60,math.radians(-56),0.),(1.,-edge,derivative)]
    for (a,x,dx),(b,y,dy) in zip(keys,keys[1:]):
        if a<=s<=b:
            theta=hermite(x,y,dx,dy,(s-a)/(b-a),b-a);break
    return theta,.09*math.sin(math.pi*s)**4,False,0.

def verify():
    for i in range(1,160):
        q=-DUTY/2+DUTY*i/160
        theta,clearance,plant,c=leg(q%1)
        assert plant and abs(.675*math.sin(theta)+c*math.cos(theta)-(SPEED/HZ*q+c))<1e-9
    for variant in VARIANTS:
        a=variant[1];values=[a*.5*bounce(i/10000) for i in range(10000)]
        assert abs(max(values)-min(values)-a)<1e-7
    assert abs(FPS/FPS_BASE/FRAMES-HZ)<1e-12
    return {'contact_equations':159,'variants':3,'hz':HZ,'fps_base':FPS_BASE}
if __name__=='__main__':print(verify())
