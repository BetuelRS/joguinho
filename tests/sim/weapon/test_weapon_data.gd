extends GutTest


func _two_block_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.tip_length = 0.1
	w.double_edged = false
	w.sections = [
		WeaponSection.make(WeaponSection.Kind.HANDLE, -0.2, 0.0, 0.02, 0.02, 1.0),
		WeaponSection.make(WeaponSection.Kind.BLADE, 0.0, 0.8, 0.03, 0.005, 3.0),
	]
	return w


func test_total_mass_sums_sections() -> void:
	assert_almost_eq(_two_block_weapon().total_mass(), 4.0, 1e-5)


func test_center_of_mass_is_weighted_average() -> void:
	# (1 * -0.1 + 3 * 0.4) / 4 = 0.275
	assert_almost_eq(_two_block_weapon().center_of_mass(), Vector3(0, 0.275, 0), Vector3.ONE * 1e-5)


func test_length_spans_all_sections() -> void:
	assert_almost_eq(_two_block_weapon().length(), 1.0, 1e-5)


func test_inertia_single_box_matches_formula() -> void:
	var w := WeaponData.new()
	w.sections = [WeaponSection.make(WeaponSection.Kind.BLADE, 0.0, 1.0, 0.05, 0.01, 2.0)]
	var i := w.inertia_about_com()
	# Caixa 0.1 x 1.0 x 0.02, massa 2: Izz = m/12 (lx^2 + ly^2)
	assert_almost_eq(i.z, 2.0 / 12.0 * (0.01 + 1.0), 1e-5)
	assert_almost_eq(i.y, 2.0 / 12.0 * (0.01 + 0.0004), 1e-5)


func test_inertia_uses_parallel_axis() -> void:
	var w := _two_block_weapon()
	var com := w.center_of_mass().y
	var naive := 0.0
	for s in w.sections:
		var ly := s.y_to - s.y_from
		var lx := s.half_width * 2.0
		naive += s.mass / 12.0 * (lx * lx + ly * ly)
	assert_gt(w.inertia_about_com().z, naive)


func test_zone_tip() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0.03, 0.75, 0), Vector3.RIGHT), WeaponZone.Kind.TIP)


func test_zone_edge_on_primary_side() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0.03, 0.4, 0), Vector3.RIGHT), WeaponZone.Kind.EDGE)


func test_zone_single_edge_back_is_flat() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(-0.03, 0.4, 0), Vector3.LEFT), WeaponZone.Kind.FLAT)


func test_zone_double_edge_back_is_edge() -> void:
	var w := _two_block_weapon()
	w.double_edged = true
	assert_eq(w.zone_at(Vector3(-0.03, 0.4, 0), Vector3.LEFT), WeaponZone.Kind.EDGE)


func test_zone_flat_side() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0, 0.4, 0.005), Vector3.BACK), WeaponZone.Kind.FLAT)


func test_zone_handle() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0, -0.1, 0), Vector3.RIGHT), WeaponZone.Kind.HANDLE)


func test_zone_outside_clamps_to_nearest_section() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0, -0.5, 0), Vector3.RIGHT), WeaponZone.Kind.HANDLE)
	assert_eq(_two_block_weapon().zone_at(Vector3(0, 0.9, 0), Vector3.UP), WeaponZone.Kind.TIP)


func test_edge_dir_double_edged_left_normal_is_left() -> void:
	var w := _two_block_weapon()
	w.double_edged = true
	assert_eq(w.edge_dir_at(Vector3.LEFT), Vector3.LEFT)


func test_edge_dir_double_edged_right_normal_is_right() -> void:
	var w := _two_block_weapon()
	w.double_edged = true
	assert_eq(w.edge_dir_at(Vector3.RIGHT), Vector3.RIGHT)


func test_edge_dir_single_edged_left_normal_is_right() -> void:
	var w := _two_block_weapon()
	assert_eq(w.edge_dir_at(Vector3.LEFT), Vector3.RIGHT)
