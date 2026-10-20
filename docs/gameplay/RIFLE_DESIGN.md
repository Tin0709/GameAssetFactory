# Rifle gameplay decisions

## Infinite ammunition — permanent user decision, 2026-10-20

The rifle has **infinite ammo**. Do not add magazine depletion, reserve-ammo limits, reload mechanics, reload animations or reload interruptions. Continuous held firing is limited by a controlled fire interval, not ammunition. Retain responsive movement and the approved weapon/contact/camera behaviour. Future authorized rifle work follows this rule unless the user explicitly changes it.

The current implementation is confined to the existing `res://scenes/dev/ActionsStuffWalkRunTest.tscn`; production WorldMap is unchanged. LMB fires, RMB aims, R resets. Current dev cadence is6Hz/360RPM to preserve the complete approved recoil recovery, while Walk2.70/Run~7.55m/s and physics/camera remain unchanged. Reuse existing combat feedback and bounded pools; avoid per-shot object construction, frame-stall shot backlogs and cumulative pose offsets.

Read `docs/animation/reviews/rifle_continuous_fire_v001/README.md` for the accepted source hashes, adapter, tests and limitations. The research export exclusion remains mandatory; this does not authorize proprietary source data in commercial production.
