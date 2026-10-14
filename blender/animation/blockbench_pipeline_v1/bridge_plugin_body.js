// CONTRACT is prepended by build_proxy.py; no network or external dependencies.
(() => {
  const c=GAF_BRIDGE_CONTRACT;
  const fail=message=>{throw new Error(message)};
  const close=(a,b)=>a.length===b.length&&a.every((v,i)=>Math.abs(v-b[i])<1e-5);
  const rows=m=>[0,1,2,3].map(i=>[0,1,2,3].map(j=>m.elements[j*4+i]));
  function validate() {
    if (Blockbench.version!=='5.2.2') fail('This bridge is validated for Blockbench 5.2.2; validate a new version before exporting.');
    if (Format.id!=='free') fail('Open the Generic Model proxy.');
    if (Group.all.length!==c.bones.length || Cube.all.length!==c.cubes.length || Outliner.elements.length!==c.cubes.length+c.preview_meshes.length) fail('Proxy topology changed.');
    for (const b of c.bones) {
      const g=Group.all.find(g=>g.uuid===b.uuid);
      if (!g || g.name!==b.name || (g.parent==='root'?null:g.parent.name)!==b.parent || !close(g.origin,b.origin) || !close(g.rotation,[0,0,0])) fail('Changed bone name, hierarchy, pivot or rest rotation: '+b.name);
      if (b.locked&&!g.locked) fail('Keep forearm helper locked: '+b.name);
    }
    for(const q of c.cubes) {
      const cube=Cube.all.find(v=>v.uuid===q.uuid);
      if(!cube || cube.parent.name!==q.bone || !close(cube.from,q.from) || !close(cube.to,q.to) || !close(cube.origin,q.origin) || !close(cube.rotation,[0,0,0]) || cube.inflate) fail('Changed rigid geometry: '+q.name);
    }
    for(const q of c.preview_meshes){const m=Mesh.all.find(v=>v.uuid===q.uuid);if(!m||m.parent.name!=='WeaponCarrier'||!m.locked||!close(m.origin,q.origin)||!close(m.rotation,[0,0,0]))fail('Changed rifle reference mesh');}
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
        if(k.data_points.length>1 && k.data_points.slice(1).some(dp=>['x','y','z'].some(axis=>Number(dp[axis])!==Number(k.data_points[0][axis])))) fail('Distinct pre/post values are discontinuous and unsupported in v1.');
        if(k.interpolation==='step') fail('Step/discontinuous keys need a separate bake policy; not supported in v1.');
        for(const dp of k.data_points)for(const axis of ['x','y','z'])if(dp[axis]!==undefined && (!Number.isFinite(Number(dp[axis]))||!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(String(dp[axis])))) fail('Use ordinary decimal literals; Molang and scientific notation are unsupported.');
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
