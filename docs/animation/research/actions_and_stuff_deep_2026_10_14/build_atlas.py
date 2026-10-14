"""Read-only reference decoder. Writes analytical outputs only beside this script.
No Blender/Godot/production input is modified. Pixel proxies are NOT bone data.
"""
from pathlib import Path
import cv2, numpy as np, json, hashlib, csv, math
from PIL import Image, ImageDraw, ImageFont
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
from portable_inputs import source, font
FONT=font(14)
SMALL=font(12)
SOURCES={'walk':source('walk'), 'run':source('run')}
def dump(name,data):
    (OUT/name).write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def decode(p):
    cap=cv2.VideoCapture(str(p)); fps=cap.get(cv2.CAP_PROP_FPS); frames=[]
    while True:
        ok,f=cap.read()
        if not ok: break
        frames.append(f)
    cap.release(); return fps,frames

def proxy(f):
    h,w=f.shape[:2]; rgb=cv2.cvtColor(f,cv2.COLOR_BGR2RGB).astype(float)
    r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]; yy,xx=np.indices((h,w))
    # Deliberately broad color-region screen proxies; no hidden anatomy inferred.
    cap=(r>110)&(r>g*1.23)&(g>b*1.22)&(yy<h*.65)&(xx>w*.20)&(xx<w*.85)
    shirt=(b>70)&(b>r*1.25)&(b>g*1.08)&(yy>h*.18)&(yy<h*.70)&(xx>w*.24)&(xx<w*.81)
    def stats(mask,iscap=False):
        n,labels,st,ct=cv2.connectedComponentsWithStats(mask.astype('uint8'))
        if n<2: return None
        candidates=[i for i in range(1,n) if not iscap or (st[i,2]>st[i,3]*2.0 and st[i,2]>20)]
        if not candidates:return None
        idx=min(candidates,key=lambda i:ct[i][1]) if iscap else max(candidates,key=lambda i:st[i,cv2.CC_STAT_AREA]); y,x=np.where(labels==idx)
        if len(x)<8:return None
        slope=np.polyfit(x,y,1)[0] if np.ptp(x)>5 else 0
        return {'x':float(np.mean(x)),'y':float(np.mean(y)), 'area':len(x),
                'width':int(np.ptp(x)+1),'bottom':float(np.quantile(y,.96)),
                'image_slope_deg':float(np.degrees(np.arctan(slope)))}
    cp=stats(cap,True)
    if cp:
        shirt &= (yy>cp['y']+35)&(yy<cp['y']+155)&(xx>cp['x']-50)&(xx<cp['x']+50)&(b>g*1.4)
    sp=stats(shirt) if cp else None
    item=None; shoes=[]
    if cp and sp:
        gold=(r>80)&(r>g*1.15)&(g>b*1.5)&(yy>cp['y']+70)&(yy<cp['y']+215)&(xx<cp['x']-15)&(xx>cp['x']-95)
        item=stats(gold)
        dark=(rgb.max(axis=2)<55)&((rgb.max(axis=2)-rgb.min(axis=2))<22)&(yy>sp['bottom']+12)&(yy<h*.96)&(xx>cp['x']-60)&(xx<cp['x']+60)
        n,lab,st,ct=cv2.connectedComponentsWithStats(dark.astype('uint8'))
        ids=[i for i in range(1,n) if 35<st[i,4]<1100 and st[i,2]>6 and st[i,3]>3]
        ids=sorted(ids,key=lambda i:st[i,4],reverse=True)[:2]
        shoes=sorted([{'x':float(ct[i,0]),'y':float(ct[i,1]),'area':int(st[i,4])} for i in ids],key=lambda p:p['x'])
    return {'cap':cp,'shirt':sp,'item':item,'shoes':shoes}

def camera_step(a,b):
    h,w=a.shape[:2]; mask=np.full((h,w),255,np.uint8)
    mask[int(h*.02):int(h*.91),int(w*.16):int(w*.9)]=0
    ga=cv2.cvtColor(a,cv2.COLOR_BGR2GRAY);gb=cv2.cvtColor(b,cv2.COLOR_BGR2GRAY)
    pts=cv2.goodFeaturesToTrack(ga,180,.01,4,mask=mask)
    if pts is None:return [0.,0.,0,0]
    dst,status,err=cv2.calcOpticalFlowPyrLK(ga,gb,pts,None,winSize=(15,15),maxLevel=2)
    back,bs,_=cv2.calcOpticalFlowPyrLK(gb,ga,dst,None,winSize=(15,15),maxLevel=2)
    good=(status.ravel()==1)&(bs.ravel()==1)&(np.linalg.norm(back-pts,axis=2).ravel()<1.0)
    dif=(dst-pts).reshape(-1,2)[good]
    if len(dif)<6:return [0.,0.,len(dif),0]
    med=np.median(dif,axis=0); residual=np.linalg.norm(dif-med,axis=1)
    keep=residual<2.0
    if keep.sum()<6:return [float(med[0]),float(med[1]),int(keep.sum()),0]
    med=np.median(dif[keep],axis=0)
    return [float(med[0]),float(med[1]),int(keep.sum()),1]

def sheet(name,frames,indices,annotations=None,proxies=None,cols=5):
    w,h=frames[0].shape[1],frames[0].shape[0]; cellw=w+8;cellh=h+55
    im=Image.new('RGB',(cols*cellw,math.ceil(len(indices)/cols)*cellh+40),(20,27,35))
    d=ImageDraw.Draw(im);d.text((8,8),name+' | source frames zero-based; contact = candidate',font=FONT,fill='white')
    for j,fi in enumerate(indices):
        x=(j%cols)*cellw;y=40+(j//cols)*cellh
        img=Image.fromarray(cv2.cvtColor(frames[fi],cv2.COLOR_BGR2RGB)); im.paste(img,(x,y))
        d.text((x+3,y+h+2),f'F{fi}  {fi/30:.3f}s',font=FONT,fill='white')
        if annotations and fi in annotations:d.text((x+3,y+h+21),annotations[fi],font=SMALL,fill='#ffda83')
        if proxies and fi in proxies:
            for key,col in [('cap','#ff8888'),('shirt','#67dfff')]:
                p=proxies[fi][key]
                if p:
                    px=x+p['x'];py=y+p['y'];d.ellipse((px-3,py-3,px+3,py+3),outline=col,width=2)
            for p in proxies[fi]['shoes']:
                px=x+p['x'];py=y+p['y'];d.rectangle((px-3,py-3,px+3,py+3),outline='#ffff55',width=2)
    im.save(OUT/(name+'.jpg'),quality=92)

def main():
    sources={}; allframes={}; measured={}
    for kind,path in SOURCES.items():
        fps,frames=decode(path);allframes[kind]=frames
        dif=[float(np.abs(a.astype(float)-b).mean()) for a,b in zip(frames[:-1],frames[1:])]
        sources[kind]={'path':str(path),'sha256':sha(path),'fps':fps,'decoded_frames':len(frames),
            'dimensions':[frames[0].shape[1],frames[0].shape[0]],'duration_s':len(frames)/fps,
            'pack_version':'unknown','original_playback_speed':'not independently verified; analyzed at recorded 30FPS, no retime',
            'adjacent_exact_duplicate_pairs':[i+1 for i,v in enumerate(dif) if v==0],
            'adjacent_RGB_MAE':dif}
        # Three consecutive primary cycles, chosen by repeating visible extension.
        starts=[30,50,70] if kind=='walk' else [40,57,74]
        period=20 if kind=='walk' else 17
        ps={i:proxy(frames[i]) for i in range(starts[0],starts[-1]+period+1)}
        measured[kind]=[]
        for cycle,start in enumerate(starts):
            rows=[];shift=np.zeros(2)
            for fi in range(start,start+period+1):
                cam=[0.,0.,0,1] if fi==start else camera_step(frames[fi-1],frames[fi])
                shift+=cam[:2];p=ps[fi]
                row={'source':kind,'cycle':cycle+1,'frame':fi,'time_s':fi/fps,
                     'phase_percent':100*(fi-start)/period,'camera_dx_px':float(shift[0]),'camera_dy_px':float(shift[1]),
                     'background_inliers':cam[2],'camera_step_usable':bool(cam[3])}
                for key in ('cap','shirt'):
                    for axis in ('x','y'):
                        row[f'{key}_{axis}_raw_px']=p[key][axis] if p[key] else None
                        row[f'{key}_{axis}_corrected_px']=(p[key][axis]-shift[0 if axis=='x' else 1]) if p[key] else None
                    row[f'{key}_screen_slope_deg']=p[key]['image_slope_deg'] if p[key] else None
                row['shirt_hem_y_proxy_px']=p['shirt']['bottom'] if p['shirt'] else None
                row['item_x_relative_shirt_px']=p['item']['x']-p['shirt']['x'] if p['item'] and p['shirt'] else None
                row['item_y_relative_shirt_px']=p['item']['y']-p['shirt']['y'] if p['item'] and p['shirt'] else None
                row['shoe_components']=len(p['shoes'])
                for si in (0,1):
                    for axis in ('x','y'):
                        row[f'screen_shoe_{si}_{axis}_px']=p['shoes'][si][axis] if len(p['shoes'])>si else None
                row['shoe_projected_y_difference_px']=p['shoes'][1]['y']-p['shoes'][0]['y'] if len(p['shoes'])==2 else None
                rows.append(row)
            measured[kind]+=rows
            anchors=(start,start+(10 if kind=='walk' else 9),start+period)
            anns={r['frame']:f"{r['phase_percent']:.0f}% | "+('receive?' if r['frame'] in anchors else 'screen proxies') for r in rows}
            sheet(f'{kind}_cycle_{cycle+1}_F{start}_{start+period}',frames,[r['frame'] for r in rows],anns,ps)
        rear_start=160
        sheet(kind+'_rear_context_F160_199',frames,list(range(rear_start,rear_start+40)),cols=5)
        # Plot only measured screen proxies; resets camera accumulation per cycle.
        fig,axs=plt.subplots(3,2,figsize=(12,9),layout='constrained')
        for c in range(1,4):
            rows=[r for r in measured[kind] if r['cycle']==c];phase=[r['phase_percent'] for r in rows]
            for k,key in enumerate(('cap','shirt')):
                for typ,ls in [('raw','--'),('corrected','-')]:
                    ys=np.array([r[f'{key}_y_{typ}_px'] for r in rows],float)
                    axs[k,0].plot(phase,-(ys-ys[0]),ls,label=f'C{c} {typ}')
                raw=np.array([r[f'{key}_y_corrected_px'] for r in rows],float)
                axs[k,1].plot(phase[:-1],-np.diff(raw),label=f'C{c}')
            axs[2,0].plot(phase,[r['cap_screen_slope_deg'] for r in rows],label=f'C{c}')
            gap=np.array([r['shirt_y_raw_px']-r['cap_y_raw_px'] if r['shirt_y_raw_px'] is not None and r['cap_y_raw_px'] is not None else np.nan for r in rows])
            axs[2,1].plot(phase,gap-gap[0],label=f'C{c}')
        titles=['Cap displacement (+up), px','Cap spacing, px/frame','Shirt-region displacement (+up), px','Shirt spacing, px/frame','Cap mask projected slope, degrees','Shirt-cap projected gap change, px']
        for ax,t in zip(axs.flat,titles):
            ax.set_title(t);ax.set_xlabel('Gait phase % (candidate anchors)');ax.grid(alpha=.25);ax.legend(fontsize=7,ncol=2)
        fig.suptitle(kind.upper()+': 2D color proxies, NOT hips/bones/COM; camera correction approximate')
        fig.savefig(OUT/(kind+'_screen_proxy_curves.png'),dpi=140);plt.close(fig)
        fig,axs=plt.subplots(2,1,figsize=(11,6),layout='constrained')
        for c in range(1,4):
            rows=[r for r in measured[kind] if r['cycle']==c];phase=[r['phase_percent'] for r in rows]
            axs[0].plot(phase,[r['shoe_projected_y_difference_px'] for r in rows],marker='.',label=f'C{c}')
            axs[1].plot(phase,[r['item_y_relative_shirt_px'] for r in rows],marker='.',label=f'C{c}')
        axs[0].set_title('Screen-right minus screen-left shoe patch Y; merged/absent = gap (NOT clearance)')
        axs[1].set_title('Gold item Y relative to shirt-region centroid (NOT hand-joint travel)')
        for ax in axs:ax.legend();ax.grid(alpha=.25);ax.set_xlabel('Phase %');ax.set_ylabel('pixels')
        fig.suptitle(kind.upper()+' limb silhouettes: exploratory 2D masks; see confidence/occlusion notes')
        fig.savefig(OUT/(kind+'_limb_proxies.png'),dpi=140);plt.close(fig)
    dump('source_media.json',sources);dump('screen_proxies.json',measured)
    for kind,rows in measured.items():
        with (OUT/(kind+'_screen_proxies.csv')).open('w',newline='',encoding='utf-8') as f:
            writer=csv.DictWriter(f,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
    print(json.dumps({k:{kk:vv for kk,vv in v.items() if kk!='adjacent_RGB_MAE'} for k,v in sources.items()},indent=2))

if __name__=='__main__':main()
