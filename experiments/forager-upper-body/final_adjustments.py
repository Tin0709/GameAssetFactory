"""Add faceted sculpting to the braid while keeping the broad pixel silhouette."""
from pathlib import Path

p=Path("forager.py")
s=p.read_text(encoding="utf8")
s=s.replace('VERSION=2 if PASS in ("refined","final") else 1\n','')
s=s.replace('    cen=(a+b)/2\n','')
start=s.index('def cross(')
end=s.index('def projected_mark',start)
s=s[:start]+s[end:]
old='''for i,(a,b,w,d) in enumerate(braid):
    segment(f"Braid · lobe {i+1}",a,b,w*.885,d*.9,"hair","Head" if i<2 else "Chest",head,.46)'''
new='''def plait_lobe(label,a,b,width,depth,bone):
    a,b=Vector(a),Vector(b)
    direction=(b-a).normalized()
    transverse=Vector((0,1,0)).cross(direction).normalized()
    thickness=direction.cross(transverse).normalized()
    profile=((-1,-.56),(-.57,-1),(.57,-1),(1,-.56),
             (1,.49),(.59,1),(-.59,1),(-1,.49))
    sections=[]
    for t,w,d,lean in ((0,.72,.82,-.2),(.23,1,1,.4),(.78,.89,.90,.1),(1,.65,.71,-.35)):
        mid=a.lerp(b,t)+transverse*lean
        sections.append([tuple(mid+transverse*(u*width*w/2)+thickness*(v*depth*d/2))
                         for u,v in profile])
    return rings(label,sections,"hair",bone,head,.17)

for i,(a,b,w,d) in enumerate(braid):
    plait_lobe(f"Braid · lobe {i+1}",a,b,w*.97,d*.95,"Head" if i<2 else "Chest")'''
assert old in s
s=s.replace(old,new)
s=s.replace('bpy.context.preferences.filepaths.save_version=0',
            'bpy.data.orphans_purge(do_recursive=True)\nbpy.context.preferences.filepaths.save_version=0')
p.write_text(s,encoding="utf8")

