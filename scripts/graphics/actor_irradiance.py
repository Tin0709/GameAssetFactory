"""Original low-frequency actor field from GAF map, not native MD2/Lumen.
Six cosine-integrated directions share each set of traced incident rays.
"""
from pathlib import Path
import argparse,json,time
import numpy as np
from .terrain_irradiance import Scene,sphere
AXES=np.array([[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]],float)

def occupied(scene,p):
    c=np.floor((p-scene.offset)*scene.scale).astype(int)
    inside=np.all((c>=scene.low)&(c<scene.high),axis=1)
    valid=np.zeros(len(c),bool);valid[inside]=scene.grid[tuple((c[inside]-scene.low).T)]>=0
    return valid

def integrate_volume_points(scene,points,rays,sun_direction,sky_mean):
    points=np.asarray(points,float);dirs=sphere(rays);sun=np.asarray(sun_direction,float);sun/=np.linalg.norm(sun)
    if points.ndim!=2 or points.shape[1]!=3 or not np.isfinite(points).all()or occupied(scene,points).any():raise ValueError('Empty finite receivers required')
    mean=np.asarray(sky_mean,float)
    incident=mean*(1+dirs[:,1,None]*[.15,.25,.45]+.18*(dirs[:,0,None]*.616-dirs[:,2,None]*.788))
    weight=np.maximum(AXES@dirs.T,0)*(4/rays)
    outputs={'sky':[],'sun':[]}
    for start in range(0,len(points),64):
        p=points[start:start+64];n=len(p);origins=np.repeat(p,rays,axis=0);direction=np.tile(dirs,(n,1))
        hit,normal=scene.trace(origins,direction);mask=hit>=0;visible=(~mask).reshape(n,rays)
        sky=np.einsum('ar,nr,rc->nac',weight,visible,incident)
        visibility=np.clip(visible@weight.T,0,1)
        color=np.zeros((len(hit),3));color[mask]=scene.colors[hit[mask]]
        top=mask&(normal[:,1]>0);color[top]=scene.top_colors[hit[top]]
        blocked=(~visible)[:,None,:]*weight[None,:,:]
        avg=np.einsum('nar,nrc->nac',blocked,color.reshape(n,rays,3))/np.maximum(blocked.sum(2)[:,:,None],1e-9)
        sky/=np.maximum(1-avg*(1-visibility[:,:,None]),.05)
        bounce=np.zeros_like(color);lit=mask&(normal@sun>0)
        if lit.any():
            axis=abs(normal[lit]).argmax(1);plane=(scene.cells[hit[lit]]+(normal[lit]>0))/scene.scale+scene.offset
            distance=(plane[np.arange(len(axis)),axis]-origins[lit][np.arange(len(axis)),axis])/direction[lit][np.arange(len(axis)),axis]
            location=origins[lit]+direction[lit]*distance[:,None]+normal[lit]*.01
            shadow,_=scene.trace(location,np.broadcast_to(sun,location.shape))
            bounce[lit]=color[lit]*np.maximum(normal[lit]@sun,0)[:,None]*(shadow<0)[:,None]
        outputs['sky'].append(sky);outputs['sun'].append(np.einsum('ar,nrc->nac',weight,bounce.reshape(n,rays,3)))
    return {k:np.concatenate(v)for k,v in outputs.items()}

def bake(source,out,rays=128):
    source=Path(source);out=Path(out)
    m=json.loads((source/'metadata.json').read_text())
    if not m.get('ambient_recipe_identity'):raise ValueError('Refresh original scene export: ambient recipe identity missing')
    out.mkdir();scene=Scene(m['occupied'],m['offset'],m['side_colors'],m['top_colors'])
    low=scene.low/scene.scale+scene.offset;high=scene.high/scene.scale+scene.offset
    origin=np.floor(low/[4,2,4])*[4,2,4]+.25
    extent=np.ceil((high-origin)/[4,2,4]).astype(int)+2
    # One layer above the highest terrain supports normal jumps; outside volume falls back.
    extent[1]+=2
    ijk=np.indices(extent).reshape(3,-1).T;p=origin+ijk*[4,2,4];valid=~occupied(scene,p)
    started=time.monotonic();print('ACTOR_PROBE_BAKE',len(p),'grid probes;',valid.sum(),'empty',flush=True)
    result=integrate_volume_points(scene,p[valid],rays,m['sun_direction'],m['sky_mean'])
    for key in ['sky','sun']:
        a=np.zeros((len(p),6,3),np.float32);a[valid]=result[key];a.tofile(out/(key+'.bin'))
    valid.astype('uint8').tofile(out/'valid.bin')
    for key in ['occupied','side_colors','top_colors','rows','count']:m.pop(key,None)
    m.update(scope='Original GAF actor incident field; not MD2 radiance',origin=origin.tolist(),step=[4.,2.,4.],dimensions=extent.tolist(),probe_count=len(p),rays=rays,seconds=time.monotonic()-started)
    (out/'metadata.json').write_text(json.dumps(m,indent=2));print('BAKE_READY',m['seconds'],flush=True)
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--source',required=True);a.add_argument('--output',required=True);a.add_argument('--rays',type=int,default=128);v=a.parse_args();bake(v.source,v.output,v.rays)
