# Balance and tuning

Balance settings live in `scripts/consts.gd`. A run has ten one-minute waves. Survive ten minutes to win; the boss is removed from the run. Its prototype script and constants remain dormant for future work. Remaining enemies do not need to be cleared after the timer ends.

The first five waves build the character. Wave six more than doubles the previous wave's enemy count, and the second half keeps increasing the horde. Spawn rates interpolate linearly between minute boundaries; health changes by wave. Previously spawned enemies retain their original health and speed.

| Wave | Time | Spawns / second, start → end | Primary HP | Expected new enemies | New enemy speed at start |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | 0:00–1:00 | 0.40 → 0.50 | 100 | 27 | 3.20 |
| 2 | 1:00–2:00 | 0.50 → 0.65 | 100 | 34.5 | 3.21 |
| 3 | 2:00–3:00 | 0.65 → 1.00 | 180 | 49.5 | 3.27 |
| 4 | 3:00–4:00 | 1.00 → 1.50 | 260 | 75 | 3.45 |
| 5 | 4:00–5:00 | 1.50 → 3.00 | 350 | 135 | 3.80 |
| 6 | 5:00–6:00 | 3.00 → 7.00 | 450 | 300 | 4.36 |
| 7 | 6:00–7:00 | 7.00 → 11.00 | 550 | 540 | 5.21 |
| 8 | 7:00–8:00 | 11.00 → 15.00 | 650 | 780 | 6.39 |
| 9 | 8:00–9:00 | 15.00 → 20.00 | 800 | 1,050 | 7.96 |
| 10 | 9:00–10:00 | 20.00 → 26.00 | 950 | 1,380 | 9.98 |

## Spawn geometry

All enemies, including the initial seven, spawn on one of four perimeter lines: `x = ±46` or `z = ±46`, with the other coordinate uniformly sampled between −46 and +46. The walls' inner faces are at ±47.5; the largest enemy's half-width is about 0.89, leaving clearance. There are no player-centred spawn circles or central spawn points.

Candidates within 18 horizontal units of the player are rejected. After 24 attempts, the fallback uses the opposite corner, still on the perimeter. The rules test checks 1,400 samples with the player at the centre, each side and opposite corners, including wall clearance, minimum distance and coverage of all four sides.

## Difficulty calculations

Enemies per wave are the area under the rate curve: `60 × (start_rate + end_rate) / 2`. The curve generates about 4,371 enemies, plus seven initial enemies: **4,378 per run**, versus about 2,034 in the previous balance. Waves six through ten supply 4,050 of those spawns. The final minute supplies 1,380, versus 600 previously. Fractional spawn debt is retained, so slow frames still create the requested number of enemies.

Base expected damage is `damage × projectiles hitting × attack_speed / 0.65 × (1 + crit_chance)`. Base DPS is `100 / 0.65 × 1.05 = 161.5`; at 70% accuracy it is 113 DPS, comfortably above the opening load of 40–65 HP/second. The first two minutes only spawn 100 HP red cubes.

Late enemies have less health than before to reward clearing large groups. In wave ten, 85% have 950 HP and 15% have 800 HP: mean health is **927.5 HP**. Incoming health rises from `20 × 927.5 = 18,550` to `26 × 927.5 = 24,115 HP/second`. One reference build at 9:00 has seven projectiles, 525 damage, 4.47 attack speed and 28% crit: approximately 32,349 theoretical direct DPS if every projectile hits, or 22,644 at 70%. Ricochets, explosions and abilities add crowd damage; spread, travel time, walls and missed volleys reduce effective damage. This is a pressure budget, not a guarantee of clearing every spawn.

New enemy speed is `3.2 + (12.5 − 3.2) × (elapsed / 600)^3`. The delayed increase lets the middle waves fill the arena before the fastest enemies arrive. Final-wave new enemies accelerate from 9.98 to 12.5, exceeding the player's 9-unit walking speed. Full bunny hopping reaches 18, but enemies approach from all sides and intercept routes.

Each contact hit deals **7 HP**, with a shared 0.45-second recovery window and a per-enemy 0.8-second cooldown. Regeneration stays at 2 HP/second for the first two minutes, then declines to 0.5. Its final-minute integral is **35.625 HP**, approximately five contact hits. A saturated crowd can deal up to `7 / 0.45 = 15.56 HP/second`; after final regeneration it can drain full health in about **6.64 seconds**. Dash protects for only `0.5 / 3 = 16.7%` of its cooldown. Continuous crowd contact is fatal even with regeneration.

## Full-run playtests

Automated pilots play the actual Godot scene at 60 physics ticks per simulated second. They move, aim with limited turn speed, fire physical projectiles, collect real pickups, select real upgrade offers and use abilities at their actual cooldowns. They never teleport, inject damage, grant XP/upgrades or skip the timer. Headless Godot cannot capture a cursor, so its harness mirrors held-fire creation at the normal attack cooldown. The casual pilot walks without jumping or dashing, but still aims and uses abilities effectively. These labels describe bot behaviour, not measured human skill levels.

Release results are recorded below; full traces are kept in `tests/results/horde_playtests.txt`.

| Pilot / seed | Outcome | Final-wave minimum HP | Final-wave damage | Peak alive |
| --- | --- | ---: | ---: | ---: |
| Skilled / 1337 | Won at 10:00 with 20.5 HP | 18.5 | 70 | 149 |
| Skilled / 11 | Won at 10:00 with 48.9 HP | 48.3 | 70 | 151 |
| Skilled / 27 | Died at 9:30.35 | 0 | 56 | 175 |
| Casual / 11 | Died at 9:37.07 | 0 | 49 | 186 |
| Rendered skilled / 1337 | Died at 9:28.72 | 0 | 77 | 166 |

All five pilots were at full health at the two-minute checkpoint. The 1337 headless winner entered the final wave with 54.9 HP: approximately `54.9 + 35.625 − 70 = 20.5` at the finish. Its 18.5 HP low point leaves fewer than three additional 7 HP hits of margin. The stronger seed 11 build has more breathing room; other builds die under the same fixed settings. Visual checks at 8:00 and 9:00 showed the real crowd, pickups, health bars and final-wave HUD without layout clipping.

Tuning used complete runs, rather than shortened final-wave simulations. The initial fast speed curve killed skilled pilots in waves seven/eight. Delaying the speed ramp moved the failure point to wave nine. Reducing contact damage allowed complete runs, and the final 7 HP setting tightened the margin while preserving the large hordes. No difficulty scales secretly with the player's build.

The outcomes establish that actual earned builds can complete the timer and that other builds fail under the final pressure. They do not establish a human win percentage. Rendered and headless held-fire timing can produce different upgrades and outcomes even with the same seed. Browser UI automation was unavailable during this verification; the exported pack was instead loaded directly in Godot and checked with the survival/spawn rules test.

Run a full playtest:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/balance_playtest.gd -- --seed=1337 --pilot=skilled
```

Use `--pilot=casual` for walking, `--pilot=passive` to omit abilities, or `--seconds=120` for an opening check. Omit `--headless` and add `--capture` to render the pilot and save minute screenshots in `.testdata/`. Captured runs disable vsync to accelerate the fixed-tick test. The harness does not save player records.

Run focused rules and exported-pack verification:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/balance_rules_test.gd
godot --headless --path . --main-pack docs/index.pck --fixed-fps 60 --script C:/R/game-3/tests/balance_rules_test.gd
```

Eight focused checks cover spawning, survival victory/death, movement, fireballs, upgrades, skills, dash collision, explosion/vortex effects and lobby flow. The release Web export uses the installed single-threaded template; keep every exported `docs/` file together.

## Adjustment guide

- Change the first six `ENEMY_SPAWN_RATES` to tune the opening and the transition after wave five; change the last five for horde size.
- Prefer tuning late HP and contact damage over removing enemies when the horde is too harsh. Keep ten health tiers.
- `ENEMY_SPEED_END` and `ENEMY_SPEED_RAMP_EXPONENT` control how early fast enemies intercept the player.
- `HEALTH_REGEN_END`, `PLAYER_HIT_GRACE` and `DASH_COOLDOWN` control the margin for mistakes.
- XP, drops, upgrade amounts and rarity weights affect crowd-clearing power and require complete reruns after changes.
- Keep spawn-rate values positive. Keep spawns on the perimeter and at least 18 units from the player.
