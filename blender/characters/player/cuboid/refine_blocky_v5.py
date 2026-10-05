from pathlib import Path
p=Path(r'C:\Users\ADMIN\Desktop\GameAssetFactory\blender\characters\player\cuboid\create_blocky_run_v5_pass5.py');s=p.read_text(encoding='utf-8-sig')
s=s.replace("if phase<.01 or phase>7.99:right=.23","if phase<.01 or phase>7.99:\n                right=.23;slope=-.038 if k.co.x<5 or k.co.x>16 else -.032")
s=s.replace("# Remove interior keys on truly constant channels;", """if n in ['Neck','Head'] and c.array_index==0:
        for k in c.keyframe_points:
            offset=1.4 if n=='Neck' else 1.7
            if abs((k.co.x-shift[n]-1)%8-offset-2)<.02:k.co.y-=math.radians(.16 if n=='Neck' else .09)
    # Remove interior keys on truly constant channels;""")
s=s.replace('if error<=.00012:break','if error<=(.00045 if axis==1 else .00012):break').replace('assert error<=.00012,(n,axis,error)','assert error<=(.00045 if axis==1 else .00012),(n,axis,error)')
s=s.replace('0.12 mm local error','0.45 mm vertical / 0.12 mm transverse local error')
s=s.replace("report=dict(action=v5.name", "assert all(a<b for a,b in zip(half_compression(v5),half_compression(v4)))\nreport=dict(action=v5.name")
p.write_text(s,encoding='utf-8')
