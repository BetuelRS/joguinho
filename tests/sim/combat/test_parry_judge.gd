extends GutTest

var ct := CombatTuning.new()  # janela 0.15 s, velocidade mínima 3 m/s


func test_flat_fast_in_window_is_parry() -> void:
	assert_true(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 5.0, 0.1, ct))


func test_edge_is_never_parry() -> void:
	assert_false(ParryJudge.is_parry(WeaponZone.Kind.EDGE, 5.0, 0.1, ct))


func test_slow_hand_is_not_parry() -> void:
	assert_false(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 1.0, 0.1, ct))


func test_late_is_not_parry() -> void:
	assert_false(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 5.0, 0.2, ct))


func test_window_boundary_is_inclusive() -> void:
	assert_true(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 3.0, 0.15, ct))
