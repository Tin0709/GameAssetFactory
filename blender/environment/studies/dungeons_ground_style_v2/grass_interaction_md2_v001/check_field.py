"""Focused numerical contracts, independent of Blender drawing."""
import json
import time
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent))
from field import CONTROLS, FieldCache, grid, route, spring_step, target


def check():
    p={k:v[0] for k,v in CONTROLS.items()};start=time.perf_counter();cache=FieldCache(p)
    assert np.isfinite(cache.frames).all()
    assert np.max(np.linalg.norm(cache.frames,axis=-1))<1.
    assert not np.any(cache.frames[:,0]) and not np.any(cache.frames[:,-1])
    assert not np.any(cache.frames[:,:,0]) and not np.any(cache.frames[:,:,-1])
    sample=np.array([[.3,0.],[-.3,0.],[0.,.3],[0.,-.3],[3.,3.]])
    stationary,falloff=target(sample,np.zeros(2),np.zeros(2),.9,1.15)
    assert np.all(np.sum(stationary[:4]*sample[:4],axis=-1)>0.)
    assert not np.any(stationary[-1])
    walking,_=target(sample,np.zeros(2),np.array([1.,0.]),.9,1.15)
    running,_=target(sample,np.zeros(2),np.array([3.,0.]),.9,1.15)
    ratio=float(np.linalg.norm(running[2])/np.linalg.norm(walking[2]));assert ratio>1.5
    # Exact critical recovery has no overshoot, and settles smoothly.
    x=np.ones((1,2));velocity=np.zeros_like(x);trace=[]
    for _ in range(180):
        x,velocity=spring_step(x,velocity,np.zeros_like(x),6.,1/120);trace.append(float(x[0,0]))
    assert min(trace)>0. and all(a>b for a,b in zip(trace,trace[1:]));assert trace[-1]<.002
    # Sampling never advances state: reverse scrubbing / repeated evaluation exact.
    a=cache.sample(7.25).copy();cache.sample(18.);cache.sample(.5)
    assert np.array_equal(a,cache.sample(7.25))
    assert np.max(np.abs(cache.sample(20.)))<.0001
    # Check actual route derivative, standing rest and authored proxy speeds.
    for t in [2.,4.,6.5,7.,9.]:
        pos,vel=route(t);finite=(route(t+.00001)[0]-route(t-.00001)[0])/.00002
        assert np.allclose(vel,finite,atol=.0001)
    assert np.allclose(route(11.)[1],0.) and np.allclose(route(13.)[0],route(11.)[0])
    zero=FieldCache({**p,'Interaction Strength':0.});assert not np.any(zero.frames)
    return {'passed':True,'grid':list(grid().shape),'default_cache_bytes':int(cache.frames.nbytes),
            'run_walk_strength_ratio':ratio,'peak_field_angle_rad':float(np.max(np.linalg.norm(cache.frames,axis=-1))),
            'end_field_residual_rad':float(np.max(np.abs(cache.sample(20.)))),
            'numeric_check_seconds':time.perf_counter()-start}


if __name__=='__main__':print('FIELD_CHECK',json.dumps(check()),flush=True)
