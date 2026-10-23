# GameAssetFactory animation knowledge system

Verified 2026-10-23. Purpose: design **original** expressive voxel animation using audited motion principles, the actual selected rig/weapon and the established Blender → review → Godot workflow. This milestone adds knowledge and read-only discovery; it creates no Action or gameplay change.

## Start small

Read the [Director Skill](../../../.agents/skills/gaf-animation-director/SKILL.md), [Motion Bible](MOTION_STYLE_BIBLE.md) and [Rig Constraints](RIG_CONSTRAINTS.md), then only the relevant route:

| Task | Load next |
|---|---|
| Locomotion, starts/stops, jumping | [Timing](TIMING_AND_SPACING.md), [Weight](WEIGHT_AND_BODY_MECHANICS.md), [Transitions](TRANSITION_RULES.md) |
| Bounce, arcs, expressive follow-through | [Patterns](SNAPPY_BOUNCY_PATTERNS.md) plus the relevant principle in Timing/Weight |
| Rifle, ranged or weapon-ready motion | [Weapon Handling](WEAPON_HANDLING.md), [Approved References](APPROVED_REFERENCES.md) |
| Melee, combo, skill, reaction, enemy | [Combat Design](COMBAT_ANIMATION_DESIGN.md), Weapon Handling and the named [source evidence](SOURCE_EVIDENCE.md) |
| Blender creation/review | [Authoring Workflow](AUTHORING_WORKFLOW.md), exact live manifest/source/slot |
| Authorized gameplay integration | [Godot Integration](GODOT_INTEGRATION.md), Transitions, actual current scripts |
| New research or uncertain source claim | [Evidence](SOURCE_EVIDENCE.md), [Gaps and demonstrations](GAPS_AND_DEMOS.md), then only relevant pack paths |

**S** = literal verified source; **O** = observed pixels; **A** = project adaptation; **P** = original artistic proposal; **U** = unknown. A source mechanism does not prove an artistic explanation. Artistic approval, technical validation, integration authorization and commercial provenance are independent.

## Read-only discovery

Use Python3.11+ from the repository root; no Blender/Godot process is started:

```sh
python3 scripts/animation_knowledge.py lookup
python3 scripts/animation_knowledge.py lookup combat
python3 scripts/animation_knowledge.py check
python3 scripts/animation_knowledge.py verify
```

`lookup` routes a topic to documents and source pointers. `check` validates routing/document availability and reports current manifest metadata without needing the pack. `verify` hashes the pinned local archive and members, checks internal version and resolves selected RFC6901 JSON pointers. `--root ROOT`, `--json` and `verify --pack FILE` support another checkout/location. It does not certify aesthetic quality, licensing, complete graph coverage, native rig correctness or phone performance. Stale/missing evidence fails explicitly; never silently refresh a pin to make a check pass.

The compact [evidence index](evidence.json) stores paths/hashes/pointers, not a replacement copy of proprietary animation data. Existing [source-index generator](../../../scripts/research/generate_actions_stuff_source_index.py) remains the deeper research route. Preserve its caches and all existing authoring tools.

## Durable maintenance

For each future task, record the chosen rig/rest basis, weapon/grips, source IDs, original design decisions, playable timing/closing sample, entry/exit pose and velocity, support, event authority, interruptions and provenance. Use the live [manifest](../../../blender/animation/showcase/animation_manifest.json); dated documents are snapshots.

New original Actions remain independent and Pending in the existing appropriate Showcase. Review actual normal-speed pixels before declaring artistic quality. Integrate only when authorized; preserve prior valid authorization. Do not replace production WorldMap or build another test project. When evidence changes, update the smallest affected document/pointer and rerun discovery checks; retain uncertainty rather than invent source behavior.
