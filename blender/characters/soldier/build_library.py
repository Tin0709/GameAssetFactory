"""Register the same Pending review candidate in the requested Soldier library."""
import bpy,json,uuid,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;R=HERE.parents[2]
D=R/'blender/characters/player/reviews/survivor_reference_v001'
FILE=HERE/'SOLDIER_Asset_Library.blend'
# A rerun may update the current Pending library only; reviewed assets cannot be replaced.
if FILE.exists():
 with bpy.data.libraries.load(str(FILE),link=False) as (src,dst):dst.scenes=[src.scenes[0]]
 assert dst.scenes[0].get('review_status')=='Pending'
bpy.ops.wm.open_mainfile(filepath=str(D/'Survivor_Reference_v001.blend'),load_ui=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.name='SOLDIER_ASSET_LIBRARY'
asset=next(c for c in bpy.data.collections if c.name.startswith('ASSET'))
asset.name='SOLDIER_Skin_v001_PENDING'
root=bpy.data.collections.new('SOLDIER_ASSETS');scene.collection.children.link(root)
for label in ['01_SKINS','02_HAIR_VARIANTS','03_CLOTHING_UPGRADES','04_EQUIPMENT','05_FUTURE_UPGRADES']:
 c=bpy.data.collections.new(label);root.children.link(c)
 c['purpose']='Current Pending skin' if label=='01_SKINS' else 'Reserved for future user-requested assets; empty'
scene.collection.children.unlink(asset);bpy.data.collections['01_SKINS'].children.link(asset)
asset.asset_mark();asset['review_status']='Pending'
asset.asset_data.description='SOLDIER skin v001 / Pending: layered warm-brown hair, large eyes and brows, no nose/mouth/neck. Original V6 head/torso/legs,3x12x4 slim arms; thick clothing relief. Blender review only.'
asset.asset_data.author='GameAssetFactory'
for name in ['Soldier','Skin','Pending','Blender Review']:
 if name not in asset.asset_data.tags:asset.asset_data.tags.new(name)
ns=uuid.UUID('61d15e50-3029-47c6-9db9-3d1c2813aa89')
paths=['SOLDIER/Skins','SOLDIER/Hair','SOLDIER/Clothing','SOLDIER/Equipment','SOLDIER/Future Upgrades']
cat_ids={p:str(uuid.uuid5(ns,p)) for p in paths}
(HERE/'blender_assets.cats.txt').write_text('# Blender Asset Catalog Definition File\nVERSION 1\n\n'+'\n'.join(cat_ids[p]+':'+p+':'+p.split('/')[-1] for p in paths)+'\n')
asset.asset_data.catalog_id=cat_ids['SOLDIER/Skins']
with bpy.context.temp_override(id=asset):bpy.ops.ed.lib_id_load_custom_preview(filepath=str(D/'renders/Front_3Q.png'))
body=next(o for o in asset.objects if o.get('body_source'))
hair=next(o for o in asset.objects if o.get('hair_voxel_m'))
clothes=next(o for o in asset.objects if o.type=='MESH' and o not in [body,hair])
rig=next(o for o in asset.objects if o.type=='ARMATURE')
registry={'schema_version':1,'library':'SOLDIER_Asset_Library','status':'Pending','entries':[{'id':'SOLDIER_Skin_v001','label':'Soldier / Survivor reference skin','status':'Pending','collection':asset.name,'body':body.name,'rig':rig.name,'hair':hair.name,'clothing':clothes.name,'source_candidate':str(D/'Survivor_Reference_v001.blend'),'source_body_sha256':json.loads((D/'model_validation.json').read_text())['body_source_sha256'],'slim_arm_wld_m':[.16875,.675,.225],'cameras':['Front','Front_3Q','Left_Side','Back','Right_Side','Back_3Q']}],'reserved_categories':paths[1:],'gameplay_integrated':False}
scene['soldier_registry']=json.dumps(registry);scene['review_status']='Pending'
scene['library_readme']='START HERE — SOLDIER LIBRARY'
text=bpy.data.texts.new('START HERE — SOLDIER LIBRARY')
text.write('SOLDIER ASSET LIBRARY / PENDING\n\nCurrent candidate: SOLDIER_Skin_v001_PENDING in SOLDIER_ASSETS >01_SKINS.\nOne complete skin asset includes body, rig,3D hair and clothing.\nOriginal V6 head/torso/legs; old3x12x4 slim arms. No neck geometry.\nLarge eyes with short brown brows; no nose or mouth.\nHair retains staggered locks with20% thinner outer relief. Clothing is thicker for distance readability.\nImages/reference/four-view review are packed. Front_3Q is the opening camera.\nUse Numpad0 or the six named cameras. F12 renders.\nAsset Browser: choose Current File to browse the marked Soldier skin.\nFuture Hair/Clothing/Equipment/Upgrade folders are intentionally empty.\nAdd upgrades as separate Pending collections/assets; preserve existing reviewed versions.\nNo Godot integration and no new animation Actions.\n')
scene.camera=bpy.data.objects['Front_3Q']
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA'
   area.spaces.active.overlay.show_overlays=False
   area.spaces.active.shading.type='MATERIAL'
  if area.type=='DOPESHEET_EDITOR':
   area.type='FILE_BROWSER';area.ui_type='ASSETS'
   params=getattr(area.spaces.active,'params',None)
   if params:params.asset_library_reference='LOCAL'
# All packed images remain portable; source candidate and approved sources are never saved.
assert len(bpy.data.actions)==0 and len([o for o in asset.objects if o.type=='MESH'])==3
bpy.ops.wm.save_as_mainfile(filepath=str(FILE),compress=True)
(HERE/'registry.json').write_text(json.dumps(registry,indent=2))
print('SOLDIER_LIBRARY_SAVED',str(FILE))
