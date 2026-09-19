class_name WeaponData
extends Resource
## Definição física de uma arma. Espaço local: origem na base da guarda, +Y para a ponta,
## +X fio principal, +Z normal da chapa.

@export var id: StringName
@export var display_name: String
@export var damage_mult: float = 1.0
## Posição Y da mão principal e da segunda mão (pegada de duas mãos).
@export var grip_primary: float = 0.0
@export var grip_secondary: float = 0.0
@export var double_edged: bool = true
## Comprimento (m) a partir do fim da lâmina que conta como ponta.
@export var tip_length: float = 0.1
@export var sections: Array[WeaponSection] = []


func total_mass() -> float:
	var m := 0.0
	for s in sections:
		m += s.mass
	return m


func center_of_mass() -> Vector3:
	var acc := 0.0
	for s in sections:
		acc += s.mass * s.center_y()
	return Vector3(0.0, acc / total_mass(), 0.0)


## Momentos principais de inércia em torno do centro de massa (caixas + eixos paralelos).
func inertia_about_com() -> Vector3:
	var com_y := center_of_mass().y
	var inertia := Vector3.ZERO
	for s in sections:
		var lx := s.half_width * 2.0
		var ly := s.y_to - s.y_from
		var lz := s.half_thickness * 2.0
		var d := s.center_y() - com_y
		inertia.x += s.mass / 12.0 * (ly * ly + lz * lz) + s.mass * d * d
		inertia.y += s.mass / 12.0 * (lx * lx + lz * lz)
		inertia.z += s.mass / 12.0 * (lx * lx + ly * ly) + s.mass * d * d
	return inertia


func length() -> float:
	var lo := INF
	var hi := -INF
	for s in sections:
		lo = minf(lo, s.y_from)
		hi = maxf(hi, s.y_to)
	return hi - lo


## Seção que contém `y`; fora da arma, a seção mais próxima.
func section_at(y: float) -> WeaponSection:
	var best: WeaponSection = null
	var best_dist := INF
	for s in sections:
		if y >= s.y_from and y <= s.y_to:
			return s
		var dist := minf(absf(y - s.y_from), absf(y - s.y_to))
		if dist < best_dist:
			best_dist = dist
			best = s
	return best


func zone_at(local_point: Vector3, local_normal: Vector3) -> int:
	var s := section_at(local_point.y)
	match s.kind:
		WeaponSection.Kind.BLADE:
			if local_point.y >= s.y_to - tip_length:
				return WeaponZone.Kind.TIP
			if absf(local_normal.x) >= absf(local_normal.z) and (double_edged or local_normal.x > 0.0):
				return WeaponZone.Kind.EDGE
			return WeaponZone.Kind.FLAT
		WeaponSection.Kind.GUARD:
			return WeaponZone.Kind.GUARD
		WeaponSection.Kind.HEAD:
			return WeaponZone.Kind.HEAD
		_:
			return WeaponZone.Kind.HANDLE
