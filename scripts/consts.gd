extends RefCounted

# Game design settings. Distances in world units, times in seconds.
const ARENA_HALF := 48.0
const RUN_DURATION := 600.0
# Spawn rates at each minute boundary. Interpolate rates, not intervals.
# First five waves build the character; waves six onward flood the perimeter.
const ENEMY_SPAWN_RATES := [0.4, 0.5, 0.65, 1.0, 1.5, 3.0, 12.0, 30.0, 60.0, 100.0, 100.0]
const INITIAL_ENEMY_COUNT := 7
const ENEMY_HEALTH := [100.0, 100.0, 180.0, 260.0, 350.0, 450.0, 550.0, 650.0, 800.0, 1900.0]
const ENEMY_PREVIOUS_TYPE_CHANCE := 0.15
const ENEMY_NEXT_TYPE_CHANCE := 0.10
const ENEMY_SPEED := 3.2
const ENEMY_SPAWN_DISTANCE_MIN := 18.0
# Keep even the largest enemy inside the walls (inner face at 47.5).
const ENEMY_SPAWN_EDGE := ARENA_HALF - 2.0
const ENEMY_CONTACT_DAMAGE := 7.0
const ENEMY_CONTACT_COOLDOWN := 0.8

const PLAYER_MAX_HEALTH := 100.0
const PLAYER_HIT_GRACE := 0.45
const HEALTH_REGEN_START := 2.0
const HEALTH_REGEN_END := 0.5
const HEALTH_REGEN_RAMP_START := 120.0
const BASE_ATTACK_INTERVAL := 0.65
const BASE_DAMAGE := 100.0
const BASE_PROJECTILES := 1
const BASE_BOUNCES := 0
const BASE_EXPLOSION_RADIUS := 1.5
const BASE_CRIT_CHANCE := 0.05
const BASE_ATTACK_SPEED := 1.0
const PLAYER_WALK_SPEED := 9.0
const PLAYER_MAX_HOP_SPEED := 18.0
const PLAYER_JUMP_VELOCITY := 7.6
const PLAYER_MEGA_JUMP_VELOCITY := 15.5
const PLAYER_LONG_JUMP_SPEED := 27.0
const FIREBALL_SPEED := 28.0
const FIREBALL_LIFETIME := 5.0
const FIREBALL_SPREAD_DEGREES := 4.0
const CRIT_DAMAGE_MULTIPLIER := 2.0
const CRIT_CHANCE_CAP := 0.75

const XP_BASE_REQUIREMENT := 100.0
const XP_REQUIREMENT_LINEAR := 42.0
const XP_REQUIREMENT_QUADRATIC := 3.0
const XP_DROPS_MIN := 2
const XP_DROPS_MAX := 4
const XP_PER_DROP := 12.0
const INITIAL_COLLECTION_RADIUS := 2.2
const INITIAL_RELIC_COUNT := 4
const RELIC_SPAWN_INTERVAL := 13.0
const RELIC_FIRST_SPAWN_TIME := 10.0
const MAGNET_FIRST_SPAWN_TIME := 7.0
const OPENING_GRACE_DURATION := 120.0
const RELIC_LEVEL_XP_FRACTION := 0.25
const RELIC_COLLECTION_RADIUS_BONUS := 0.55
const STAR_SPAWN_INTERVAL := 120.0
const STAR_DURATION := 5.0
const STAR_SPEED_MULTIPLIER := 3.0
const MAGNET_SPAWN_INTERVAL := 14.0
const SKILL_COOLDOWN := 60.0
const FROST_DURATION := 4.0
const FORCE_PUSH_STRENGTH := 31.0
const UPGRADE_DAMAGE := 20.0
const UPGRADE_RADIUS := 0.30
const UPGRADE_CRIT_PERCENT := 3.0
const UPGRADE_ATTACK_SPEED_PERCENT := 12.0
const RARITIES := [
	{"name": "Common", "color": Color("f4f4f4"), "mult": 1.0, "weight": 50.0},
	{"name": "Uncommon", "color": Color("59e66b"), "mult": 1.45, "weight": 27.0},
	{"name": "Rare", "color": Color("55a6ff"), "mult": 2.0, "weight": 14.0},
	{"name": "Epic", "color": Color("bd6bff"), "mult": 2.8, "weight": 7.0},
	{"name": "Legendary", "color": Color("ff9d32"), "mult": 4.0, "weight": 2.0}
]
const DASH_DISTANCE := 24
const DASH_DURATION := 0.5
const DASH_COOLDOWN := 3.0
const DASH_CONTACT_RADIUS := 1.15
const DASH_KNOCKBACK_FORCE := 24.0

# Dormant boss prototype settings. The survival run does not spawn a boss.
const BOSS_FIGHT_DURATION := 60.0
const BOSS_SPAWN_TIME := RUN_DURATION - BOSS_FIGHT_DURATION
const BOSS_HEALTH := 500000.0
const BOSS_SPEED := 10.5
const BOSS_SCALE := 3.0
const BOSS_SPAWN_DISTANCE := 25.0
const BOSS_CONTACT_DAMAGE := 22.0
const BOSS_SPECIAL_HIT_DAMAGE := 1500.0
const BOSS_SPECIAL_HIT_COOLDOWN := 1.5

const EXPLOSION_DEATH_PARTICLES := 24
const VORTEX_ORBIT_RADIUS_MIN := 0.8
const VORTEX_ORBIT_RADIUS_MAX := 1.3
const VORTEX_ORBIT_SPEED_MIN := 2.0
const VORTEX_ORBIT_SPEED_MAX := 4.5
