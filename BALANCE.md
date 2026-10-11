# Balance and tuning

Balance settings live in `scripts/consts.gd`. A run has ten one-minute waves. Survive ten minutes to win. The dormant boss prototype remains unused, and remaining enemies do not need to be cleared after the timer ends.

Spawning uses a MegaBonk-inspired population director. Time sets a target living population and maximum spawn-credit income. A thin crowd earns credits quickly; replenishment slows as the crowd fills and stops at the target. Killing enemies frees slots, so builds that clear quickly encounter more enemies and can earn more XP. Enemy health changes by wave; previously spawned enemies retain their original health. Every enemy type moves at a constant **3.2 units/second**.

| Wave | Time | Normal population target, start → end | Maximum credits / second, start → end | Primary HP |
| --- | --- | ---: | ---: | ---: |
| 1 | 0:00–1:00 | 12 → 18 | 0.40 → 0.50 | 100 |
| 2 | 1:00–2:00 | 18 → 26 | 0.50 → 0.65 | 100 |
| 3 | 2:00–3:00 | 26 → 40 | 0.65 → 1.00 | 180 |
| 4 | 3:00–4:00 | 40 → 60 | 1.00 → 1.50 | 260 |
| 5 | 4:00–5:00 | 60 → 90 | 1.50 → 3.00 | 350 |
| 6 | 5:00–6:00 | 90 → 130 | 3.00 → 12.00 | 450 |
| 7 | 6:00–7:00 | 130 → 180 | 12.00 → 30.00 | 550 |
| 8 | 7:00–8:00 | 180 → 230 | 30.00 → 60.00 | 650 |
| 9 | 8:00–9:00 | 230 → 280 | 60.00 → 20.00 | 800 |
| 10 | 9:00–10:00 | 400 → 400 (final swarm) | 40.00 → 40.00 | 10,000 |

Timed swarms run at **2:30–3:00, 5:00–5:30 and 7:30–8:00**. They multiply the population target by 1.5 and maximum credit income by 2. The final minute sustains a **400-enemy target** with up to **40 credits/second**. Targets and base income interpolate between minute boundaries. The HUD announces swarms and shows the actual living count. When a swarm ends, its surviving enemies remain and replenishment waits until the crowd falls below the normal target.

## Research and adaptation

The [Bonk Tuner author's documentation](https://www.nexusmods.com/megabonk/mods/151) describes separate enemy-target, spawn-interval and credit-income controls. Its [patch source](https://github.com/ZeusesNeckMeat/BonkTuner/blob/main/Patches.cs) directly patches MegaBonk's `StageSummoner.GetNumTargetEnemies`, `StageSummoner.GetSummonInterval` and summoner credit income. The [modifier service](https://github.com/ZeusesNeckMeat/BonkTuner/blob/main/Services/EnemyModifierService.cs) confirms those controls. MegaBonk's [developer patch notes](https://steamcommunity.com/app/3405340/allnews/) describe a distinct final swarm and changes intended to prevent excessively long runs.

These primary sources establish the target/interval/credit structure and final-swarm concept, but do not publish the complete original director formulas. Population-deficit feedback, unit cost per enemy, numerical curves, swarm timings, distances and the 400-enemy limit here are an original adaptation for this arena and ten-minute objective. No MegaBonk or mod source code or assets are incorporated.

## Spawn geometry

All enemies, including the initial seven, spawn in compact clumps. The director banks enough credits for **3–6 enemies**; the last one or two available population slots can still be filled. Larger batches split evenly across several clumps, and the initial seven arrive as groups of four and three. Members share an anchor and sit on a **2.6-unit radius** ring, giving even the largest six-member group enough spacing to emerge without overlapping.

Every member stays **18–28 horizontal units from the player's current position** and inside `x/z = ±46`. Anchors reserve the entire clump's radius from both the annulus boundaries and the walls. The walls' inner faces are at ±47.5, leaving clearance for the largest enemy's roughly 0.89 half-width.

When horizontal speed is at least **0.5 units/second**, **80% of clumps prefer a ±60° cone around actual movement velocity**. The remaining clumps sample all directions, so enemies still arrive from the sides and rear. This follows strafing, retreating and dashing independently of camera facing. Stationary players and vertical jumps use all horizontal directions. A forward-biased search tries 32 positions in the cone before trying 32 in all directions, allowing wall-blocked travel to fall back to available space. If all candidates fail, the anchor goes toward the arena centre at the minimum reserved distance.

Enemies begin fully underground, then rise smoothly over **0.8 seconds**, with a **0.07-second stagger** between clump members. Their health bars appear at the end. While rising they count toward population limits, remain grounded, and have no contact/projectile collider; chasing, contact damage, knockback, vortex capture and ricochet targeting start after emergence. Pause and upgrade menus pause the rise. Global ability damage can still affect the emerging enemies.

`tests/spawn_presentation_test.gd` checks initial and credit-batched groups, spacing, wall and annulus bounds, movement bias in four directions, stationary coverage, the rise/stagger, paused animation and collider/ricochet activation. Its optional `--capture` mode records buried, rising and emerged frames using the compatibility renderer.

## Difficulty calculations

Every 0.25 seconds, the director counts living enemies and computes `deficit = (target − alive) / target`. Below the target, credit income is `maximum_rate × clamp(2 × deficit, 0.15, 1)`. Each enemy costs one credit. Once enough credits exist for a clump (or the remaining slots), the director spends whole credits without exceeding the target and retains the fractional remainder. At or above the target, income and stored credit become zero. Defeated enemies release their slots immediately, including nodes awaiting deletion. No build stats are inspected and no health/speed adjustment is applied.

There is no fixed number of enemies per wave: totals depend on clearing speed. Integrating maximum income gives an upper bound of roughly **11,298 enemies including the initial seven**. Actual totals are lower as population feedback slows or stops spawning. Ordinary slow frames retain fractional credit; recovery after long stalls is limited to eight ticks, 32 stored credits and 32 new enemies per frame. This replaces unlimited spawn debt to protect the Web build from an overdue spawn avalanche. The director's living population never exceeds 400.

Base expected damage is `damage × projectiles hitting × attack_speed / 0.65 × (1 + crit_chance)`. Base DPS is `100 / 0.65 × 1.05 = 161.5`; at 70% accuracy it is 113 DPS, above the opening maximum load of 40–65 HP/second. The first two minutes spawn only 100 HP red cubes.

The final tier has **10,000 HP**. In wave ten, 85% have 10,000 HP and 15% have 800 HP: mean health is **8,620 HP**. Maximum incoming health for an empty final crowd is `40 × 8,620 = 344,800 HP/second`; income slows as the crowd fills and stops at 400 living enemies. Ricochets, explosions and abilities add crowd damage; spread, travel time, walls and missed volleys reduce effective damage. Surviving the timer does not require clearing every spawn.

Walking reaches 9 units/second and full bunny hopping reaches 18. Enemy speed remains `ENEMY_SPEED = 3.2`; increased pressure comes from population targets, swarm surges and health.

## Run results

Victory and death release the mouse and replace the arena with `results.tscn`. The screen shows total damage dealt, enemies defeated, survival time, wave and level reached, damage taken, biggest hit, most kills in one attack, attacks used and the final build. Play Again / R starts a fresh run; Back To Lobby / Esc returns to the menu.

Total damage measures enemy health actually removed, excludes overkill and includes nonlethal hits, explosions, mega fireballs and Star Power. Biggest hit retains the full attack damage. Damage taken measures health actually lost, including lethal hits capped to remaining health. The results snapshot survives scene changes in `RunStats.last_run`; new runs reset it, while personal records remain saved.

## XP progression and build display

Every defeated enemy drops **one blue ball worth 12 XP**. Previously enemies dropped two to four 12-XP balls. The sphere has a brighter unshaded core and a shared soft additive glow billboard, so its glow is visible with the Web compatibility renderer without adding a light for every pickup.

XP magnets first spawn at **2:00** and repeat every **120 seconds**. Each magnet still pulls all XP balls currently on the map. The historical XP/vortex playtests below used the previous 7-second first magnet / 14-second repeat schedule; their collection and survival outcomes do not measure this reduced magnet availability.

The cost to advance from level `L` is `100 + 42 × (L − 1) + 10 × (L − 1)²`. Reaching level 40 from level 1 costs **225,212 XP** before relic rewards. Maximum-credit spawning supplies a bound of about 135,575 XP; collecting gold relics grants 25% of the current level requirement. Integrating maximum income and scheduled relics gives an upper-bound ten-minute reward budget of **level 37**. Population feedback, missed pickups, uncollected relics, surviving enemies and early death reduce actual progression; there is no level cap or forced level grant. The historical winning pilot below reached level 39 with the previous spawn system.

Escape pauses the timer and displays the current build to the left of the pause actions: damage, critical chance/damage, attack speed multiplier, attacks per second, projectiles, ricochets, explosion radius, pickup radius, health and regeneration. Upgrade cards show `current -> next` values in the stat's units; previews and application share the same calculation, including the 75% critical-chance cap.

Vortex starts at its original 1.35m sphere radius and shrinks smoothly to **25%** over 0.65 seconds. Enemies orbit 3.2–4.2m around its sides, keeping their body centres near its height rather than stacking above it. The centre stays at least the current halo radius plus 0.12m above the floor, including launches aimed straight down. Captured enemies are released when the vortex expires.

Each contact hit deals **7 HP**, with a shared 0.45-second recovery window and a per-enemy 0.8-second cooldown. Regeneration stays at 2 HP/second for the first two minutes, then declines to 0.5. Its final-minute integral is **35.625 HP**, approximately five contact hits. A saturated crowd can deal up to `7 / 0.45 = 15.56 HP/second`; after final regeneration it can drain full health in about **6.64 seconds**. Dash protects for only `0.5 / 3 = 16.7%` of its cooldown. Continuous crowd contact is fatal even with regeneration.

## Full-run playtests

Clump/emergence/movement-bias check (2026-10-11): skilled pilot / seed 1337 died at **8:39.83**, level 26, with **3,971 kills**, **2,731,870 damage dealt** and **338 peak living enemies**. It retained full health at 6:00. The trace is in `tests/results/clump_spawning_playtest_1337.txt`. This exercises actual movement, earned progression and all three timed swarms, but ended before the final minute. Focused checks separately validate final replenishment and the 400-enemy cap. Buried, rising and emerged clumps were also checked in rendered compatibility-mode captures. A single bot run does not establish a human win rate or browser frame rate.

Historical population-director check (2026-10-11, before clumps, emergence and movement bias): skilled pilot / seed 1337 died at **7:37.53**, level 22, with 2,162 kills, 1,102,610 damage dealt and 298 peak living enemies. It had full health at 4:00. The trace is in `tests/results/megabonk_spawning_playtest_1337.txt`. This single run measures actual earned progression and the first three swarm entries; it does not establish final-minute survivability or a human win rate. Focused checks independently exercise final replenishment, the 400-enemy cap, crowd saturation, kill-driven refill, swarm endings, pause, spawn distances and long-frame recovery.

Automated pilots play the actual Godot scene at 60 physics ticks per simulated second. They move, aim with limited turn speed, fire physical projectiles, collect real pickups, select real upgrade offers and use abilities at their actual cooldowns. They never teleport, inject damage, grant XP/upgrades or skip the timer. Headless Godot cannot capture a cursor, so its harness mirrors held-fire creation at the normal attack cooldown. The casual pilot walks without jumping or dashing, but still aims and uses abilities effectively. These labels describe bot behaviour, not measured human skill levels.

Historical 20/s finale check (2026-10-09, before the population director): focused balance checks verify the full rate curve, the sustained 20/s final minute, 10,000 HP final tier, actual spawned health and spawn debt; the progression check calculates a level-34 ideal reward budget. A real skilled pilot / seed 1337 died at **7:03.67**, level 19, with 1,535 kills and 618 peak living enemies. This run used the two-minute magnet schedule and ended before the changed final waves, so it cannot validate their survivability. The trace is recorded in `tests/results/tough_finale_playtest_1337.txt`.

Historical XP/vortex release check (2026-10-09, before the magnet and final-wave changes): skilled pilot / seed 1337 completed the full ten-minute run at **level 39**, with **51.0 HP**, a final-wave minimum of **43.7 HP**, 49 HP of final-wave damage, and **1,071 peak living enemies**. It defeated 14,665 enemies and dealt 15,985,180 damage. Seeds 11 and 27 died at 7:07.47 / level 21 and 8:45.42 / level 31 respectively. Fewer upgrades increase the difficulty with the existing horde settings. These are bot outcomes, not a human win-rate or browser performance measurement. Minute checkpoints and outcomes are in `tests/results/xp_vortex_playtest_1337.txt`, `xp_vortex_playtest_11.txt` and `xp_vortex_playtest_27.txt`. Rendered pause, upgrade, XP-glow and large/small vortex screenshots were checked; progression UI, vortex and balance rules pass from the rebuilt Web pack.

Previous release check (2026-10-07): skilled pilot / seed 1337 completed the full ten-minute run with **74.7 HP**, a final-wave minimum of **67.1 HP**, 28 HP of final-wave damage, and **826 peak living enemies**. It finished at level 78 with 15,467 kills and 17,279,190 damage dealt. The ending total includes partial damage to surviving enemies. The output and minute checkpoints are recorded in `tests/results/constant_speed_playtest.txt`.

The results below are historical results for the previous 26/s release with accelerating enemies and 950 HP final enemies; they do not describe the current 20/s, 10,000-HP finale. Full traces are kept in `tests/results/horde_playtests.txt`.

| Pilot / seed | Outcome | Final-wave minimum HP | Final-wave damage | Peak alive |
| --- | --- | ---: | ---: | ---: |
| Skilled / 1337 | Won at 10:00 with 20.5 HP | 18.5 | 70 | 149 |
| Skilled / 11 | Won at 10:00 with 48.9 HP | 48.3 | 70 | 151 |
| Skilled / 27 | Died at 9:30.35 | 0 | 56 | 175 |
| Casual / 11 | Died at 9:37.07 | 0 | 49 | 186 |
| Rendered skilled / 1337 | Died at 9:28.72 | 0 | 77 | 166 |

All five pilots were at full health at the two-minute checkpoint. The 1337 headless winner entered the final wave with 54.9 HP: approximately `54.9 + 35.625 − 70 = 20.5` at the finish. Its 18.5 HP low point leaves fewer than three additional 7 HP hits of margin. The stronger seed 11 build has more breathing room; other builds die under the same fixed settings. Visual checks at 8:00 and 9:00 showed the real crowd, pickups, health bars and final-wave HUD without layout clipping.

Tuning used complete runs, rather than shortened final-wave simulations. The initial fast speed curve killed skilled pilots in waves seven/eight. Delaying the speed ramp moved the failure point to wave nine. Reducing contact damage allowed complete runs, and the final 7 HP setting tightened the margin while preserving the large hordes. No difficulty scales secretly with the player's build.

Those historical outcomes establish that actual earned builds could complete the previous balance. They do not establish a human win percentage or a completion guarantee for the current balance. Rendered and headless held-fire timing can produce different upgrades and outcomes even with the same seed.

Run a full playtest:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/balance_playtest.gd -- --seed=1337 --pilot=skilled
```

Use `--pilot=casual` for walking, `--pilot=passive` to omit abilities, or `--seconds=120` for an opening check. Omit `--headless` and add `--capture` to render the pilot and save minute screenshots in `.testdata/`. Captured runs disable vsync to accelerate the fixed-tick test. The harness does not save player records.

Run focused rules and exported-pack verification:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/balance_rules_test.gd
godot --headless --path . --fixed-fps 60 --script tests/spawn_director_test.gd
godot --headless --path . --fixed-fps 60 --script tests/spawn_presentation_test.gd
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/balance_rules_test.gd
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/spawn_director_test.gd
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/spawn_presentation_test.gd
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/progression_ui_test.gd
```

Focused checks cover spawning, constant speed, population targets, timed and final swarms, 10,000 HP final tier, bounded spawn credit, survival victory/death, movement, fireballs, upgrades, skills, dash collision, explosion/vortex effects, lobby flow and results. `tests/results_test.gd` checks actual damage accounting, arena cleanup, replay, menu return and displayed stats; add `-- --capture` without `--headless` to capture both result screens. The release Web export uses the installed single-threaded template; keep every exported `docs/` file together.

`./tools/export_web.ps1` runs the installed Godot release export and adds a content-hash version to the pack URL, preventing browsers from loading a cached pack after deployment. After running the direct export command from `AGENTS.md`, use `./tools/export_web.ps1 -StampOnly` to apply the same loader update. All exported files stay together under `docs/`.

## Adjustment guide

- `ENEMY_POPULATION_TARGETS` controls crowd size; `ENEMY_SPAWN_RATES` controls maximum replenishment income. Tune them together.
- `ENEMY_SWARM_TIMES`, `ENEMY_SWARM_DURATION` and the swarm multipliers control pressure surges. `ENEMY_FINAL_SWARM_TIME` begins the sustained final crowd.
- `ENEMY_POPULATION_CAP`, credit cap and per-frame budget bound Web workload. Do not restore unlimited catch-up spawning.
- `ENEMY_CLUMP_MIN_SIZE`, `ENEMY_CLUMP_MAX_SIZE` and `ENEMY_CLUMP_RADIUS` control batching and group spacing; keep enough room for each health tier's scaled collider.
- `ENEMY_SPAWN_FORWARD_CHANCE` and the forward half-angle control movement bias; retain an all-direction fallback at walls.
- `ENEMY_EMERGENCE_DURATION`, depth and stagger control the underground rise; bodies must start fully buried and finish before collider activation.
- Keep ten health tiers. Late HP and contact damage affect survival separately from crowd size.
- `ENEMY_SPEED` controls the constant movement speed for every wave and enemy tier.
- `HEALTH_REGEN_END`, `PLAYER_HIT_GRACE` and `DASH_COOLDOWN` control the margin for mistakes.
- XP, drops, upgrade amounts and rarity weights affect crowd-clearing power and require complete reruns after changes.
- Keep spawn-rate values positive. Keep spawns inside wall clearance and 18–28 units from the player.
