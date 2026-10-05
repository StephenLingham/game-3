# Balance and tuning

Edit `scripts/consts.gd`. The default run lasts ten minutes, with the boss in the last minute. Enemy health has ten entries; spawn rates have eleven entries, one at each minute boundary. Rates interpolate linearly, so pressure does not jump at minute boundaries. Health tiers still change each minute.

| Time | Spawn rate / second | Primary HP | New enemy speed |
| --- | ---: | ---: | ---: |
| 0:00 | 0.40 | 100 | 3.20 |
| 2:00 | 0.65 | 180 | 3.72 |
| 5:00 | 2.20 | 550 | 5.44 |
| 8:00 | 6.00 | 1,200 | 7.96 |
| 9:00 | 8.50 | 1,500 | 8.95 |
| 10:00 | 11.50 | 1,500 | 10.00 |

Before 2:00 all spawns are 100 HP red cubes, including the entire second minute. Base shots kill them with one hit. The table's HP column describes the primary tier after the opening grace period. Earlier spawns retain their original health and speed.

## Calculations

Expected single-target damage per second is:

`damage × projectiles hitting × attack_speed / BASE_ATTACK_INTERVAL × (1 + crit_chance × (CRIT_DAMAGE_MULTIPLIER - 1))`.

Base DPS is `100 / 0.65 × 1.05 = 161.5`. Even at 70% hit accuracy, 113 DPS exceeds the opening spawn load of 40–65 HP/second. Regeneration stays at 2 HP/second for the first two minutes, then declines linearly to 0.5. This gives beginners time to learn and collect upgrades.

The area under the piecewise linear rate curve gives enemies per minute: `60 × (start_rate + end_rate) / 2`. The opening minutes spawn approximately 27 and 34.5 enemies; the last minute spawns approximately 600. Across the run the curve generates about 2,034 enemies, plus the initial seven and boss. The actual spawn clock retains fractional debt, including when a frame is slower than one spawn interval.

In the last tier, 85% of spawns have 1,500 HP and 15% have 1,200 HP, giving mean health 1,455. Incoming health rises from `8.5 × 1,455 = 12,367.5` to `11.5 × 1,455 = 16,732.5 HP/second`. Ricochets, explosions, vortex grouping and star pickups supply crowd damage; concentrating only on the boss leaves a growing crowd.

A reference late build with five projectiles, 555 damage, 3.05 attack speed and 17% crit has about 15,235 theoretical boss DPS when every projectile hits. Dodging, obstructing enemies and missed volleys reduce this. The 500,000 HP boss takes 55.6 seconds at 9,000 effective DPS, leaving 4.4 seconds. Health is fixed, so better upgrades and aim improve the margin; it does not secretly scale with the player's build.

Normal walking is 9 units/second, full bunny hopping is 18, and late enemies approach 10. Movement becomes necessary. Dash protects for `0.5 / 3 = 16.7%` of its cooldown, compared with the previous 90.9%. A shared 0.45-second hit recovery prevents a crowd from delivering many hits in one frame. The scaled boss now has a contact radius matching its body; the old 1.2-unit check made it struggle to hit the player.

## Full-run playtests

These are automated pilots playing the actual Godot scene at 60 physics ticks/second. They move, aim with a limited turn speed, fire physical projectiles, collect real pickups, choose from real upgrade offers and use abilities at their actual cooldowns. They never teleport, inject damage, grant XP/upgrades or skip the survival timer. Headless Godot cannot capture a cursor, so the harness mirrors held-fire projectile creation using the normal attack cooldown. The casual pilot walks without bunny hopping or dashing but still aims and uses abilities effectively; it is not a measured human skill level.

| Pilot / seed | First 2 minutes | Boss defeated at | Outcome |
| --- | --- | --- | --- |
| Skilled / 11 | 100 HP | 9:40.97 | Won with 56.9 HP |
| Skilled / 27 | 100 HP | 9:58.22 | Won with 78.9 HP; 1.78 seconds spare |
| Casual / 11 | 100 HP | 9:23.82 | Won with 18.7 HP; minimum 18.0 |
| Skilled / 1337 | 100 HP | 9:29.03 | Died at 9:55.62 despite killing boss |
| Rendered skilled / 27 | 100 HP | Still alive | Died at 9:39.75; boss had 117,050 HP |

The runs show an easy opening and a beatable ending with genuine failures near the finish. Stronger builds can kill the boss earlier but must still survive the complete final minute. Rendered input timing can produce a different run from headless timing. Automated results and a visual opening check do not establish a human win percentage. Additional live Computer Use was stopped by the user. A final headless rerun reproduced seed 27's 9:58.22 boss kill.

Run a full playtest:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/balance_playtest.gd -- --seed=27 --pilot=skilled
```

Use `--pilot=casual` to test walking, or `--pilot=passive` to omit abilities. Use `--seconds=120` for an opening-only run. Omit `--headless` to watch the pilot. Playtest records are isolated from the player's saved records.

Run the focused rules check:

```powershell
godot --headless --path . --fixed-fps 60 --script tests/balance_rules_test.gd
```

## Adjustment guide

- Change the first three `ENEMY_SPAWN_RATES` or `OPENING_GRACE_DURATION` to adjust the easy opening.
- Change the last three rates, last health tiers or `ENEMY_SPEED_END` to adjust late crowd pressure.
- Change `BOSS_HEALTH` to adjust the damage deadline: at 9,000 effective DPS, 9,000 HP changes the fight by about one second. `BOSS_SPEED`, `BOSS_SCALE` and contact damage also affect pressure and volley hit rates.
- Change `HEALTH_REGEN_END`, `PLAYER_HIT_GRACE` or `DASH_COOLDOWN` to adjust the player's margin for mistakes.
- XP coefficients, drop values, upgrade amounts and rarity weights control power growth. Changing these requires another full-run check, because they also change boss damage substantially.
- Keep the spawn-rate values positive. Keep ten health tiers; their colours and visuals are defined for ten types.
