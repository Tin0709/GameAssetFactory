"""Original, deterministic shared spring-field proof for Blender review.

No bpy dependency: one fixed-step field, not physics/scripts on individual grass.
Numerical parameters are authored, not measurements of Minecraft Dungeons II.
"""
import math
import numpy as np

NAME = 'MD2_Grass_Interaction_v001'
SIZE = (64, 48)
BOUNDS = (-5., 5., -4., 4.)
SOLVER_HZ = 120
CACHE_HZ = 60
CONTROLS = {
    'Player Interaction On/Off': (True, None, None, 'Off gives the unchanged Wind result.'),
    'Interaction Radius': (.90, .45, 1.6, 'World-space influence radius in metres.'),
    'Interaction Strength': (1.15, 0., 1.8, 'Bounded push strength; zero gives unchanged Wind.'),
    'Bending Response': (18., 8., 36., 'Contact response rate, per second.'),
    'Recovery Speed': (6., 2.5, 12., 'Critically damped recovery rate, per second.'),
    'Walk/Run Preview Speed': (1., .5, 1.5, 'Proxy route speed multiplier; does not change Wind speed.'),
}
TIMES = np.array([0., 1.5, 4.5, 5.1, 6., 7.8, 8.4, 10.5, 13.5, 16., 18., 20.])
POINTS = np.array([[-7.,-4.],[-3.2,-1.7],[2.7,-1.7],[3.2,-1.4],[2.8,1.],[-2.8,1.],[-2.7,.5],[0.,0.],[0.,0.],[4.,2.5],[7.,5.],[7.,5.]])
TANGENTS = np.zeros_like(POINTS)
for _i in range(1,len(TIMES)-1):
    if np.linalg.norm(POINTS[_i]-POINTS[_i-1]) > 1e-8 and np.linalg.norm(POINTS[_i+1]-POINTS[_i]) > 1e-8:
        TANGENTS[_i] = (POINTS[_i+1]-POINTS[_i-1])/(TIMES[_i+1]-TIMES[_i-1])


def route(seconds, speed=1.):
    """Hermite proxy route: position and true derivative in world metres/second."""
    t = float(np.clip(seconds*speed, 0., TIMES[-1]))
    i = min(int(np.searchsorted(TIMES,t,side='right'))-1,len(TIMES)-2)
    i = max(0,i); duration = TIMES[i+1]-TIMES[i]; u = (t-TIMES[i])/duration
    a,b = POINTS[i:i+2]; va,vb = TANGENTS[i:i+2]
    p = (2*u**3-3*u**2+1)*a + (u**3-2*u**2+u)*duration*va + (-2*u**3+3*u**2)*b + (u**3-u**2)*duration*vb
    v = ((6*u*u-6*u)*a + (3*u*u-4*u+1)*duration*va + (-6*u*u+6*u)*b + (3*u*u-2*u)*duration*vb)/duration*speed
    return p,v


def phase(seconds, speed=1.):
    t = seconds*speed
    if t < 5.1: return 'WALK / SHORT GRASS'
    if t < 8.4: return 'RUN / TALL GRASS'
    if t < 10.5: return 'DENSE PATCH'
    if t < 13.5: return 'STANDING / CONTACT'
    if t < 18.: return 'LEAVING / RECOVERY'
    return 'RECOVERY / WIND CONTINUES'


def grid():
    w,h = SIZE; xmin,xmax,ymin,ymax = BOUNDS
    xs = xmin+(np.arange(w)+.5)*(xmax-xmin)/w
    ys = ymin+(np.arange(h)+.5)*(ymax-ymin)/h
    return np.stack(np.meshgrid(xs,ys),axis=-1).astype(np.float32)


def target(points, position, velocity, radius, strength):
    delta = points-position
    distance = np.linalg.norm(delta,axis=-1)
    radial = delta/np.maximum(distance[...,None],1e-6)
    moving = float(np.linalg.norm(velocity))
    direction = velocity/max(moving,1e-6)
    # Forward influence avoids a sudden 180deg flip as a moving body passes a
    # root; radial influence still bends side tufts away. Standing is radial.
    push = .70*radial + .85*(moving/(moving+.4))*direction
    norm = np.linalg.norm(push,axis=-1,keepdims=True)
    push = np.where(norm>1e-6,push/np.maximum(norm,1e-6),np.array([0.,-1.]))
    q = np.clip(1.-distance/radius,0.,1.)
    falloff = q*q*(3.-2.*q)
    amplitude = min(.95,strength*(.30+.20*moving))
    return (push*(amplitude*falloff[...,None])).astype(np.float32),falloff.astype(np.float32)


def spring_step(displacement, velocity, desired, omega, dt):
    """Closed-form critically damped step to a locally constant target."""
    err = displacement-desired
    temporary = (velocity+omega*err)*dt
    decay = np.exp(-omega*dt)
    return desired+(err+temporary)*decay,(velocity-omega*temporary)*decay


class FieldCache:
    def __init__(self, params):
        self.params = dict(params); speed = float(params['Walk/Run Preview Speed'])
        self.duration = 20./speed
        points = grid(); shape = points.shape
        x = np.zeros(shape,dtype=np.float32); v = np.zeros_like(x)
        steps = math.ceil(self.duration*SOLVER_HZ)
        frames = [x.copy()]; distance = [0.]; travelled = 0.; previous = route(0.,speed)[0]
        for step in range(1,steps+1):
            t = step/SOLVER_HZ; pos,vel = route(t,speed)
            desired,falloff = target(points,pos,vel,float(params['Interaction Radius']),float(params['Interaction Strength']))
            omega = float(params['Recovery Speed'])+(float(params['Bending Response'])-float(params['Recovery Speed']))*falloff
            x,v = spring_step(x,v,desired,omega[...,None],1./SOLVER_HZ)
            x[0]=0.;x[-1]=0.;x[:,0]=0.;x[:,-1]=0.
            v[0]=0.;v[-1]=0.;v[:,0]=0.;v[:,-1]=0.
            travelled += float(np.linalg.norm(pos-previous)); previous=pos
            if step % (SOLVER_HZ//CACHE_HZ)==0:
                frames.append(x.astype(np.float32).copy()); distance.append(travelled)
        self.frames = np.stack(frames); self.distance = np.array(distance)
        self.frames[np.abs(self.frames)<1e-7] = 0.

    def sample(self, seconds):
        u = min(max(seconds,0.)*CACHE_HZ,len(self.frames)-1)
        a = min(int(u),len(self.frames)-1); b = min(a+1,len(self.frames)-1); f=u-a
        return self.frames[a]*(1.-f)+self.frames[b]*f

    def travelled(self, seconds):
        u = min(max(seconds,0.)*CACHE_HZ,len(self.distance)-1)
        a=int(u);b=min(a+1,len(self.distance)-1)
        return float(self.distance[a]*(1-u+a)+self.distance[b]*(u-a))

    def rgba(self, seconds):
        values = self.sample(seconds)
        result = np.empty((*values.shape[:2],4),dtype=np.float32)
        result[...,:2] = .5 + .5*values
        result[...,2] = .5;result[...,3] = 1.
        return result
