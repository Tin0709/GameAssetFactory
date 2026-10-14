const GAF_BRIDGE_CONTRACT={"schema": "gaf.blockbench.contract.v1", "units_per_meter": 16, "blender_to_blockbench": [[16, 0, 0, 0], [0, 0, 16, 0], [0, -16, 0, 0], [0, 0, 0, 1]], "rig_sha256": "cb913716b708b9f975b350f4a80a57d8244f1903ced498a6b3ce0fc5f8391b2f", "bones": [{"name": "Root", "uuid": "16f94f12-577e-5ba9-b2bf-f28a6d2d8c41", "parent": null, "origin": [0.0, 0.0, -0.0], "rotation": [0, 0, 0], "blender_rest": [[1.0, 0.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 0.0, 1.0]], "mode": "XYZ", "locked": false}, {"name": "Hips", "uuid": "3c0557f6-3961-5180-976d-d93cf24f95e0", "parent": "Root", "origin": [0.0, 10.799999237060547, -0.0], "rotation": [0, 0, 0], "blender_rest": [[1.0, 0.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 1.0, 0.0, 0.6749999523162842], [0.0, 0.0, 0.0, 1.0]], "mode": "XYZ", "locked": false}, {"name": "Spine", "uuid": "e9d1acb9-c580-50a3-8ed7-ccc684e35434", "parent": "Hips", "origin": [0.0, 12.59999942779541, -0.0], "rotation": [0, 0, 0], "blender_rest": [[1.0, 0.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 1.0, 0.0, 0.7874999642372131], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "Chest", "uuid": "d2bbe433-153c-58be-9ec5-e5bee7d5925c", "parent": "Spine", "origin": [0.0, 17.100000381469727, -0.0], "rotation": [0, 0, 0], "blender_rest": [[1.0, 0.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 1.0, 0.0, 1.068750023841858], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "Neck", "uuid": "b4e74610-aaea-5f80-8660-99f099ee5901", "parent": "Chest", "origin": [0.0, 21.599998474121094, -0.0], "rotation": [0, 0, 0], "blender_rest": [[1.0, 0.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 1.0, 0.0, 1.3499999046325684], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "Head", "uuid": "253419a0-07ea-5671-ae4b-05987de95a64", "parent": "Neck", "origin": [0.0, 21.599998474121094, -0.0], "rotation": [0, 0, 0], "blender_rest": [[1.0, 0.0, 0.0, 0.0], [0.0, 0.0, -1.0, 0.0], [0.0, 1.0, 0.0, 1.3499999046325684], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "UpperArm.L", "uuid": "40ad3fd8-3585-59e4-a4b5-c4c86d7b0f98", "parent": "Chest", "origin": [5.399999618530273, 21.599998474121094, -0.0], "rotation": [0, 0, 0], "blender_rest": [[-1.0, 0.0, -8.742277657347586e-08, 0.3374999761581421], [8.742277657347586e-08, 0.0, -1.0, 0.0], [0.0, -1.0, 0.0, 1.3499999046325684], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "ForeArm.L", "uuid": "58ac4cfd-6719-56b3-92ea-b5a8647e3e53", "parent": "UpperArm.L", "origin": [5.399999618530273, 16.19999885559082, -0.0], "rotation": [0, 0, 0], "blender_rest": [[-1.0, 0.0, -8.742276236262114e-08, 0.3374999761581421], [8.742276236262114e-08, 0.0, -1.0, 0.0], [0.0, -0.9999999403953552, 0.0, 1.0124999284744263], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": true}, {"name": "UpperArm.R", "uuid": "bc092742-33ac-5c2f-aff7-72b785820c5f", "parent": "Chest", "origin": [-5.399999618530273, 21.599998474121094, -0.0], "rotation": [0, 0, 0], "blender_rest": [[-1.0, 0.0, -8.742277657347586e-08, -0.3374999761581421], [8.742277657347586e-08, 0.0, -1.0, 0.0], [0.0, -1.0, 0.0, 1.3499999046325684], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "ForeArm.R", "uuid": "1f3ee01c-aacc-5c54-94c7-90ffcbefd8f8", "parent": "UpperArm.R", "origin": [-5.399999618530273, 16.19999885559082, -0.0], "rotation": [0, 0, 0], "blender_rest": [[-1.0, 0.0, -8.742276236262114e-08, -0.3374999761581421], [8.742276236262114e-08, 0.0, -1.0, 0.0], [0.0, -0.9999999403953552, 0.0, 1.0124999284744263], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": true}, {"name": "WeaponCarrier", "uuid": "f3b24f34-3da6-5530-807d-02c4ffd30991", "parent": "Chest", "origin": [-1.473071575164795, 15.501165390014648, 7.303738117218018], "rotation": [0, 0, 0], "blender_rest": [[-0.9975640177726746, -0.06889767944812775, -0.010912107303738594, -0.09206697344779968], [0.06975644826889038, -0.9852824807167053, -0.15605364739894867, -0.4564836323261261], [2.3283064365386963e-07, -0.15643471479415894, 0.9876883029937744, 0.9688228368759155], [0.0, 0.0, 0.0, 1.0]], "mode": "QUATERNION", "locked": false}, {"name": "Leg.L", "uuid": "689cf123-d20c-532b-90b9-d108b9d87274", "parent": "Hips", "origin": [1.7999999523162842, 10.799999237060547, -0.0], "rotation": [0, 0, 0], "blender_rest": [[-1.0, 0.0, -8.742277657347586e-08, 0.11249999701976776], [8.742277657347586e-08, 0.0, -1.0, 0.0], [0.0, -1.0, 0.0, 0.6749999523162842], [0.0, 0.0, 0.0, 1.0]], "mode": "XYZ", "locked": false}, {"name": "Leg.R", "uuid": "d5c1fed0-34f5-53a3-9805-d2d436f0cf5f", "parent": "Hips", "origin": [-1.7999999523162842, 10.799999237060547, -0.0], "rotation": [0, 0, 0], "blender_rest": [[-1.0, 0.0, -8.742277657347586e-08, -0.11249999701976776], [8.742277657347586e-08, 0.0, -1.0, 0.0], [0.0, -1.0, 0.0, 0.6749999523162842], [0.0, 0.0, 0.0, 1.0]], "mode": "XYZ", "locked": false}], "cubes": [{"name": "Head", "uuid": "2c7a681e-278b-50eb-855d-8cf8362f39d0", "bone": "Head", "from": [-3.5999999046325684, 21.600000381469727, -3.5999999046325684], "to": [3.5999999046325684, 28.799999237060547, 3.5999999046325684], "origin": [0.0, 21.599998474121094, -0.0], "color": 0}, {"name": "Chest", "uuid": "107b259f-86bd-5c05-bff1-82afa0efa8b9", "bone": "Chest", "from": [-3.5999999046325684, 10.800000190734863, -1.7999999523162842], "to": [3.5999999046325684, 21.600000381469727, 1.7999999523162842], "origin": [0.0, 17.100000381469727, -0.0], "color": 1}, {"name": "FullArm.L", "uuid": "f6b99e43-e5f9-5ca3-954f-e15c12e31e64", "bone": "UpperArm.L", "from": [4.049999713897705, 10.799999237060547, -1.7999999523162842], "to": [6.75, 21.600000381469727, 1.7999999523162842], "origin": [5.399999618530273, 21.599998474121094, -0.0], "color": 2}, {"name": "FullArm.R", "uuid": "735d19f5-dc51-5d41-b2a5-d0e00fe7daaa", "bone": "UpperArm.R", "from": [-6.75, 10.799999237060547, -1.7999999523162842], "to": [-4.049999713897705, 21.600000381469727, 1.7999999523162842], "origin": [-5.399999618530273, 21.599998474121094, -0.0], "color": 3}, {"name": "Leg.L", "uuid": "6a7c5855-d1bf-534d-b13e-39b581cd3638", "bone": "Leg.L", "from": [0.0, 0.0, -1.7999999523162842], "to": [3.5999999046325684, 10.800000190734863, 1.7999999523162842], "origin": [1.7999999523162842, 10.799999237060547, -0.0], "color": 4}, {"name": "Leg.R", "uuid": "6297c01c-0292-5be0-8719-9e8a6d9908ef", "bone": "Leg.R", "from": [-3.5999999046325684, 0.0, -1.7999999523162842], "to": [0.0, 10.800000190734863, 1.7999999523162842], "origin": [-1.7999999523162842, 10.799999237060547, -0.0], "color": 5}], "rest_policy": "Exact Blender rest pose; every pose channel is zero at neutral. Showcase neutral shoulder offsets are intentionally overridden by full-channel Actions.", "sha256": "54d8d663738619b8b28075f53b196f82d27b6e098c9b4a0998bb87051a9b14cc"};
// CONTRACT is prepended by build_proxy.py; no network or external dependencies.
(() => {
  const c=GAF_BRIDGE_CONTRACT;
  const fail=message=>{throw new Error(message)};
  const close=(a,b)=>a.length===b.length&&a.every((v,i)=>Math.abs(v-b[i])<1e-5);
  const rows=m=>[0,1,2,3].map(i=>[0,1,2,3].map(j=>m.elements[j*4+i]));
  function validate() {
    if (Blockbench.version!=='5.2.2') fail('This bridge is validated for Blockbench 5.2.2; validate a new version before exporting.');
    if (Format.id!=='free') fail('Open the Generic Model proxy.');
    if (Group.all.length!==c.bones.length || Cube.all.length!==c.cubes.length || Outliner.elements.length!==c.cubes.length) fail('Proxy topology changed.');
    for (const b of c.bones) {
      const g=Group.all.find(g=>g.uuid===b.uuid);
      if (!g || g.name!==b.name || (g.parent==='root'?null:g.parent.name)!==b.parent || !close(g.origin,b.origin) || !close(g.rotation,[0,0,0])) fail('Changed bone name, hierarchy, pivot or rest rotation: '+b.name);
      if (b.locked&&!g.locked) fail('Keep forearm helper locked: '+b.name);
    }
    for(const q of c.cubes) {
      const cube=Cube.all.find(v=>v.uuid===q.uuid);
      if(!cube || cube.parent.name!==q.bone || !close(cube.from,q.from) || !close(cube.to,q.to) || !close(cube.origin,q.origin) || !close(cube.rotation,[0,0,0]) || cube.inflate) fail('Changed rigid geometry: '+q.name);
    }
    return true;
  }
  function sample(animation=Animation.selected, fps=30, rate=120) {
    validate();
    if(!animation || !Animation.all.includes(animation)) fail('Select an animation.');
    if(!Number.isInteger(fps)||fps<1||fps>240||!Number.isInteger(rate)||rate<fps||rate>960) fail('Invalid FPS/rate.');
    if(!Number.isFinite(animation.length)||animation.length<=0||animation.length>600) fail('Length must be 0–600 seconds.');
    if(AnimationController.selected || animation.override || animation.blend_weight.trim() && animation.blend_weight.trim()!=='1') fail('Controllers, override and blend expressions are unsupported.');
    for(const ba of Object.values(animation.animators)) {
      if(ba.type!=='bone') fail('Only bone animators are supported; remove effects.');
      if(ba.rotation_global || ba.muted && Object.values(ba.muted).some(Boolean)) fail('Global rotation and muted channels are unsupported.');
      for(const k of ba.keyframes) {
        if(k.interpolation==='step') fail('Step/discontinuous keys need a separate bake policy; not supported in v1.');
        for(const dp of k.data_points)for(const axis of ['x','y','z'])if(dp[axis]!==undefined && !Number.isFinite(Number(dp[axis]))) fail('Molang expressions are unsupported; use numeric keyframes.');
        if(k.channel==='scale' && k.data_points.some(dp=>['x','y','z'].some(axis=>Number(dp[axis])!==1))) fail('Animated scaling is forbidden.');
        if(c.bones.find(b=>b.uuid===ba.uuid)?.locked && k.data_points.some(dp=>['x','y','z'].some(axis=>Number(dp[axis])!==(k.channel==='scale'?1:0)))) fail('ForeArm motion is forbidden.');
      }
    }
    const selected=Animation.selected,time=Timeline.time,playing=Animation.all.map(a=>a.playing);
    try {
      Animation.all.forEach(a=>a.playing=false);animation.select();Animation.all.forEach(a=>a.playing=a===animation);
      Animator.showDefaultPose();Canvas.scene.updateMatrixWorld(true);
      const rest=Object.fromEntries(c.bones.map(b=>[b.name,rows(Group.all.find(g=>g.uuid===b.uuid).mesh.matrixWorld)]));
      const duration=Math.ceil(animation.length*fps-1e-9)/fps;
      const times=new Set([0,duration]);for(let i=1;i<Math.ceil(duration*rate);i++)times.add(Math.min(i/rate,duration));
      for(const ba of Object.values(animation.animators))for(const k of ba.keyframes)if(k.time>=0&&k.time<=duration)times.add(k.time);
      const samples=[...times].sort((a,b)=>a-b).map(t=> {
        Timeline.time=t;Animator.preview();Canvas.scene.updateMatrixWorld(true);
        const matrices=Object.fromEntries(c.bones.map(b=>[b.name,rows(Group.all.find(g=>g.uuid===b.uuid).mesh.matrixWorld)]));
        const corners={};if(t===0||Math.abs(t-.5)<1e-8||Math.abs(t-duration)<1e-8)for(const q of c.cubes){const mesh=Cube.all.find(v=>v.uuid===q.uuid).mesh;const attr=mesh.geometry.attributes.position;corners[q.name]=Array.from({length:attr.count},(_,i)=>mesh.localToWorld(new THREE.Vector3().fromBufferAttribute(attr,i)).toArray());}
        return {time:t,matrices,...(Object.keys(corners).length?{corners}:{})};
      });
      return {schema:'gaf.blockbench.samples.v1',contract_sha256:c.sha256,blockbench_version:Blockbench.version,name:animation.name,fps,sample_rate:rate,duration,source_duration:animation.length,loop:animation.loop,rotation_order:Format.euler_order,rest,samples};
    } finally {
      if(selected)selected.select();Animation.all.forEach((a,i)=>a.playing=playing[i]);Timeline.time=time;Animator.preview();
    }
  }
  globalThis.GAFBlockbenchBridge={sample,validate,contract:c};
  let action;
  Plugin.register('gaf_rigid_blender_bridge',{title:'GAF Rigid Blender Bridge',author:'GameAssetFactory',version:'1.0.0',variant:'desktop',min_version:'5.2.2',description:'Export evaluated rigid poses for the existing Blender player rig. Imports remain Pending.',
    onload(){action=new Action('gaf_export_rigid_pose',{name:'Export pose/keyframes to Blender (Pending)',icon:'accessibility_new',condition:()=>Format.id==='free'&&Modes.animate,
      click(){try{const data=sample();Blockbench.export({type:'JSON',extensions:['json'],name:data.name+'.samples',content:JSON.stringify(data,null,2),savetype:'text'});}catch(error){Blockbench.showMessageBox({title:'Bridge export rejected',message:error.message});}}});MenuBar.addAction(action,'file.export');},
    onunload(){if(action)action.delete();delete globalThis.GAFBlockbenchBridge;}
  });
})();
