extends Node

const SAVE_PATH := "user://arena_shooter_stats.cfg"
const SECTION := "records"
const DEFAULTS := {
	"highest_level": 1,
	"most_kills": 0,
	"longest_time": 0.0,
	"most_damage": 0.0,
	"most_attack_kills": 0,
}

var records: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	load_records()

func load_records() -> void:
	records = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in DEFAULTS:
		records[key] = config.get_value(SECTION, key, DEFAULTS[key])

func record_run(level: int, kills: int, duration: float, damage: float, attack_kills: int) -> void:
	records.highest_level = maxi(int(records.highest_level), level)
	records.most_kills = maxi(int(records.most_kills), kills)
	records.longest_time = maxf(float(records.longest_time), duration)
	records.most_damage = maxf(float(records.most_damage), damage)
	records.most_attack_kills = maxi(int(records.most_attack_kills), attack_kills)
	_save()

func _save() -> void:
	# Headless test runs must never pollute a player's real records.
	if DisplayServer.get_name() == "headless":
		return
	var config := ConfigFile.new()
	for key in records:
		config.set_value(SECTION, key, records[key])
	config.save(SAVE_PATH)

func formatted_time() -> String:
	var total_seconds := int(floor(float(records.longest_time)))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
