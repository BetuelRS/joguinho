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
	match zone:
		WeaponZone.Kind.TIP:
			if v.dot(blade_axis.normalized()) >= cos(deg_to_rad(tuning.thrust_max_angle_deg)):
				return HitType.Kind.THRUST
			if _is_cut(v, blade_axis, edge_dir, tuning):
				return HitType.Kind.CUT
			return HitType.Kind.BLUNT
		WeaponZone.Kind.EDGE:
			if _is_cut(v, blade_axis, edge_dir, tuning):
				return HitType.Kind.CUT
			return HitType.Kind.BLUNT
		_:
			return HitType.Kind.BLUNT


## Um corte exige que a velocidade esteja aproximadamente no plano da lâmina
## (definido por `blade_axis` e `edge_dir`) e avance na direção do fio.
static func _is_cut(v: Vector3, blade_axis: Vector3, edge_dir: Vector3, tuning: CombatTuning) -> bool:
	var a := blade_axis.normalized()
	var e := edge_dir.normalized()
	var n := a.cross(e).normalized()
	var in_plane := asin(clampf(absf(v.dot(n)), 0.0, 1.0)) <= deg_to_rad(tuning.cut_max_angle_deg)
	var edge_forward := v.dot(e) >= tuning.cut_min_edge_dot
	return in_plane and edge_forward
