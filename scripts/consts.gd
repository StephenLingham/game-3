extends RefCounted

# Game design settings. Distances in world units, times in seconds.
const ARENA_HALF := 48.0
const RUN_DURATION := 600.0
# One enemy per interval. Smaller intervals spawn faster.
const ENEMY_SPAWN_INTERVAL_START := 1
const ENEMY_SPAWN_INTERVAL_END := 0.0375
# Below 1 ramps up earlier; above 1 ramps up later.
const ENEMY_SPAWN_RAMP_EXPONENT := 0.75
const DASH_DISTANCE := 24
const DASH_DURATION := 0.5
const DASH_COOLDOWN := 0.55
const DASH_CONTACT_RADIUS := 1.15
const DASH_KNOCKBACK_FORCE := 24.0

# Final boss arrives with one minute left in the default run.
const BOSS_SPAWN_TIME := 540.0
const BOSS_HEALTH := 12000.0
const BOSS_SPEED := 4.5
const BOSS_SPECIAL_HIT_DAMAGE := 1500.0

const EXPLOSION_DEATH_PARTICLES := 24
const VORTEX_ORBIT_RADIUS_MIN := 0.8
const VORTEX_ORBIT_RADIUS_MAX := 1.3
const VORTEX_ORBIT_SPEED_MIN := 2.0
const VORTEX_ORBIT_SPEED_MAX := 4.5
