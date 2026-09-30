# Voltaic Barrier calculation

Implemented against the custom v0.23.1 installation on 2026-09-30.

## Mechanics and model

- The wall hits every 250 ms, so its hit DPS uses 4 hits per second. Placement attack speed still controls placement and its costs.
- Projectiles fired through the wall become energised and discharge chaining lightning beams on hit. The beam is a separate triggered attack using Barrier's weapon damage, level and compatible supports.
- Beam triggers use the projectile attack selected in the Build sidebar. Its calculated attacks per second are multiplied by its accuracy chance to hit. The beam keeps its own damage, accuracy and critical calculations.
- Assumes each attack sends one qualifying projectile through the wall and hits the modeled target. Additional projectiles, chains and nearby targets do not automatically multiply single-target DPS. Extra shotgun hits, wall uptime, weapon-swap snapshots and detailed projectile paths are outside this model.
- The selected source must be an enabled direct projectile attack that collides. Minions, totems, traps, mines, triggered attacks, non-projectile components and projectiles without collision are excluded. No valid source means zero beam DPS, with an explanation when the beam is selected in Calcs.
- Wall damage is area damage. The beam's target search radius does not make its hit area damage. Concentrated Area supports the wall's area hit, not the direct beam.
- Skills has a Barrier DPS selector: wall and beams, wall only, or beams only. Old builds default to both. This controls Full DPS contribution; Lightning Arrow remains a separate entry.
- Culling Strike II applies to the compatible Barrier components. Standard Boss is Unique, with a 5% base cull threshold. Full DPS applies the strongest included cull once to the total, as an effective damage equivalent. The 20-second conditional threshold bonus is excluded as requested.
- Support gem hover comparisons always calculate Full DPS, independently of the list sorting metric.

Current extracted mechanics: [Voltaic Barrier](https://poe2db.tw/us/Voltaic_Barrier), [Culling Strike II](https://poe2db.tw/us/Culling_Strike_II). In particular, the wall interval is `voltaic_barrier_damage_interval_ms = 250`; the beam trigger is `triggered_on_voltaic_barrier_boosted_projectile_collision = 100`. Community descriptions of pellet overlap and weapon snapshots were treated as leads, not sufficient justification for automatic single-target multipliers.

Upstream issue/PR searches for Voltaic Barrier and inspection of fetched upstream/dev found no reusable implementation on 2026-09-30. The general player trigger engine is disabled there; this change adds a narrow Barrier handler without enabling unrelated triggers.

## Verification

`tests/custom_voltaic_barrier.lua`, using the existing shipped LuaJIT harness, checks source-rate coupling, independent support effects, fixed wall hit rate, component totals, Unique/Rare/normal culling, absent sources, Calcs selection, undo/redo, XML persistence, old-build defaults and actual support-hover rendering under both sort metrics. It also checks that support comparisons recalculate dependent beam DPS rather than using a stale cached result.

## Workflow inefficiencies observed

| Inefficiency | Effect | Improvement |
| --- | --- | --- |
| Broad Barrier searches | Unrelated results obscured mechanics research. | Start with exact skill name and PoE2-specific sources. |
| GitHub search returned full irrelevant issue bodies | Large results and embedded builds wasted context. | Filter titles and short summaries before opening relevant issues. |
| Old installed commit metadata despite matching Lua payload | Metadata alone suggested a stale installation. | Compare the shipped application payload before deciding to redeploy. |
| Test fixtures initially used guessed internal method names and incomplete UI cache data | Repeated fixture repairs delayed verification. | Read the current method signatures and render prerequisites before building UI fixtures. |
| First package was staged before committing | Deployment correctly rejected its dirty-source metadata. | Commit locally, then package and verify the active installation before pushing. |
| Hidden restart initially left a blank window | UI verification needed a restore/maximize cycle to force painting. | Check painting after restart before treating a running process as verified. |
