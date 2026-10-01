extends "res://scripts/enemy.gd"

const GameConsts = preload("res://scripts/consts.gd")
var special_hit_cooldown := 0.0

func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	var title := Label3D.new()
	title.text = "FINAL BOSS"
	title.position.y = 2.2
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.font_size = 48
	title.modulate = Color("ffba38")
	add_child(title)

func _physics_process(delta: float) -> void:
	special_hit_cooldown = maxf(0.0, special_hit_cooldown - delta)
	super._physics_process(delta)

# Star contact and mega fireballs damage the boss instead of instantly killing it.
func defeat(attack_id := -1, damage_amount := 0.0) -> void:
	if health > 0.0:
		if special_hit_cooldown <= 0.0:
			special_hit_cooldown = 0.5
			take_damage(GameConsts.BOSS_SPECIAL_HIT_DAMAGE, false, attack_id)
		return
	super.defeat(attack_id, damage_amount)
