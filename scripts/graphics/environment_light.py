"""Original GGX quadrature and original GAF-map light visibility. No MD2 data.
The split-sum consumer is standard microfacet math; this is not a native LUT dump.
"""
from pathlib import Path
import argparse,json,numpy as np
from .terrain_irradiance import Scene
from .actor_irradiance import occupied

def ggx_brdf(nv,roughness,samples=1024):
    nv=np.asarray(nv,float).reshape(-1,1)
    if np.any(nv<=0)or np.any(nv>1)or not 0<=roughness<=1:raise ValueError('Invalid microfacet parameters')
    if roughness==0:return ((1-(1-nv[:,0])**5),(1-nv[:,0])**5)
    i=np.arange(samples,dtype=np.uint32);bits=i.copy();reverse=np.zeros_like(bits)
    for _ in range(32):reverse=(reverse<<1)|(bits&1);bits>>=1
    u=(i.astype(float)+.5)/samples;v=reverse.astype(float)/2**32
    a=roughness**2;hz=np.sqrt((1-v)/(1+(a*a-1)*v));r=np.sqrt(np.maximum(1-hz*hz,0))
    hx=r*np.cos(2*np.pi*u);hy=r*np.sin(2*np.pi*u)
    vh=np.sqrt(1-nv*nv)*hx+nv*hz
    nl=2*vh*hz-nv
    def g1(x):return 2*x/np.maximum(x+np.sqrt(a*a+(1-a*a)*x*x),1e-12)
    g=g1(nv)*g1(np.maximum(nl,0));weight=np.where(nl>0,g*np.maximum(vh,0)/np.maximum(nv*hz,1e-12),0)
    fresnel=(1-np.clip(vh,0,1))**5
    return np.mean(weight*(1-fresnel),axis=1),np.mean(weight*fresnel,axis=1)

def sun_visibility(scene,points,direction):
    p=np.asarray(points,float);d=np.asarray(direction,float)
    if d.shape!=(3,)or not np.isfinite(d).all()or np.linalg.norm(d)==0:raise ValueError('Sun direction required')
    d=d/np.linalg.norm(d);valid=~occupied(scene,p);out=np.zeros(len(p),np.uint8)
    hit,_=scene.trace(p[valid],np.broadcast_to(d,(int(valid.sum()),3)));out[valid]=(hit<0)
    return out

def bake(source,lattice,out):
    source=Path(source);lattice=Path(lattice);out=Path(out);out.mkdir()
    m=json.loads((source/'metadata.json').read_text());grid=json.loads((lattice/'metadata.json').read_text())
    scene=Scene(m['occupied'],m['offset'],m['side_colors'],m['top_colors'])
    ijk=np.indices(grid['dimensions']).reshape(3,-1).T;p=np.asarray(grid['origin'])+ijk*grid['step']
    visibility=sun_visibility(scene,p,m['sun_direction']);(visibility*255).tofile(out/'visibility.bin')
    meta={k:grid[k]for k in ['origin','step','dimensions','source_runtime_sha256','ambient_recipe_identity','material_fingerprints','surface_recipe_sha256','sun_direction']}
    meta.update(scope='Original GAF static sun visibility, not native light shafts',probe_count=len(p),unoccluded=int(visibility.sum()))
    (out/'metadata.json').write_text(json.dumps(meta,indent=2))
    size=64;lut=[]
    for y in range(size):
        a,b=ggx_brdf((np.arange(size)+.5)/size,(y+.5)/size,1024);lut.append(np.stack([a,b],axis=-1))
    table=np.array(lut,dtype='<f2');assert np.isfinite(table).all()and table.min()>=0
    table.tofile(out/'brdf.bin');print('ENV_LIGHT_BAKE',meta['probe_count'],meta['unoccluded'],'LUT range',table.min(),table.max())
if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--source',required=True);a.add_argument('--lattice',required=True);a.add_argument('--output',required=True);v=a.parse_args();bake(v.source,v.lattice,v.output)
