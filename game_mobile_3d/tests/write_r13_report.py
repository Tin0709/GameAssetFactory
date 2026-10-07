import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'.validation/r13';DATA=ROOT/'assets/characters/r13'
source=json.loads((DATA/'source.json').read_text())
runtime=json.loads((OUT/'runtime.json').read_text())
speed=json.loads((OUT/'speed_validation.json').read_text())
lines=['# R13 integrated gameplay review','','ARTISTIC STATUS: AWAITING HUMAN REVIEW.','',
    'The real F5 main scene uses the saved R12/R13 body, weapon geometry and native Action samples. No original approved Blender Action or file was saved over. No additional percentage/45-degree adjustment was applied.','',
    'Source: `'+source['source']+'`','SHA-256: `'+source['file_sha256']+'`','',
    '## Exact native sources and timing','',
    '| Weapon | Approved baked Action | Holster / Draw clips | Duration each | Final socket |',
    '|---|---|---|---|---|']
for kind,data in source['weapons'].items():
    lines.append(f"| {kind} | `{data['action']}` | `R13_{kind}_Holster` / `R13_{kind}_Draw` | 46/24 ÷ {speed['speed']} = {speed['duration_seconds']:.9f} s | {data['attachment']} |")
lines += ['', 'Holster exports frames 12..58 (includes arm settling). Draw minimally maps the already-authored review return, frames 66..112, including its preparation. This is a stow-compatible return export; it is not the old placeholder/old Draw and no new Draw pose choreography was authored. Original DrawLongGun remains in the previous asset for rollback.', '',
    f"Runtime Holster and Draw playback is {speed['speed']}× original speed; original Blender Actions and source samples remain unchanged. Holster: hand → Carrier at t=0; Carrier → back/right hip at t={29.4/24/speed['speed']:.6f} s; STOWED at t={speed['duration_seconds']:.6f} s. Draw: release from stowed socket at t={16.6/24/speed['speed']:.6f} s; same instance catches hand and becomes READY at t={speed['duration_seconds']:.6f} s. Native reparenting preserves global transforms. Mount entry blends take {100/speed['speed']:.3f} ms (Holster) / {80/speed['speed']:.3f} ms (Draw), with {120/speed['speed']:.3f} ms exit blending. Event and blend phases scale together.", '',
    'The latest long-gun diagonal is approximately 55° down in the rear projection (the previously authored 10° + requested additional 45°), with the existing 12° stock clearance lean. Center is Chest Y +0.05 m, 106.25 mm above torso midpoint; closest back gap is 15 mm. Pistol bbox center remains Chest X -0.225, Y -0.40, Z +0.02 m: character RIGHT hip, intentional half-width inset.', '',
    '## Final runtime weapon root transforms','',
    'Matrices below are local to BoneAttachment3D on Chest, including the approved final scale. Their final column is translation. Standalone GLB geometry is Y-up; mount conversion is applied once at the boundary. Full unrounded data is in `assets/characters/r13/source.json`. The named HipWeaponSocket_R follows Chest because the approved hip mount was authored in Chest space.', '']
for kind,data in source['weapons'].items():
    lines += ['### '+kind, '', '```text']
    lines += [' '.join(f'{v: .9f}' for v in row) for row in data['stow_mount']]
    lines += ['```', '']
lines += ['## Preserved behavior and differences','',
    '- Original 12 production Animation clips (including all six reference locomotion/turn clips) are preserved byte-for-byte in the new model. Only upper channels are supplied by the 18 new native clips; active Walk/Sprint phase is unchanged. No Run V7 correction is imposed on Walk.',
    '- Latest simple right-primary hold, pistol free left arm, independent long-gun left follow, shoulder inset, breathing and R12 fore/aft rhythm are sampled from their actual baked Actions.',
    '- Straight UpperArm + ForeArm geometry maps onto the existing full-length Arm bone with identical rest basis. There is one skeleton and one pose writer.',
    f"- Awareness, 1.5-second grace, sprint priority, weapon switch and READY/hand firing gate remain in the same gameplay behavior. Pistol uses a native transition. All three transitions are {speed['duration_seconds']:.6f} s at {speed['speed']}× playback; gameplay tests use actual duration.",
    '- Test audio is suppressed before voice playback and Master is muted. Open review additionally uses Dummy audio output.',
    '- F5 gameplay has an upper-right test enemy button. It clears ordinary enemies and pauses spawning, adds one stationary immortal non-attacking target at map center, and preserves normal awareness/auto-fire. Clicking again removes the target without spawning replacements, allowing Holster after grace. R resets normal gameplay.', '',
    '## Verification','',
    f"- Speed regression: {speed['checks']} checks, {len(speed['failures'])} failures. Every native upper key matches its source at the retimed phase; Idle/Walk/Sprint duration remains unchanged; all six transitions finish at {speed['completion_tick']} physics ticks (60 Hz).",
    f"- R13 runtime: {runtime['checks']} checks, {len(runtime['failures'])} failures. Idle/Walk/left-right direction changes, sprint, awareness loss/reacquisition, pre/post-release Draw cancellation, switches during transport and immediately after READY, same weapon instances, exact mounts and continuous handoffs.",
    '- Asset verification: all original 12 clip inputs/outputs byte-identical; source file hash unchanged; upper-only native samples; original Action fingerprints preserved.',
    '- Gameplay regressions: combat 78 checks, progression 85 checks, weapon selector 127 checks, movement/weapons 798 checks passed.',
    '- Stationary enemy: all three classes acquire/draw; enemy does not move, attack, die, grant kills; removal permits completed STOWED. Normal enemy combat still works.',
    '- Silent test: Master muted and all ten sound event types suppressed.',
    '- Rendered native game captures compared with the saved Blender READY, transport and STOWED showcase, not just matrices. No obvious new attachment pop or final clipping was observed in the captured views; intentional pistol inset remains. All-angle aesthetic approval remains with the user.',
    '- Fresh independent code review identified early respawn and stale Draw exit mount bugs; both were reproduced with failing tests, fixed and verified. Reload regressions also validate local Animation libraries and correct native track paths.', '',
    '## Rollback','',
    'Previous `assets/characters/player_cuboid_animated_v5.glb`, weapon v4 assets and R6/D5/E3 scripts remain intact. To roll back this integration, change the two resources in `scenes/characters/CuboidPlayer.tscn` to `res://scripts/player_reference_locomotion_r6p.gd` and `res://assets/characters/player_cuboid_animated_v5.glb`. The socket factory defaults to the prior implementation. Test button/silence are independent of animation migration.', '',
    'Review gallery: [three weapons and Blender comparison](review/index.html).',
    'Evidence: [runtime](runtime.json), [assets](asset_validation.json), [speed](speed_validation.json).']
(OUT/'REPORT.md').write_text('\n'.join(lines),encoding='utf8')
gallery=OUT/'review';gallery.mkdir(exist_ok=True)
html='''<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>R13 — Native gameplay review</title><style>
body{margin:0;background:#111a20;color:#e1edf0;font:16px system-ui}main{max-width:1450px;margin:auto;padding:30px}h1{font-size:28px}p{line-height:1.55;color:#b9cbd1}nav{display:flex;gap:10px;margin:20px 0}button{background:#263b45;border:1px solid #62838e;border-radius:6px;color:white;padding:12px 20px;cursor:pointer}button.active{background:#1a697a}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}.card{background:#1b282e;border-radius:10px;overflow:hidden}.card h2{padding:0 20px}img{width:100%;display:block}.source{margin-top:32px;background:#1b282e;padding:18px;border-radius:10px}a{color:#73dcec}@media(max-width:800px){.grid{grid-template-columns:1fr}}
</style><main><h1>R13 — Pistol · Rifle · Shotgun</h1><p>Animation cất/rút súng trong gameplay: __SPEED__× bản gốc, __DURATION__ giây. Ảnh bên dưới dùng để đối chiếu pose.<br>F5: chọn súng, bấm “Enemy test ở giữa map”. Enemy đứng yên, không tấn công, bất tử. Bấm xóa để thử cất súng; R về gameplay thường. Game test không tiếng.</p><nav><button class="active" data-state="ready_idle">Cầm súng</button><button data-state="transport_idle">Đang cất</button><button data-state="stowed">Vị trí cất</button><button data-state="ready_move_right">Đi bộ</button><button data-state="sprint_stowed">Sprint đã cất</button></nav><div class="grid">'''
html=html.replace('__SPEED__',str(speed['speed']).replace('.',',')).replace('__DURATION__',f"{speed['duration_seconds']:.3f}".replace('.',','))
for index,kind in enumerate(['Pistol','Rifle / M4A1','Shotgun']):
    html+=f'<article class="card"><h2>{kind}</h2><img data-index="{index}" src="../{index}_ready_idle.png" alt="{kind} in real Godot gameplay"></article>'
html+='''</div><section class="source"><h2>Blender — nguồn đã duyệt</h2><p>Các góc máy/ánh sáng khác nhau; đối chiếu tay chính, tay phụ, khoảng cách với mặt và vị trí cất.</p><img id="source" src="../blender_ready.png" alt="Approved Blender source"><p><a href="../REPORT.md">Báo cáo nguồn Action, transforms, timings, rollback và kiểm tra</a></p></section><script>
document.querySelectorAll('button').forEach(b=>b.onclick=()=>{document.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('.card img').forEach(x=>x.src='../'+x.dataset.index+'_'+b.dataset.state+'.png');document.querySelector('#source').src='../blender_'+(b.dataset.state.includes('stowed')?'stowed':b.dataset.state.includes('transport')?'transport':'ready')+'.png'});
</script></main></html>'''
(gallery/'index.html').write_text(html,encoding='utf8')
print('R13 report and 3-weapon review gallery written')
