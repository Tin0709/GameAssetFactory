"""Reuse the proven R2 preview architecture with explicit V2 bases and new data names."""
from pathlib import Path
BASE=Path(__file__).resolve().parent
src=(BASE/'build_turning_r2_preview.py').read_text()
src=src.replace('R2','R3').replace('ReferenceStudy_V1','ReferenceStudy_V2').replace('_Reference_V1','_Reference_V2')
src=src.replace("from turning_r2_common import *",'''from turning_r2_common import *
OUT=BASE/'turning_study_r3_review'
DEV=BASE/'player_locomotion_turning_v2_study.blend'
original_copy_character=copy_character
def copy_character(scene,label):
    r,m=original_copy_character(scene,label)
    r.name='R3_'+label+'_Rig';m.name='R3_'+label+'_Mesh'
    return r,m
''')
src=src.replace("bpy.data.objects['R3_Author_Rig']","bpy.data.objects['R2_R3_Author_Rig']").replace("bpy.data.objects['R3_Author_Mesh']","bpy.data.objects['R2_R3_Author_Mesh']")
src=src.replace('shared R1 phase','shared V2 phase').replace('straight R1 + path','straight V2 + path').replace('R1 asset changes','existing asset changes')
# Bake at four substeps per display frame to preserve sharp V2 recovery through
# interpolation. Integer display frames still follow the original 24 FPS clock.
src=src.replace("for i,row in enumerate(rows):key_pose(author,a,i+1,fullpose(gait,row['time'],row['signed_weight']))",'''for k in range((len(rows)-1)*4+1):
        f=1+k/4;i=int(k/4);u=k/4-i;row=rows[i]
        weight=row['signed_weight']
        if u and i+1<len(rows) and rows[i+1]['case']==row['case']:
            weight=rate(row['case'],row['case_time']+u/24)/MAX_RATE
        key_pose(author,a,f,fullpose(gait,(f-1)/24,weight))''')
ns={'__file__':str(BASE/'build_turning_r2_preview.py')};exec(compile(src,str(BASE/'build_turning_r3_preview.py'),'exec'),ns);result=ns['result']
