# Balance and tuning

Balance settings live in `scripts/consts.gd`. A run has ten one-minute waves. Survive ten minutes to win; the boss is removed from the run. Its prototype script and constants remain dormant for future work. Remaining enemies do not need to be cleared after the timer ends.

The first five waves build the character. The second half increases the horde to **100 enemies per second at the start of wave ten**, sustained for the entire final minute. Spawn rates interpolate linearly between minute boundaries; health changes by wave. Previously spawned enemies retain their original health. Every enemy type moves at a constant **3.2 units/second**, regardless of spawn time.

| Wave | Time | Spawns / second, start → end | Primary HP | Expected new enemies | New enemy speed at start |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | 0:00–1:00 | 0.40 → 0.50 | 100 | 27 | 3.20 |
| 2 | 1:00–2:00 | 0.50 → 0.65 | 100 | 34.5 | 3.20 |
| 3 | 2:00–3:00 | 0.65 → 1.00 | 180 | 49.5 | 3.20 |
| 4 | 3:00–4:00 | 1.00 → 1.50 | 260 | 75 | 3.20 |
| 5 | 4:00–5:00 | 1.50 → 3.00 | 350 | 135 | 3.20 |
| 6 | 5:00–6:00 | 3.00 → 12.00 | 450 | 450 | 3.20 |
| 7 | 6:00–7:00 | 12.00 → 30.00 | 550 | 1,260 | 3.20 |
| 8 | 7:00–8:00 | 30.00 → 60.00 | 650 | 2,700 | 3.20 |
| 9 | 8:00–9:00 | 60.00 → 100.00 | 800 | 4,800 | 3.20 |
| 10 | 9:00–10:00 | 100.00 → 100.00 | 1,900 | 6,000 | 3.20 |

## Spawn geometry

All enemies, including the initial seven, spawn on one of four perimeter lines: `x = ±46` or `z = ±46`, with the other coordinate uniformly sampled between −46 and +46. The walls' inner faces are at ±47.5; the largest enemy's half-width is about 0.89, leaving clearance. There are no player-centred spawn circles or central spawn points.

Candidates within 18 horizontal units of the player are rejected. After 24 attempts, the fallback uses the opposite corner, still on the perimeter. The rules test checks 1,400 samples with the player at the centre, each side and opposite corners, including wall clearance, minimum distance and coverage of all four sides.

## Difficulty calculations

Enemies per wave are the area under the rate curve: `60 × (start_rate + end_rate) / 2`. The curve generates about 15,531 enemies, plus seven initial enemies: **15,538 per run**. Waves six through ten supply 15,210 of those spawns. The final minute supplies 6,000. Fractional spawn debt is retained, so slow frames still create the requested number of enemies.

Base expected damage is `damage × projectiles hitting × attack_speed / 0.65 × (1 + crit_chance)`. Base DPS is `100 / 0.65 × 1.05 = 161.5`; at 70% accuracy it is 113 DPS, comfortably above the opening load of 40–65 HP/second. The first two minutes only spawn 100 HP red cubes.

The final enemy tier has **1,900 HP**, twice its previous 950 HP. Earlier tiers retain their original health. In wave ten, 85% have 1,900 HP and 15% have 800 HP: mean health is **1,735 HP**. Incoming health is `100 × 1,735 = 173,500 HP/second` throughout the final wave. Ricochets, explosions and abilities add crowd damage; spread, travel time, walls and missed volleys reduce effective damage. Surviving the timer does not require clearing every spawn.

Enemy speed is fixed by `ENEMY_SPEED = 3.2`, including enemy setup outside the normal spawn path. There is no time or type-based speed ramp. Walking reaches 9 units/second and full bunny hopping reaches 18; the difficulty increase comes from horde density and health.

## Run results

Victory and death release the mouse and replace the arena with `results.tscn`. The screen shows total damage dealt, enemies defeated, survival time, wave and level reached, damage taken, biggest hit, most kills in one attack, attacks used and the final build. Play Again / R starts a fresh run; Back To Lobby / Esc returns to the menu.

Total damage measures enemy health actually removed, excludes overkill and includes nonlethal hits, explosions, mega fireballs and Star Power. Biggest hit retains the full attack damage. Damage taken measures health actually lost, including lethal hits capped to remaining health. The results snapshot survives scene changes in `RunStats.last_run`; new runs reset it, while personal records remain saved.

## XP progression and build display

Every defeated enemy drops **one blue ball worth 12 XP**. Previously enemies dropped two to four 12-XP balls. The sphere has a brighter unshaded core and a shared soft additive glow billboard, so its glow is visible with the Web compatibility renderer without adding a light for every pickup.

The cost to advance from level `L` is `100 + 42 × (L − 1) + 10 × (L − 1)²`, increased from a quadratic coefficient of 3. Reaching level 40 from level 1 costs **225,212 XP** before relic rewards. All 15,538 scheduled enemies supply about 186,456 XP; collecting gold relics still grants 25% of the current level requirement. Integrating the spawn curve and scheduled relics gives an ideal ten-minute reward budget of **level 40**. Missed pickups, uncollected relics, surviving enemies and early death reduce actual progression; there is no level cap or forced level grant. The real winning pilot below reached level 39.

Escape pauses the timer and displays the current build to the left of the pause actions: damage, critical chance/damage, attack speed multiplier, attacks per second, projectiles, ricochets, explosion radius, pickup radius, health and regeneration. Upgrade cards show `current -> next` values in the stat's units; previews and application share the same calculation, including the 75% critical-chance cap.

Vortex starts at its original 1.35m sphere radius and shrinks smoothly to **25%** over 0.65 seconds. Enemies orbit 3.2–4.2m around its sides, keeping their body centres near its height rather than stacking above it. The centre stays at least the current halo radius plus 0.12m above the floor, including launches aimed straight down. Captured enemies are released when the vortex expires.

Each contact hit deals **7 HP**, with a shared 0.45-second recovery window and a per-enemy 0.8-second cooldown. Regeneration stays at 2 HP/second for the first two minutes, then declines to 0.5. Its final-minute integral is **35.625 HP**, approximately five contact hits. A saturated crowd can deal up to `7 / 0.45 = 15.56 HP/second`; after final regeneration it can drain full health in about **6.64 seconds**. Dash protects for only `0.5 / 3 = 16.7%` of its cooldown. Continuous crowd contact is fatal even with regeneration.

## Full-run playtests

Automated pilots play the actual Godot scene at 60 physics ticks per simulated second. They move, aim with limited turn speed, fire physical projectiles, collect real pickups, select real upgrade offers and use abilities at their actual cooldowns. They never teleport, inject damage, grant XP/upgrades or skip the timer. Headless Godot cannot capture a cursor, so its harness mirrors held-fire creation at the normal attack cooldown. The casual pilot walks without jumping or dashing, but still aims and uses abilities effectively. These labels describe bot behaviour, not measured human skill levels.

Current release check (2026-10-09): skilled pilot / seed 1337 completed the full ten-minute run at **level 39**, with **51.0 HP**, a final-wave minimum of **43.7 HP**, 49 HP of final-wave damage, and **1,071 peak living enemies**. It defeated 14,665 enemies and dealt 15,985,180 damage. Seeds 11 and 27 died at 7:07.47 / level 21 and 8:45.42 / level 31 respectively. Fewer upgrades increase the difficulty with the existing horde settings. These are bot outcomes, not a human win-rate or browser performance measurement. Minute checkpoints and outcomes are in `tests/results/xp_vortex_playtest_1337.txt`, `xp_vortex_playtest_11.txt` and `xp_vortex_playtest_27.txt`. Rendered pause, upgrade, XP-glow and large/small vortex screenshots were checked; progression UI, vortex and balance rules pass from the rebuilt Web pack.

Previous release check (2026-10-07): skilled pilot / seed 1337 completed the full ten-minute run with **74.7 HP**, a final-wave minimum of **67.1 HP**, 28 HP of final-wave damage, and **826 peak living enemies**. It finished at level 78 with 15,467 kills and 17,279,190 damage dealt. The ending total includes partial damage to surviving enemies. The output and minute checkpoints are recorded in `tests/results/constant_speed_playtest.txt`.

The results below are historical results for the previous 26/s release with accelerating enemies and 950 HP final enemies; they do not describe the current 100/s balance. Full traces are kept in `tests/results/horde_playtests.txt`.

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
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/balance_rules_test.gd
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/progression_ui_test.gd
```

Focused checks cover spawning, constant speed, 100/s final-wave spawn debt, doubled final HP, survival victory/death, movement, fireballs, upgrades, skills, dash collision, explosion/vortex effects, lobby flow and results. `tests/results_test.gd` checks actual damage accounting, arena cleanup, replay, menu return and displayed stats; add `-- --capture` without `--headless` to capture both result screens. The release Web export uses the installed single-threaded template; keep every exported `docs/` file together.

## Adjustment guide

- Change the first six `ENEMY_SPAWN_RATES` to tune the opening and the transition after wave five; change the last five for horde size.
- Prefer tuning late HP and contact damage over removing enemies when the horde is too harsh. Keep ten health tiers.
- `ENEMY_SPEED` controls the constant movement speed for every wave and enemy tier.
- `HEALTH_REGEN_END`, `PLAYER_HIT_GRACE` and `DASH_COOLDOWN` control the margin for mistakes.
- XP, drops, upgrade amounts and rarity weights affect crowd-clearing power and require complete reruns after changes.
- Keep spawn-rate values positive. Keep spawns on the perimeter and at least 18 units from the player.
