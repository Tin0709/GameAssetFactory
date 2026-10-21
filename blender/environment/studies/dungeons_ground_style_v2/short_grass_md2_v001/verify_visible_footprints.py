"""Measure opaque texel support over the two quad strips; read-only native check."""
import bpy,json,math
from pathlib import Path
D=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(D.parent/'dungeons_ground_style_v2.blend'))
M=json.loads((D/'manifest.json').read_text()); image=bpy.data.objects[M['assets'][0]['name']].data.materials[0].node_tree.nodes.get('Image Texture').image
W,H=image.size;pix=list(image.pixels);out=[]
for item in M['assets']:
 m=bpy.data.objects[item['name']].data;uvs=m.uv_layers['UV_Atlas'];points=[]
 for poly in m.polygons:
  vs=[m.vertices[i].co for i in poly.vertices];uv=[uvs.data[i].uv for i in poly.loop_indices]
  u0,u1=uv[0].x,uv[1].x;v0,v1=uv[0].y,uv[3].y
  for y in range(max(0,int(v0*H)),min(H,math.ceil(v1*H))):
   for x in range(max(0,int(u0*W)),min(W,math.ceil(u1*W))):
    if pix[(y*W+x)*4+3]<.5:continue
    for u in [max(u0,x/W),min(u1,(x+1)/W)]:
     for v in [max(v0,y/H),min(v1,(y+1)/H)]:
      s=(u-u0)/(u1-u0);t=(v-v0)/(v1-v0)
      points.append(vs[0]*(1-s)*(1-t)+vs[1]*s*(1-t)+vs[2]*s*t+vs[3]*(1-s)*t)
 size=[max(p[i] for p in points)-min(p[i] for p in points) for i in [0,1]]
 out.append({'name':item['name'],'visible_alpha_xy_m':size})
assert all(min(item['visible_alpha_xy_m'])>=1. for item in out),out
print('VISIBLE_ALPHA_SUPPORT',json.dumps(out));(D/'visible_footprints.json').write_text(json.dumps(out,indent=2)+'\n')
