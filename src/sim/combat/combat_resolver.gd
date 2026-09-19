class_name CombatResolver
extends RefCounted
## Aplica as consequências de acertos e choques no estado dos lutadores.


static func apply_hit(hit: HitEvent, weapon_mult: float, health: BodyHealth, balance: Balance, tuning: CombatTuning) -> void:
	hit.damage = DamageCalculator.damage(hit.energy, hit.hit_type, hit.part, weapon_mult, tuning)
	if hit.damage > 0.0:
		health.apply_damage(hit.part, hit.damage, hit.hit_type, hit.energy, tuning)
	balance.drain(DamageCalculator.balance_drain(hit.energy, hit.hit_type, tuning))


## Quem tinha menos momentum perde a linha. -1 em empate.
static func clash_loser(clash: ClashEvent) -> int:
	if is_equal_approx(clash.momentum_a, clash.momentum_b):
		return -1
	return clash.fighter_a if clash.momentum_a < clash.momentum_b else clash.fighter_b


static func clash_balance_drain(clash: ClashEvent, tuning: CombatTuning) -> float:
	return absf(clash.momentum_a - clash.momentum_b) * tuning.clash_balance_per_momentum
