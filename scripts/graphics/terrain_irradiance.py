"""Original scene-owned diffuse transport; no MD2 files, shaders or radiance arrays.

Uses the established unit-XZ/half-Y solid grid. Runtime only interpolates results.
Sky visibility and single sunlight bounce are separate; the color-aware geometric
series for untraced sky bounces is an approximation, not recovered Lumen.
"""
from pathlib import Path
import argparse, json, time
import numpy as np


class Scene:
    def __init__(self,cells,offset,colors,top_colors=None):
        cells=np.asarray(cells,int);self.offset=np.asarray(offset,float)
        self.colors=np.asarray(colors,float)
        self.top_colors=np.asarray(top_colors if top_colors is not None else colors,float)
        if cells.ndim!=2 or cells.shape[1]!=3 or not len(cells):raise ValueError('Solid cells required')
        if self.colors.shape!=cells.shape or self.top_colors.shape!=cells.shape or not np.isfinite(self.colors).all() or not np.isfinite(self.top_colors).all():raise ValueError('Finite RGB per cell required')
        if np.any(self.colors<0) or np.any(self.colors>1) or np.any(self.top_colors<0) or np.any(self.top_colors>1):raise ValueError('Reflectance must be in [0,1]')
        if self.offset.shape!=(3,) or not np.isfinite(self.offset).all():raise ValueError('Finite offset required')
        self.cells=cells;self.low=cells.min(0);self.high=cells.max(0)+1;self.scale=np.array([1.,2.,1.])
        self.grid=np.full(tuple(self.high-self.low),-1,np.int32)
        self.grid[tuple((cells-self.low).T)]=np.arange(len(cells))
        if np.count_nonzero(self.grid>=0)!=len(cells):raise ValueError('Duplicate cells')

    def trace(self,origins,directions):
        o=(np.asarray(origins,float)-self.offset)*self.scale
        d=np.broadcast_to(np.asarray(directions,float),o.shape)*self.scale
        if not np.isfinite(o).all() or not np.isfinite(d).all() or np.any(np.all(d==0,axis=1)):raise ValueError('Invalid ray')
        a=np.divide(self.low-o,d,out=np.full_like(d,-np.inf),where=d!=0)
        b=np.divide(self.high-o,d,out=np.full_like(d,np.inf),where=d!=0)
        slab=np.minimum(a,b);enter=np.maximum(slab.max(1),0.)
        leave=np.maximum(a,b).min(1)
        valid=(leave>enter)&np.all((d!=0)|((o>=self.low)&(o<self.high)),axis=1)
        o=o+d*np.where(valid,enter+1e-8,0.)[:,None]
        cell=np.floor(o).astype(np.int32);step=np.sign(d).astype(np.int32)
        delta=np.divide(1.,abs(d),out=np.full_like(d,np.inf),where=d!=0)
        tmax=np.divide(cell+(step>0)-o,d,out=np.full_like(d,np.inf),where=d!=0)
        result=np.full(len(o),-1,np.int32);normal=np.zeros((len(o),3),np.int8)
        entry_axis=slab.argmax(1);initial=np.flatnonzero(valid&(enter>0))
        normal[initial,entry_axis[initial]]=-step[initial,entry_axis[initial]]
        active=np.flatnonzero(valid&np.all((cell>=self.low)&(cell<self.high),axis=1))
        while len(active):
            value=self.grid[tuple((cell[active]-self.low).T)];hit=value>=0
            result[active[hit]]=value[hit];active=active[~hit]
            if not len(active):break
            axes=tmax[active]<=tmax[active].min(1)[:,None]+1e-12
            axis=np.argmax(np.where(axes,abs(d[active]),-1),axis=1)
            normal[active]=0;normal[active,axis]=-step[active,axis]
            cell[active]+=step[active]*axes
            tmax[active]=np.where(axes,tmax[active]+delta[active],tmax[active])
            active=active[np.all((cell[active]>=self.low)&(cell[active]<self.high),axis=1)]
        normal[result<0]=0
        return result,normal


def sphere(count):
    i=np.arange(count,dtype=float);y=1.-2.*(i+.5)/count
    angle=i*(np.pi*(3.-np.sqrt(5.)));r=np.sqrt(1-y*y)
    return np.column_stack([np.cos(angle)*r,y,np.sin(angle)*r])


def receiver_origins(scene,points,epsilon=.01):
    """Approach an exposed face from empty space, including concave endpoints.

    A normal epsilon alone can enter the perpendicular wall meeting a vertex.
    Retain valid origins exactly; otherwise choose the nearest legal tangential
    offset within a 1cm square. This changes integration origins, never geometry.
    """
    p=np.asarray(points,float);normal=p[:,3:]
    origin=p[:,:3]+normal*epsilon
    def occupied(q):
        cell=np.floor((q-scene.offset)*scene.scale).astype(int)
        within=np.all((cell>=scene.low)&(cell<scene.high),axis=1)
        result=np.zeros(len(cell),bool)
        result[within]=scene.grid[tuple((cell[within]-scene.low).T)]>=0
        return result
    pending=occupied(origin)
    if not np.any(pending):return origin
    axis=np.eye(3)[abs(normal).argmin(1)]
    tangent=np.cross(normal,axis);tangent/=np.linalg.norm(tangent,axis=1)[:,None]
    other=np.cross(normal,tangent)
    for a,b in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
        candidate=p[:,:3]+normal*epsilon+(a*tangent+b*other)*epsilon
        accept=pending&~occupied(candidate)
        origin[accept]=candidate[accept];pending[accept]=False
        if not np.any(pending):return origin
    raise ValueError('Receiver has no exposed origin in its tangential neighbourhood')


def integrate(scene,points,rays,sun_direction,sky_mean):
    points=np.asarray(points,float);dirs=sphere(rays);mean=np.asarray(sky_mean,float)
    sun=np.asarray(sun_direction,float);sun=sun/np.linalg.norm(sun)
    if points.ndim!=2 or points.shape[1]!=6 or not np.isfinite(points).all() or not np.allclose(np.linalg.norm(points[:,3:],axis=1),1,atol=1e-4):raise ValueError('Finite unit-normal receivers required')
    sky_radiance=mean*(1+dirs[:,1,None]*np.array([.15,.25,.45])+.18*(dirs[:,0,None]*.616-dirs[:,2,None]*.788))
    origins=receiver_origins(scene,points)
    sky_out=[];sun_out=[];vis_out=[]
    for start in range(0,len(points),128):
        p=points[start:start+128];n=len(p);origin=np.repeat(origins[start:start+128],rays,axis=0)
        hit,normal=scene.trace(origin,np.tile(dirs,(n,1)));mask=hit>=0
        weight=np.maximum(p[:,3:]@dirs.T,0.)*(4./rays)
        visible=(~mask).reshape(n,rays)
        sky=(weight*visible)@sky_radiance
        visibility=np.clip((weight*visible).sum(1),0,1)
        color=np.zeros((len(hit),3));color[mask]=scene.colors[hit[mask]]
        top=mask&(normal[:,1]>0);color[top]=scene.top_colors[hit[top]]
        blocked_weight=weight*(~visible)
        avg=(blocked_weight[:,:,None]*color.reshape(n,rays,3)).sum(1)/np.maximum(blocked_weight.sum(1)[:,None],1e-9)
        # Energy-bounded, original diffuse multibounce reserve. Zero incident
        # light remains zero, and black occluders contribute no colored reserve.
        sky/=np.maximum(1.-avg*(1.-visibility[:,None]),.05)
        bounced=np.zeros((len(hit),3))
        lit=mask&(normal@sun>0)
        if np.any(lit):
            # Get hit positions with grid plane intersections. The first-hit
            # cell identifies its exact outward plane in the anisotropic grid.
            axis=np.abs(normal[lit]).argmax(1)
            plane=(scene.cells[hit[lit]]+(normal[lit]>0))/scene.scale+scene.offset
            direction=np.tile(dirs,(n,1))[lit]
            distance=(plane[np.arange(len(axis)),axis]-origin[lit][np.arange(len(axis)),axis])/direction[np.arange(len(axis)),axis]
            position=origin[lit]+direction*distance[:,None]+normal[lit]*.01
            shadow,_=scene.trace(position,np.broadcast_to(sun,position.shape))
            bounced[lit]=color[lit]*np.maximum(normal[lit]@sun,0)[:,None]*(shadow<0)[:,None]
        sky_out.append(sky);sun_out.append((weight[:,:,None]*bounced.reshape(n,rays,3)).sum(1));vis_out.append(visibility)
    return {'sky':np.concatenate(sky_out),'sun':np.concatenate(sun_out),'visibility':np.concatenate(vis_out)}


def bake(source,output,rays):
    source=Path(source);output=Path(output);output.mkdir()
    meta=json.loads((source/'metadata.json').read_text());points=np.fromfile(source/'vertices.bin','<f4').reshape(-1,6)
    if len(points)!=meta['count'] or rays<64:raise ValueError('Invalid source/count')
    snapped=np.round(points[:,:3]*2)*.5;points[:,:3]=np.where(abs(points[:,:3]-snapped)<1e-4,snapped,points[:,:3])
    unique,inverse=np.unique(points,axis=0,return_inverse=True)
    scene=Scene(meta['occupied'],meta['offset'],meta['side_colors'],meta['top_colors'])
    origins=receiver_origins(scene,unique)
    baseline=unique.astype(float)
    repaired=int(np.count_nonzero(np.linalg.norm(origins-(baseline[:,:3]+baseline[:,3:]*.01),axis=1)>1e-9))
    started=time.monotonic();result=integrate(scene,unique,rays,meta['sun_direction'],meta['sky_mean'])
    for name in ['sky','sun']:result[name][inverse].astype('<f4').tofile(output/(name+'.bin'))
    info={k:v for k,v in meta.items() if k not in ['occupied','side_colors','top_colors']}
    info.update(rays=rays,unique_receivers=len(unique),receiver_origin_policy='empty_tangent_neighbourhood_v2',repaired_receivers=repaired,seconds=time.monotonic()-started,sky_min=float(result['sky'].min()),sky_max=float(result['sky'].max()),sun_max=float(result['sun'].max()),visibility_mean=float(result['visibility'].mean()),scope='Original GAF static diffuse transport; not native Lumen')
    (output/'metadata.json').write_text(json.dumps(info,indent=2));print(json.dumps({k:v for k,v in info.items() if k!='rows'}))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--output',required=True);p.add_argument('--rays',type=int,default=256)
    a=p.parse_args();bake(a.source,a.output,a.rays)
