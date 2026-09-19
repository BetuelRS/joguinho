class_name ParryJudge
extends RefCounted
## Parry com a mão livre: tocar a chapa da lâmina inimiga, rápido, logo após pressionar RMB.


static func is_parry(zone_touched: int, hand_speed: float, time_since_free_hand: float, tuning: CombatTuning) -> bool:
	return zone_touched == WeaponZone.Kind.FLAT \
		and hand_speed >= tuning.parry_min_speed \
		and time_since_free_hand <= tuning.parry_window
