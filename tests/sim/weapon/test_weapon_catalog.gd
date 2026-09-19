extends GutTest


func test_longsword_matches_spec() -> void:
	var w := WeaponCatalog.longsword()
	assert_almost_eq(w.total_mass(), 1.4, 0.01)
	assert_almost_eq(w.length(), 1.1, 0.05)
	var com := w.center_of_mass().y
	assert_between(com, 0.08, 0.16, "CoM ~10 cm à frente da guarda")
	assert_true(w.double_edged)


func test_hammer_matches_spec() -> void:
	var w := WeaponCatalog.hammer()
	assert_almost_eq(w.total_mass(), 5.0, 0.01)
	assert_almost_eq(w.length(), 0.9, 0.05)
	assert_gt(w.center_of_mass().y, 0.55, "massa concentrada na cabeça")


func test_hammer_head_zone() -> void:
	var w := WeaponCatalog.hammer()
	assert_eq(w.zone_at(Vector3(0.09, 0.74, 0), Vector3.RIGHT), WeaponZone.Kind.HEAD)


func test_hammer_is_much_harder_to_swing() -> void:
	# Resistência a girar em torno da mão (eixo Z, pela pegada): I_com + m d^2.
	var sword := WeaponCatalog.longsword()
	var hammer := WeaponCatalog.hammer()
	var i_sword := sword.inertia_about_com().z + sword.total_mass() * pow(sword.center_of_mass().y - sword.grip_primary, 2)
	var i_hammer := hammer.inertia_about_com().z + hammer.total_mass() * pow(hammer.center_of_mass().y - hammer.grip_primary, 2)
	assert_gt(i_hammer, i_sword * 5.0)


func test_all_returns_both() -> void:
	var ids: Array[StringName] = []
	for w in WeaponCatalog.all():
		ids.append(w.id)
	assert_has(ids, &"longsword")
	assert_has(ids, &"hammer")
