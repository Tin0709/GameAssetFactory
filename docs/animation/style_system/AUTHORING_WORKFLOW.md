# Existing authoring and review workflow

Use this route for future authorized animation work. The present knowledge task changes documentation and read-only discovery only. Consult [rig constraints](RIG_CONSTRAINTS.md), [approval/provenance](APPROVED_REFERENCES.md), the [current manifest](../../../blender/animation/showcase/animation_manifest.json) and dated [Workflow](../ANIMATION_WORKFLOW.md) before choosing a source. Work on one animation at a time and preserve current gameplay, libraries, approved Actions and comparison assets.

## From brief to review

1. Establish the intended behavior, entry/exit pose **and velocity**, support/phase, interruption, physics travel and upper-body ownership. Distinguish observed evidence, verified source behavior, measurement, inference and new proposal. Reuse an approved reference without treating its artistic approval as permission to overwrite it.
2. Author a unique versioned Action in a separate saved study. Retain exact rest rig, slots, full rigid limbs and appearance. Keep review elevation/cameras outside reusable character motion. Back up affected files and compare current hashes for concurrent work before writing.
3. Check dense poses, floor/contact, rigidity, intersections, quaternion continuity and pose/velocity seams. Verify real frame/FPS timing and distinguish playable bounds from duplicate closing samples. Review actual pixels and normal-speed playback, then save/reopen and switch between old/new clips.
4. Register the new Action **Pending in the existing Animation Showcase**. Explicit user artistic approval is the status gate. Actual Godot integration is a separately authorized step; existing recorded authorization persists and does not require another invented review gate.

## Existing entry points

From the repository root, locate an existing viewer without opening it:

```sh
python3 scripts/open_blender_viewer.py animation --dry-run
```

Its positional choices are `asset`, `player`, `animation`, `weapon`, `mobs`, `soldier`; optional `--blender-bin PATH` overrides discovery. Removing `--dry-run` opens/reuses the authorized viewer and its local UI bootstrap. See [launcher](../../../scripts/open_blender_viewer.py).

For a compatible saved study, [registration](../../../blender/animation/showcase/register_animation.py) accepts exactly six positional arguments after `--`:

```sh
blender --background SOURCE.blend --python-exit-code 1 \
  --python blender/animation/showcase/register_animation.py \
  -- ACTION RIG MESH START END FPS
```

`register_entry(action_name, rig_name, mesh_name, start, end, fps)` rejects duplicates, incompatible rest/modes, unsupported object travel, constraints/NLA/drivers and invalid Action channels. It backs up central files and appends Pending metadata. **It does not save the shared viewer.** Use addon Refresh, inspect, then let one review window save/reopen. Hash comparisons are not a general filesystem lock. The initial `build_showcase.py` is a historical three-Action builder, not a routine refresh command.

[Library helpers](../../../blender/animation/showcase/gaf_animation_library.py) already provide `curves`, `action_signature`, `rest_signature`, `validate_timing`, `validate_action`, `activate` and `refresh`. Existing contact recipes include `walk_expressive_test/build_walk.py:sole_matrix/pose` and `lowerbody_recovery_test/build_test.py:leg_matrix/set_pose`. Study render scripts remain beside them; importing these recipes can write files. Reuse their documented recipes deliberately instead of introducing a competing authoring framework.

The [Blockbench bridge](../../../blender/animation/blockbench_pipeline_v1/README.md) offers `import_clip(existing_rig, clip_json, contract_json)` and background `import_to_review.py -- CLIP.samples.json [Unique_Action_Name]`. It creates a unique source and Pending registration; the review window still owns viewer saving.

## Authorized runtime and discovery

The existing rifle exporters `export_approved.py`, `export_aim.py`, `export_recoil.py` accept `--stage EXTERNAL_DIR [--repo ROOT] [--manifest FILE]`. Their matching `build_library.gd`, `build_aim_library.gd`, `build_recoil_library.gd` consume the external stage through Godot `--script ... -- EXTERNAL_DIR`. Follow [current integration notes](../../../game_mobile_3d/scenes/dev/actions_stuff_research/rifle_ready_v001/README.md) only within authorized scope; retain research exclusion and source hashes.

`python3 scripts/animation_knowledge.py [--root ROOT] [--json] lookup [TOPIC]` lists topics or routes. Use `check` without the archive; `verify [--pack FILE]` checks pinned source bytes and pointers. `--root` and `--json` also work after a subcommand. These read-only tools complement existing authoring, source-index, preview, registration and export routes; they never open/save Blender, create Actions, export assets or change approval.
