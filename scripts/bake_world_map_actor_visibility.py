"""Bake original GAF oak visibility. Does not read MD2 or modify source assets.
Run with --output pointing at a scratch folder, then the companion Godot packer.
"""
from pathlib import Path
import argparse,ast,json,random,hashlib,time
import numpy as np

def directions(count):
    i=np.arange(count,dtype=float);y=(i+.5)/count;a=i*(np.pi*(3-np.sqrt(5)))
    r=np.sqrt(1-y*y)
    return np.stack([r*np.cos(a),y,r*np.sin(a)],axis=1)

def trace(points,dirs,occupancy,minimum,cell=.15):
    """Exact forward DDA at voxel boundaries. Independent of lighting fit."""
    shape=np.array(occupancy.shape);low=minimum*cell;high=(minimum+shape)*cell
    P=np.repeat(np.asarray(points,float),len(dirs),axis=0);D=np.tile(dirs,(len(points),1))
    inv=1/np.where(abs(D)>1e-12,D,1e-12)
    t0=(low-P)*inv;t1=(high-P)*inv
    enter=np.maximum(np.minimum(t0,t1).max(axis=1),0.)
    leave=np.maximum(t0,t1).min(axis=1)
    alive=np.flatnonzero(leave>enter+1e-8);hit=np.zeros(len(P),bool)
    pos=(P[alive]+D[alive]*(enter[alive,None]+1e-7)-low)/cell
    idx=np.floor(pos).astype(int);idx=np.clip(idx,0,shape-1)
    step=np.sign(D[alive]).astype(int);delta=abs(cell*inv[alive])
    edge=low+(idx+(step>0))*cell
    maximum=(edge-P[alive])*inv[alive]
    for _ in range(int(shape.sum())+3):
        if not len(alive):break
        blocked=occupancy[idx[:,0],idx[:,1],idx[:,2]]
        hit[alive[blocked]]=True
        keep=~blocked;alive=alive[keep];idx=idx[keep];maximum=maximum[keep];step=step[keep];delta=delta[keep]
        if not len(alive):break
        axis=maximum.argmin(axis=1);row=np.arange(len(alive));t=maximum[row,axis]
        idx[row,axis]+=step[row,axis];maximum[row,axis]+=delta[row,axis]
        keep=(t<leave[alive]) & (idx>=0).all(axis=1) & (idx<shape).all(axis=1)
        alive=alive[keep];idx=idx[keep];maximum=maximum[keep];step=step[keep];delta=delta[keep]
    return hit.reshape(len(points),len(dirs))

def coefficients(hit,dirs):
    # Original L2 cosine-kernel polynomial: 3/32 + u/2 + 15*u*u/32.
    # Uniform upper-sky samples have solid-angle weight2*pi/N; normalize by pi.
    h=hit.astype(float);n=len(dirs)
    first=h@dirs/n;second=np.einsum('pi,ij,ik->pjk',h,dirs,dirs,optimize=True)/n
    return np.column_stack([.1875*h.mean(axis=1),first,.9375*second[:,0,0],.9375*second[:,1,1],.9375*second[:,2,2],.9375*second[:,0,1],.9375*second[:,0,2],.9375*second[:,1,2]]).astype(np.float32)


def bake(output):
    root=Path(__file__).resolve().parents[1]
    source=root/'blender/environment/studies/forest_canopy_v3/generator.py'
    document=ast.parse(source.read_text(encoding='utf-8'))
    scope={'random':random}
    selected={'hashed','add_box','repair_voxel_edges','box_crown'}
    exec(compile(ast.Module(body=[n for n in document.body if isinstance(n,ast.FunctionDef) and n.name in selected],type_ignores=[]),str(source),'exec'),scope)
    author=next(n for n in document.body if isinstance(n,ast.FunctionDef) and n.name=='trees')
    layouts=ast.literal_eval(next(n.value for n in author.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='layouts' for t in n.targets)))
    manifest=json.loads((source.parent/'manifest.json').read_text())
    output.mkdir(parents=True,exist_ok=True)
    origin=np.array([-6.,-1.,-6.]);size=np.array([25,15,25]);step=.5
    z,y,x=np.meshgrid(np.arange(size[2]),np.arange(size[1]),np.arange(size[0]),indexing='ij')
    points=origin+np.column_stack([x.ravel(),y.ravel(),z.ravel()])*step
    rays=directions(192);rows={}
    for variant,boxes in layouts.items():
        cells,_=scope['box_crown'](boxes,37 if variant.endswith('a') else 81)
        if len(cells)!=manifest['assets'][variant]['leaf_voxels']:raise ValueError('Original geometry changed; revalidate cache contract')
        cells=np.array([(x,z,-y-1) for x,y,z in cells],np.int32);low=cells.min(axis=0);shape=cells.max(axis=0)+1-low
        occupied=np.zeros(shape,bool);q=cells-low;occupied[q[:,0],q[:,1],q[:,2]]=True
        start=time.perf_counter();parts=[]
        for begin in range(0,len(points),256):parts.append(coefficients(trace(points[begin:begin+256],rays,occupied,low),rays))
        values=np.concatenate(parts);values.astype('<f4').tofile(output/(variant+'.bin'))
        rows[variant]={'probes':len(values),'seconds':time.perf_counter()-start,'source_voxels':len(cells)}
    (output/'header.json').write_text(json.dumps({'origin':origin.tolist(),'size':size.tolist(),'step':step,'rays':len(rays),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'assets':rows},indent=2))
    print(json.dumps(rows))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    bake(parser.parse_args().output)
