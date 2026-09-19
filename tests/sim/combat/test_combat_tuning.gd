extends GutTest

var t := CombatTuning.new()


func test_type_mult_maps_each_type() -> void:
	assert_eq(t.type_mult(HitType.Kind.CUT), t.cut_mult)
	assert_eq(t.type_mult(HitType.Kind.THRUST), t.thrust_mult)
	assert_eq(t.type_mult(HitType.Kind.BLUNT), t.blunt_mult)


func test_part_mult_maps_each_part() -> void:
	assert_eq(t.part_mult(BodyPart.Kind.HEAD), t.head_mult)
	assert_eq(t.part_mult(BodyPart.Kind.TORSO), t.torso_mult)
	assert_eq(t.part_mult(BodyPart.Kind.ARM_L), t.arm_mult)
	assert_eq(t.part_mult(BodyPart.Kind.LEG_R), t.leg_mult)


func test_blunt_drains_more_balance_than_cut() -> void:
	assert_gt(t.balance_per_joule(HitType.Kind.BLUNT), t.balance_per_joule(HitType.Kind.CUT))


func test_body_part_helpers() -> void:
	assert_true(BodyPart.is_limb(BodyPart.Kind.ARM_R))
	assert_false(BodyPart.is_limb(BodyPart.Kind.HEAD))
	assert_true(BodyPart.is_vital(BodyPart.Kind.TORSO))
	assert_true(BodyPart.is_arm(BodyPart.Kind.ARM_L))
	assert_true(BodyPart.is_leg(BodyPart.Kind.LEG_L))
	assert_eq(BodyPart.ALL.size(), 6)
