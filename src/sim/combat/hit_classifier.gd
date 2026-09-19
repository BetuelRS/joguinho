class_name HitClassifier
extends RefCounted
## Decide o tipo do golpe pela zona tocada e pela direção do movimento.


## `v_rel`: velocidade do ponto da arma relativa ao alvo.
## `blade_axis`: direção da guarda para a ponta.
## `edge_dir`: direção para fora do fio que tocou (o chamador escolhe o lado).
static func classify(zone: int, v_rel: Vector3, blade_axis: Vector3, edge_dir: Vector3, tuning: CombatTuning) -> int:
	if v_rel.length_squared() < 1e-8:
		return HitType.Kind.BLUNT
	var v := v_rel.normalized()
	var cut_cos := cos(deg_to_rad(tuning.cut_max_angle_deg))
	match zone:
		WeaponZone.Kind.TIP:
			if v.dot(blade_axis.normalized()) >= cos(deg_to_rad(tuning.thrust_max_angle_deg)):
				return HitType.Kind.THRUST
			if v.dot(edge_dir.normalized()) >= cut_cos:
				return HitType.Kind.CUT
			return HitType.Kind.BLUNT
		WeaponZone.Kind.EDGE:
			if v.dot(edge_dir.normalized()) >= cut_cos:
				return HitType.Kind.CUT
			return HitType.Kind.BLUNT
		_:
			return HitType.Kind.BLUNT
