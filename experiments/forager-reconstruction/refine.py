"""Apply the selected silhouette and color corrections from the first render."""
from pathlib import Path

def revise(file,edits):
    p=Path(file)
    text=p.read_text(encoding="utf-8-sig")
    for before,after in edits:
        assert before in text,before
        text=text.replace(before,after,1)
    p.write_text(text,encoding="utf8")

revise("forms.py",[
    ("a=-(u.cross(v)).normalized()", "a=(u.cross(v)).normalized()"),
])
revise("headwear.py",[
    ("edge= q>54 and z<270","edge=z<264"),
    ("(-9,314,4.8,1.35),(-9,319,4.8,1.3),\n                                   (-11.1,316.5,1.25,5.2),(-6.8,315.3,1.25,5.1)",
     "(-5,312.6,6.25,1.65),(-5,318.4,6.25,1.65),\n                                   (-7.6,315.5,1.65,6.1),(-2.4,315,1.65,6.1)"),
])
revise("garments.py",[
    ('    ],"linen",chest,"Chest",.58)',
     '''    ],"leather",chest,"Chest",.58)
    panel("Shirt · narrow linen placket",[
        (-6,-26.4,238),(4,-26.4,240),(7,-27.4,222),(7,-27.0,178),
        (10,-26.4,162),(-7,-26.4,161),(-6,-27.1,201)
    ],(0,2,0),"linen",chest,"Chest",.2)'''),
    ("yy=21+15*row+fold+9*row*row*(1-abs(x)/70)",
     "yy=21+15*row+fold+9*row*row*(1-abs(x)/70)+10*(1-row)**2"),
    ("    thick.material_offset_rim=3\n",'''    thick.material_offset_rim=3
    back.shape_key_add(name="Resting cloak")
    drape=back.shape_key_add(name="Hero · outward sweep")
    for v in drape.data:
        x,y,z=v.co/U
        fall=max(0,min(1,(230-z)/117))
        near=max(0,min(1,(45-x)/85))
        v.co.x-=U*18*fall*near
        v.co.y+=U*16*fall*(.5+.5*near)
    drape.driver_add("value").driver.expression="1.0 if frame == 2 else 0.0"
'''),
])
revise("build.py",[
    ('    ("purple",.89,0),("wood",.9,0),','    ("purple",.89,0),("wood",.9,0),("stone",.76,0),'),
    ('material("amber",.42,0,(.92,.37,.033),1.8)','material("amber",.42,0,(.98,.26,.029),1.25)'),
    ('material("flame",.45,0,(1.0,.70,.18),4.25)','material("flame",.45,0,(1.0,.50,.075),2.05)'),
    ('material("stage",.94,0,(.016,.0125,.019))','material("stage",.94,0,(.026,.018,.024),.31)'),
    ('    data.ortho_scale=scale','    data.ortho_scale=scale\n    data.clip_end=350'),
    ('bone.location=basis@Vector((side*.012,side*.045,0))',
     'bone.location=basis@Vector((side*.024,-side*.026,.012))'),
    ('bone.rotation_quaternion=axis_delta(bone,(0,0,1),side*6.5)',
     '''bone.rotation_quaternion=axis_delta(bone,(0,1,0),-side*5.2) @ axis_delta(bone,(0,0,1),side*5.5)
                bpy.context.view_layer.update()
                sole=scene.objects[("R" if side<0 else "L")+" · heavy sole"]
                low=min((sole.matrix_world@v.co).z for v in sole.data.vertices)
                bone.location+=basis@Vector((0,0,-low))'''),
    ('(2000,2000,2.43)','(100000,100000,2.43)'),
    ('(0,0,1.34),80,(1,.92,.85),2.32','(0,0,1.34),68,(1,.90,.80),2.32'),
    ('scene.view_settings.exposure=.13','scene.view_settings.exposure=.06'),
])
revise("details.py",[
    ('octagon(p(321,1),20,12.3,4.3)','octagon(p(321,1),23.3,14.4,4.3)'),
    ('octagon(p(335,3),13.6,9.4,3.0)','octagon(p(335,3),15.3,10.8,3.2)'),
    ('    ],"iron",col,None,.36)','    ],"stone",col,None,.36)'),
])
revise("paint.py",[
    ('"moss":("383823","48452c","544c30","5d5535","69613c","7a6a40","8c7b4b")',
     '"moss":("343622","40412a","4a472f","544e33","62583a","6d603b","7b6a48")'),
    ('"mossDark":("302e21","383626","403d2a","49432d","4f482f","5d5335","675a37")',
     '"mossDark":("2c291c","363423","3e3d28","45402b","4c462e","555034","5d5538")'),
    ('"wood":("4a291e","623a28","73432c","854b2f","925535","a66941","b47a50"),',
     '"wood":("4a291e","623a28","73432c","854b2f","925535","a66941","b47a50"),\n"stone":("594b52","6a5a64","7b6971","907c82","a18b8e","ad9598","bca8a8"),'),
    ('col=rng.choices(range(7),[3,12,22,36,19,7,1])[0]',
     'col=rng.choices(range(7),[1,7,22,46,18,5,1] if name in ("boot","warmLeather","leather","coal") else [3,12,22,36,19,7,1])[0]'),
    ('"#df9572"','"#e09469"'),
    ('"e9a17b"','"ed9d72"'),
    ('"e9a27c"','"ec9f73"'),
    ('"efa981"','"efa77a"'),
])

