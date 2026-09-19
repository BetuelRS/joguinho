extends GutTest

var t := CombatTuning.new()  # graze 10, 0.5 dano/J, cut 1.0, thrust 1.3, head 2.0


func test_graze_does_no_damage() -> void:
	assert_eq(DamageCalculator.damage(9.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t), 0.0)
	assert_eq(DamageCalculator.damage(10.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t), 0.0)


func test_cut_on_torso() -> void:
	# (110 - 10) * 0.5 * 1.0 * 1.0 * 1.0 = 50
	assert_almost_eq(DamageCalculator.damage(110.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t), 50.0, 1e-4)


func test_thrust_on_head() -> void:
	# 100 * 0.5 * 1.3 * 2.0 = 130
	assert_almost_eq(DamageCalculator.damage(110.0, HitType.Kind.THRUST, BodyPart.Kind.HEAD, 1.0, t), 130.0, 1e-4)


func test_weapon_mult_scales_damage() -> void:
	var base := DamageCalculator.damage(110.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t)
	var doubled := DamageCalculator.damage(110.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 2.0, t)
	assert_almost_eq(doubled, base * 2.0, 1e-4)


func test_graze_does_not_drain_balance() -> void:
	assert_eq(DamageCalculator.balance_drain(5.0, HitType.Kind.BLUNT, t), 0.0)


func test_blunt_drains_more_than_cut_at_same_energy() -> void:
	var blunt := DamageCalculator.balance_drain(100.0, HitType.Kind.BLUNT, t)
	var cut := DamageCalculator.balance_drain(100.0, HitType.Kind.CUT, t)
	assert_gt(blunt, cut)
	assert_almost_eq(blunt, 25.0, 1e-4)
