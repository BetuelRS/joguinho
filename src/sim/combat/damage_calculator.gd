class_name DamageCalculator
extends RefCounted
## Converte a energia de um contato em dano e dreno de equilíbrio.


static func damage(energy: float, hit_type: int, part: int, weapon_mult: float, tuning: CombatTuning) -> float:
	if energy <= tuning.graze_energy:
		return 0.0
	return (energy - tuning.graze_energy) * tuning.damage_per_joule \
		* tuning.type_mult_for(hit_type, part) * tuning.part_mult(part) * weapon_mult


static func balance_drain(energy: float, hit_type: int, tuning: CombatTuning) -> float:
	if energy <= tuning.graze_energy:
		return 0.0
	return energy * tuning.balance_per_joule(hit_type)
