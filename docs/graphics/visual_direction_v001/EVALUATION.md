# Evaluating the benchmark environment

Status: proposed acceptance contract. The rubric organizes artistic judgment;
its score is not a scientific beauty percentage or a measure of MD2 fidelity.
The user remains the final art approver.

## Compare the right evidence

Use four registered gameplay views: approach, clearing, under-oak and stone/path
junction. For each same-game A/B, hold camera, player position/pose/time, wind
clock, resolution, renderer, AA, exposure and grade constant unless that exact
parameter group is the experiment. Store all state with the image. An actor
pose-phase difference must not be reported as a shader regression without
regional investigation; retain the existing checkpoint failure until resolved.

Judge the full-resolution image, a 320 x 180 thumbnail and a normal-size phone
display when available. Use a grayscale diagnostic to inspect focal values,
while judging the actual aesthetic in color. MD2 pictures are art references
with different geometry/framing; do not use cross-scene PSNR or pixel error to
score beauty.

Use a 10–15 second normal-speed clip for start/stop, turning, jump/land, shaded
movement, tree reveal and grass recovery. Review at the actual gameplay camera,
not only a flattering close-up. Check 16:9 and a representative wide-phone
aspect such as 20:9 without losing the focal composition or revealing undressed
edges. Exact device safe areas remain part of the later device pass.

## Art rubric

Score each item from 0 to 4:0 broken/unreadable,1 visibly unfinished,2 functional
but generic,3 cohesive and polished,4 distinctive and consistently excellent.
Write one observed strength and one remaining problem per item.

| Criterion | Weight | A score of3 should visibly mean |
|---|---:|---|
| Composition and eye guidance |20| Player, route and landmark have a clear hierarchy; near/middle/background work together |
| Lighting and depth |20| Warm light and cooler shade separate forms; contacts and shaded faces stay legible |
| Ground/vegetation integration |15| Banks, root soil and path edges feel connected, with no pasted-on borders |
| Materials and scale |10| Pixel clusters, roughness and dimensions share a consistent authored grammar |
| Color and accents |10| Greens/earth/stone belong together; flowers support a deliberate focal rhythm |
| Vegetation richness |10| Several scales of masses and gaps create detail without uniform clutter |
| Motion and temporal clarity |10| Breeze, passage, shadows and player presentation remain stable and coherent |
| Atmosphere |5| Distance has depth while the playable foreground remains crisp |

Compute the score as `sum(weight * rating / 4)` across the eight criteria.
Proposed art-candidate threshold:weighted score at least80/100, with every
criterion at least3. This is an internal review rule, not an already accepted
standard. A high average cannot compensate for the vetoes below. Record actual
user feedback; do not mark a scene approved because a model assigned a score.

## Hard vetoes

- The player or main route cannot be quickly located, shaded limbs disappear,
  or foreground foliage/reveal repeatedly obscures movement. Try a brief view
  and ask the reviewer to point out player, route and landmark; record confusion.
- Floating roots/rocks, ground gaps, square fade seams, detached contact shadows
  or stale lighting fields are visible at normal gameplay distance.
- Repeated shimmer, shadow popping, texture swimming, motion stutter or grass
  recovery snapping disrupt the motion clip.
- The candidate changes approved animation/controller behavior or fails baseline
  restoration/source preservation checks.
- Production-ineligible reference assets enter the benchmark build, or a device
  quality/performance claim lacks corresponding device evidence.

WorldMap has no active combat/spawn by default. Reserve a quiet central pocket
and inspect basic silhouette readability now. Full combat/VFX readability and
shipping load remain separate required checks before calling it game-ready;
do not build enemies or change combat simply to produce an attractive still.

## Promotion states

| State | Required evidence |
|---|---|
| Direction agreed | User selects mood and approves/revises this package; only mood is confirmed so far |
| Composition accepted | M1 registered views and playable path approved |
| Art candidate accepted | Rubric/veto review, four final views and motion clip approved by user |
| Environment device qualified | Measured supported device tier, sustained run and technical checks; workload explicitly environment/movement only |
| Gold graphics reference | User art approval plus documented device qualification and a frozen reusable recipe |
| Game-ready profile | Requalified with representative approved gameplay/action load and release-eligible dependencies |

If no phone is available, stop at an explicitly labelled desktop art candidate.
That candidate can inform later planning, but no phone performance or final
mobile benchmark status is inferred.

## What to record

Keep source commit, asset/profile signatures, placements, camera/viewport state,
feature toggles, still/clip paths, art review notes, known differences and a
performance session record. Separate original artistic choices, engine-specific
approximations and verified measurements. Record who accepted the result and
which exact revision they saw. Preserve failed controls and the prior baseline.
