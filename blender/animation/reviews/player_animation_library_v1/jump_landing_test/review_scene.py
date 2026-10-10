"""Three separate Actions, with world approach motion only in this review helper."""
import bpy,json,runpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
AP=runpy.run_path(str(OUT.parent/'jump_airpose_test/review_scene.py'))
AIR_DATA=json.loads((OUT.parent/'jump_airpose_test/manifest.json').read_text())
bind=AP['bind'];AIR_END=45;TOTAL=88

def landing_offset(f):
    # Air preview has settled at this offset; ease a single descent into support.
    # This curve never becomes an Action or export channel.
    h=AP['preview_offset'](22,AIR_DATA);t=max(0,min(1,(f-1)/8));ease=t**3*(10-15*t+6*t*t)
    return h*(1-ease)

def sequence(s,r,g):
    if g<=AIR_END:AP['sequence'](s,r,g,AIR_DATA)
    else:
        f=g-AIR_END+1;r.location=landing_offset(f);bpy.data.objects['Showcase_FixedFloor'].location.z=0
        bind(s,r,'Jump_Landing_Test',f)
    bpy.context.view_layer.update()
