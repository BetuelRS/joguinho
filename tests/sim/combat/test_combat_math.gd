extends GutTest


func _diag(x: float, y: float, z: float) -> Basis:
	return Basis(Vector3(x, 0, 0), Vector3(0, y, 0), Vector3(0, 0, z))


func test_effective_mass_at_center_equals_mass() -> void:
	var m := CombatMath.effective_mass(2.0, _diag(6, 6, 6), Vector3.ZERO, Vector3.UP)
	assert_almost_eq(m, 2.0, 1e-5)


func test_effective_mass_at_rod_tip() -> void:
	# Barra de 2 kg e 1 m: I = m L^2 / 12 = 1/6 -> inverso 6.
	# Ponta em r = 0.5 no eixo X, impacto em Y: 1/m_ef = 1/2 + 0.5*6*0.5 = 2.
	var m := CombatMath.effective_mass(2.0, _diag(0, 6, 6), Vector3(0.5, 0, 0), Vector3.UP)
	assert_almost_eq(m, 0.5, 1e-5)


func test_effective_mass_ignores_normal_length() -> void:
	var a := CombatMath.effective_mass(2.0, _diag(0, 6, 6), Vector3(0.5, 0, 0), Vector3.UP)
	var b := CombatMath.effective_mass(2.0, _diag(0, 6, 6), Vector3(0.5, 0, 0), Vector3.UP * 7.0)
	assert_almost_eq(a, b, 1e-5)


func test_contact_energy() -> void:
	assert_almost_eq(CombatMath.contact_energy(2.0, Vector3(3, 4, 0)), 25.0, 1e-5)
