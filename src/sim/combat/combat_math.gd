class_name CombatMath
extends RefCounted
## Física do contato: quanta massa "sente" o alvo e quanta energia o golpe carrega.


## Massa efetiva de um corpo rígido no ponto de contato, ao longo da normal.
## Ponta de arma girando -> massa efetiva baixa; perto do centro de massa -> massa cheia.
static func effective_mass(mass: float, inv_inertia: Basis, r: Vector3, normal: Vector3) -> float:
	var n := normal.normalized()
	var rxn := r.cross(n)
	var inverse := 1.0 / mass + rxn.dot(inv_inertia * rxn)
	return 1.0 / inverse


static func contact_energy(m_eff: float, v_rel: Vector3) -> float:
	return 0.5 * m_eff * v_rel.length_squared()
