"""Package actual Godot captures and measured verification for human review."""
import json,statistics
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'.validation/r15'
runtime=json.loads((OUT/'runtime.json').read_text())
assets=json.loads((OUT/'asset_validation.json').read_text())
source=json.loads((ROOT/'assets/characters/r15/source.json').read_text())
evidence=json.loads((OUT/'render_evidence.json').read_text())
assert not runtime['failures'] and assets['passed']
assert len(evidence)==150 and all(r['weight']>.99 for r in evidence)
gallery=OUT/'review';gallery.mkdir(exist_ok=True)
clips={}
for weapon,name in enumerate(['Pistol','Rifle / M4','Shotgun']):
    for direction in ['right','left']:
        rows=[r for r in evidence if r['weapon']==weapon and r['direction']==direction]
        assert all(r['strafe_direction']==(1 if direction=='right' else -1) for r in rows)
        # Render capture waits advance the real game. Derive display timing from
        # recorded authored phase instead of accelerating the exported footage.
        step=statistics.median((b['phase']-a['phase'])%1 for a,b in zip(rows,rows[1:]))
        duration=max(10,round(step*(20/24)*1000/10)*10)
        frames=[Image.open(p).convert('RGB') for p in sorted((OUT/'frames').glob(f'{weapon}_{direction}_*.png'))]
        assert len(frames)==25
        path=gallery/f'{weapon}_{direction}.gif'
        frames[0].save(path,save_all=True,append_images=frames[1:],duration=duration,loop=0,optimize=False)
        with Image.open(path) as gif:assert gif.n_frames==25
        clips[path.name]={'frames':25,'frame_ms':duration,'bytes':path.stat().st_size}
(OUT/'preview_validation.json').write_text(json.dumps(clips,indent=2))
report=f'''# R15 — Combat Strafe integration

Integrated into the actual F5 main scene, `CuboidGameplayTest.tscn`, on the latest R13 body/weapon assets. This pass exports and composes existing Actions; it does not author new stepping.

## Confirmed source and export

- Saved Blender file: `{source['source']}`.
- SHA-256: `{source['source_sha256']}`. Source file and all original Actions preserved.
- Actions: `Combat_StrafeLeft_V1`, `Combat_StrafeRight_V1`, frames 1..21 including closure; 20-frame cycle at 24 FPS = **0.833333 seconds**.
- Study rig: `R14_Right_Rig`; animated Hips, Leg.L, Leg.R and Spine rest bases/hierarchy match `Player_Cuboid_Rig`. The game retains the R13 production rig and its approved straight-arm geometry.
- Tracks: Hips position/rotation, Leg.L position/rotation, Leg.R position/rotation, Spine rotation. No Root travel, scale, arm, Chest, Head or weapon tracks.
- Versioned export: `assets/characters/r15/player_r15_combat_strafe_v1.glb`, **32 clips**: unchanged 12 prior GLB gameplay clips, 18 native R12/R13 clips, two native strafes. R13 mesh, skin, material, node/rest data and original clip buffers stay exact.
- Godot import: 192 Hz with key optimization disabled; 161 samples per track. Post-import retains the 12 previous imported clips exactly and strips unrequested generated strafe channels. Maximum imported position error **{runtime['max_import_position_error_m']:.12g} m**, minimum quaternion dot **{runtime['min_import_rotation_dot']}**.

## Runtime behavior

- Existing auto-combat query supplies the target. No new enemy scan/registry or duplicate targeting layer.
- Normal walking + READY + valid target + lateral movement + no sprint requests strafe. A lateral share of at least 65% enters; 55% retains it to avoid direction chatter. Diagonal WASD movement is supported when lateral motion dominates.
- Movement remains world-space WASD; the Visual continues smoothly facing the combat target. Character RIGHT is -X for the +Z-facing model. Left uses its own saved Action; no mirroring or reverse playback.
- Native leg timing is preserved: leading leg swings frames 1..8, trailing leg follows frames 11..18, with the authored 14 mm hip bounce and Spine counterbalance.
- Pose transitions blend over 0.14 seconds; reversals capture the current lower pose and enter the opposite Action at its leading-step phase. The original R6 Walk/Sprint clock keeps running. Forward movement/no target returns to existing locomotion; Sprint suppresses target-facing strafe and keeps the existing stow priority.
- Torso yaw is measured from final evaluated Chest/Hips horizontal headings. Above 12° it smoothly approaches 19.5°, leaving numeric margin below the 20° requirement. Lower yaw is corrected toward upper yaw, with inverse Chest correction preserving upper aim; there is no abrupt hard bone clamp.
- Partial-gait composition now recomputes Chest counterrotation after Hips replacement. This preserves weapon/upper heading during start, stop, reversal and sprint release.
- Weapon mounts, scales, right-primary hold, independent support-arm motion, pistol free arm, recoil and fire gating remain active. Stow/draw remains **5.25× original speed, 0.365079 seconds**, with its socket events synchronized.
- Audio remains muted; F5's stationary, immortal, non-attacking enemy button remains available.

## Verification and review

- R15: **{runtime['checks']} checks, zero failures**. Maximum sampled relative torso yaw **{runtime['max_torso_twist_deg']:.5f}°**. Covers every native sample and every preserved imported key, all three weapons, left/right/diagonal behavior, stop, target loss/change, recoil, sprint and per-frame upper heading during transitions.
- R13 full cycles: 8,280 checks; speed/native sample parity: 22,141; movement/weapons: 798. Combat: 78; selector: 127; progression: 85. All passed. Stationary enemy and silent-test regressions also passed.
- Independent review reproduced a partial-blend heading error; the correction and failing regression were verified. The follow-up probe measured maximum heading deviations 3.11° on stop, 2.79° on restart, 1.98° on reversal and 4.03° on sprint release; no remaining critical/important findings.
- Actual D3D12 gameplay captures: 150 images, all at full strafe weight, correct authored direction for every image; six animated clips decoded successfully. These show the real targeting/movement/state machine, not a separate pose simulation.

**Preserved speed limitation:** the short Blender shuffle was authored with 0.192 m/s preview travel (0.16 m per cycle), while actual combat movement remains 2.6 m/s. The integration deliberately retains gameplay speed and authored cadence; exact ground planting at that speed is not achieved, so visible foot sliding remains. Correcting stride distance/cadence is a separate animation or locomotion decision.

Human visual review remains pending. [Six gameplay previews](review/index.html), [runtime evidence](runtime.json), [asset validation](asset_validation.json), [render measurements](render_evidence.json).

## Rollback

The R13 GLB/scripts remain intact. Change `CuboidPlayer.tscn` Visual script back to `player_weapon_r13_integration.gd` and Model to `assets/characters/r13/player_r13.glb`. No original Blender source needs restoration.
'''
(OUT/'REPORT.md').write_text(report,encoding='utf8')
html='''<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>R15 · Combat Strafe</title><style>body{background:#111b24;color:#e6edf2;margin:0;font:16px system-ui}main{max-width:1400px;margin:auto;padding:28px}h1{font-size:30px}p{line-height:1.6;color:#b9cbd6}.row{display:grid;grid-template-columns:1fr 1fr;gap:18px}article{background:#1b2c39;border-radius:10px;overflow:hidden}h2{padding:0 18px;font-size:20px}img{width:100%;display:block}button{padding:12px 20px;background:#223e53;border:1px solid #51768a;border-radius:7px;color:white;cursor:pointer;margin:0 8px 20px 0}button.active{background:#176a74}a{color:#88dcf1}.note{border-left:3px solid #e5b468;padding:12px 18px;background:#23303a}@media(max-width:800px){.row{grid-template-columns:1fr}}</style><main><h1>R15 — Combat Strafe trong gameplay thật</h1><p>Giữ hướng về enemy khi đi ngang. Hai Action Blender riêng biệt; giữ asset súng mới nhất, cất/rút 0,365 giây. Bản game review chạy không tiếng.<br>Trong F5: chọn súng, bấm nút enemy test; dùng A/D để thử strafe, Shift để thử Sprint. Hướng trái/phải bên dưới tính theo nhân vật.</p><nav><button class="active" data-weapon="0">Pistol</button><button data-weapon="1">Rifle / M4</button><button data-weapon="2">Shotgun</button></nav><div class="row"><article><h2>Combat Strafe Right</h2><img id="right" src="0_right.gif" alt="Actual Godot right strafe"></article><article><h2>Combat Strafe Left</h2><img id="left" src="0_left.gif" alt="Actual Godot left strafe"></article></div><p>GIF ghi gameplay bằng input thật; phát lại đoạn ngắn để review. Camera theo nhân vật; enemy test vẫn đứng tại tâm map.</p><p class="note">Nhịp chân giữ đúng Action 0,833 giây; tốc độ combat giữ 2,6 m/s. Stride gốc ngắn nên còn trượt chân so với mặt đất. Không thay tốc độ/biên độ bước trong lần tích hợp này.</p><p><a href="../REPORT.md">Nguồn rig/Action, kiểm tra, giới hạn và rollback</a> · <a href="../runtime.json">Kết quả runtime</a></p><script>document.querySelectorAll('button').forEach(b=>b.onclick=()=>{document.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));for(const d of ['right','left'])document.querySelector('#'+d).src=b.dataset.weapon+'_'+d+'.gif'})</script></main></html>'''
(gallery/'index.html').write_text(html,encoding='utf8')
print('R15 report + six verified native gameplay GIFs:',json.dumps(clips))
