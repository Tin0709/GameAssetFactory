# R6-P production locomotion integration plan

Spec: user's PHASE R6-P request. Work in the existing workspace and leave the real game open in REFERENCE mode.

1. Inspect the production sole pose writer, weapon layers and R5 C. Record baseline regressions and preserve the old production scene for exact Legacy comparisons. Write focused expected-behavior tests, run RED for missing integration before changing runtime logic.
2. Generate safe approved-action copies without source changes. Add their six clips to a new versioned v5 GLB based on v4; retain v4 mesh/rig/skin and every prior animation byte-for-byte. Validate before import. Use a dedicated importer to retain exact old native clips and dense new curves.
3. Add a small reference extension plus base pose hook, keeping the old pose branch intact. Shared normalized phase samples six clips; normal movement uses Walk and the controller's fast_sprinting flag selects Sprint. Preserve controller facing/input/speeds. Port R5 C: normalization 1.20 rad/s, signed exponent 1.35, filter 0.10s, gait blend 0.14s. Idle and weapon layer/state/event paths remain intact; prohibit Run-specific Ready correction on reference gait.
4. Run focused GREEN, relevant regressions, natural gameplay input/weapon scenarios and rendered production/lab comparisons. Resolve failures or explicitly identify unresolved baseline issues without declaring regression success. Record cost and visual limits; set up debug F6 Legacy/Reference toggle and leave real game in Reference.

Review focus: exact Legacy pose parity, animation-mask preservation, signed wrap at all headings, gait continuity across weapon events, READY arm/socket integrity despite torso lean, Sprint priority and firing gates, absence of duplicate live skeletons/weapons, production gameplay files unchanged outside the documented integration surface.
