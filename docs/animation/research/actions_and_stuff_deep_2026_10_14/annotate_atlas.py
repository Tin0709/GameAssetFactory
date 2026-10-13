"""Encode manually inspected pose windows, never inferred 3D contact physics."""
from pathlib import Path
import json,csv,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
P=Path(__file__).resolve().parent
def dump(n,x): (P/n).write_text(json.dumps(x,indent=2,ensure_ascii=False),encoding='utf-8')
def window(kind,offset):
    if kind=='walk':
        half=0 if offset<10 else 1;u=offset%10
        cat=('receive-like' if u==0 else 'lower/compact' if u<=3 else 'rise/exchange' if u<=5 else 'open/extend')
    else:
        half=0 if offset<9 else 1;u=offset if half==0 else offset-9
        cat=('receive-like' if u==0 else 'lower/compact' if u<=2 else 'rise/exchange' if u<=4 else 'open/extend')
    return half,u,cat
def main():
    media=json.loads((P/'source_media.json').read_text());raw=json.loads((P/'screen_proxies.json').read_text())
    rows=[];cycles=[]
    for kind,starts,period,other in [('walk',[30,50,70],20,10),('run',[40,57,74],17,9)]:
        for ci,start in enumerate(starts,1):
            cyc={'id':f'{kind}_{ci}','source_filename':Path(media[kind]['path']).name,'sha256':media[kind]['sha256'],
              'fps':30,'pack_version':'unknown','review_speed':'recorded 1x; original edit/speed provenance unknown',
              'first_frame':start,'closing_frame':start+period,'frame_intervals':period,'duration_s':period/30,
              'time_start_s':start/30,'time_end_s':(start+period)/30,'phase_normalization':'100*(frame-first)/period; no video retime',
              'candidate_receiving_frames':[start,start+other,start+period],
              'candidate_anatomical_sides':['L?','R?','L?'] if kind=='walk' else ['R?','L?','R?'],
              'side_limit':'Assumes unmirrored front view. Screen side is reliable; anatomical assignment not verified.',
              'event_tolerance_frames':1,'event_tolerance_ms':1000/30,'contact_confidence':'low; extension/load transition only',
              'pose_repeat_confidence':'medium-high within this shot','grounded_intervals_3d':None,'airborne_intervals_3d':None,
              'hip_height_m':None,'bone_angles_deg':None,'support_duty_fraction':None,
              'sheet':f'{kind}_cycle_{ci}_F{start}_{start+period}.jpg'}
            cycles.append(cyc)
            for f in range(start,start+period+1):
                half,u,cat=window(kind,f-start if f<start+period else 0)
                primary_screen='right' if kind=='walk' else 'left'
                side=primary_screen if half==0 else ('left' if primary_screen=='right' else 'right')
                row={'source':kind,'cycle':ci,'source_frame_zero_based':f,'source_time_s':f/30,
                     'phase_percent':100*(f-start)/period,'observed_pose_family':cat,
                     'receiving_candidate':f in cyc['candidate_receiving_frames'],
                     'dominant_extension_screen_side':side,'possible_support':'extension-side candidate only; NOT certified',
                     'opposite_leg':'foreshortens/recovering' if cat=='lower/compact' else 'narrowing/exchanging' if cat=='rise/exchange' else 'opening/foreshortened opposite',
                     'body_landmark':'cap/shirt lower' if cat=='lower/compact' else 'cap/shirt rise' if cat=='rise/exchange' else 'readable extended silhouette',
                     'upper_body':'item-bearing and free arm unequal; cap/chest slope changes; exact lag unknown',
                     'hip_height':'unobservable as a 3D joint; shirt hem is a projection proxy only',
                     'push_off':'candidate recovery, force/contact unverified' if cat=='rise/exchange' else 'unknown',
                     'grounded_airborne':'unknown','confidence_pose':'medium','confidence_contact':'low',
                     'temporal_uncertainty_frames':1,
                     'note':'Manual pose-family annotation after inspecting ALL selected consecutive frames; phase windows approximate, not source keyframes.'}
                rows.append(row)
    dump('cycles.json',cycles);dump('frame_observations.json',rows)
    with (P/'frame_observations.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
    # Coarse pose-family intervals, with continuous source durations retained.
    colors={'receive-like':'#d48848','lower/compact':'#557da4','rise/exchange':'#43a38c','open/extend':'#af81af'}
    fig,ax=plt.subplots(figsize=(12,5),layout='constrained')
    for i,c in enumerate(cycles):
        rs=[r for r in rows if r['source']==c['id'].split('_')[0] and r['cycle']==int(c['id'][-1])][:-1]
        for r in rs:
            ax.broken_barh([(r['phase_percent'],100/c['frame_intervals'])],(i-.32,.64),facecolors=colors[r['observed_pose_family']])
        for f in c['candidate_receiving_frames']:
            ph=100*(f-c['first_frame'])/c['frame_intervals'];ax.plot(ph,i,'k|',markersize=15)
    ax.set_yticks(range(6),[f"{c['id']} F{c['first_frame']}–{c['closing_frame']} ({c['duration_s']:.3f}s)" for c in cycles])
    ax.set_xlim(0,100);ax.set_xlabel('Normalized gait phase %; black ticks = receiving candidates, NOT verified contact')
    ax.set_title('Six consecutive-cycle observations | ±1 source frame on pose events | source30FPS')
    from matplotlib.patches import Patch
    ax.legend(handles=[Patch(color=v,label=k) for k,v in colors.items()],loc='upper center',bbox_to_anchor=(.5,-.14),ncol=4)
    fig.savefig(P/'reference_timeline.png',dpi=150);plt.close(fig)
    stats={}
    for kind,data in raw.items():
        stats[kind]={}
        for c in range(1,4):
            rr=[r for r in data if r['cycle']==c];a=np.array([r['cap_y_raw_px'] if r['cap_y_raw_px'] is not None else np.nan for r in rr])
            stats[kind][str(c)]={'cap_missing_frames':[r['frame'] for r in rr if r['cap_y_raw_px'] is None],
                'cap_raw_lowering_first_3_intervals_px':float(np.nanmax(a[:4])-a[0]),
                'cap_mask_slope_range_deg':[min(r['cap_screen_slope_deg'] for r in rr if r['cap_screen_slope_deg'] is not None),max(r['cap_screen_slope_deg'] for r in rr if r['cap_screen_slope_deg'] is not None)],
                'camera_cumulative_end_px':[rr[-1]['camera_dx_px'],rr[-1]['camera_dy_px']],
                'use':'Exploratory screen-space statistics only; not body compression or world rotation.'}
    dump('proxy_statistics.json',stats)
    dump('measurement_limits.json',{
      'inspection':'All653 source frames inspected in existing numbered overview sheets; newly decoded, hashes match. Detailed all-frame sheets for Walk30–90, Run40–91 and rear160–199 each.',
      'accepted':['Decoded frame count/FPS/hash','source frame/time','visible pose-order and repeated silhouette intervals','cap/item/shirt pixel proxies where overlay matches'],
      'rejected':['First unrestricted color mask chose background tower/sky and item as cap; replaced with restricted masks before final data.',
                  'Accumulated background translation is not calibrated camera pose; notably second-cycle drift is retained as diagnostic, not physical height.',
                  'Shoe patches merge/occlude and can pick dark item detail; no continuous foot path/contact/velocity is inferred.',
                  'Shirt lower edge is not an observable hip joint; no 3D hip height or bone angles recovered.',
                  'Finite differences of noisy pixel centroids do not establish source acceleration/jerk or interpolation.'],
      'pixel_uncertainty':'about2–4px on clear cap edges; larger/unbounded for occluded shirt/item/shoes',
      'side_convention':'screen left/right primary; anatomical L/R provisional assuming unmirrored front',
      'sound':'Not listened to or analyzed. No sound attribution from visible dust.',
      'version_speed':'Pack version/settings/source capture speed unknown; recorded1x30FPS is not independently verified real-game speed.',
      'peer_review':'Independent second agent visually checked all six cycle sheets and supported20-frame Walk /17-frame Run local repeats, not exact source periods.',
      'supersedes':'Earlier rough Run16-frame estimate for this selected segment; no claim of universal17-frame run.'})
    print(json.dumps(stats,indent=2))
if __name__=='__main__':main()
