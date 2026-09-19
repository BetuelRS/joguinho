extends GutTest

var ft := FighterTuning.new()
var ct := CombatTuning.new()
var h: BodyHealth


func before_each() -> void:
	h = BodyHealth.new(ft)


func test_starts_full() -> void:
	for part in BodyPart.ALL:
		assert_eq(h.health(part), h.max_health(part))
	assert_false(h.is_dead)


func test_damage_reduces_and_clamps_at_zero() -> void:
	h.apply_damage(BodyPart.Kind.ARM_L, 30.0, HitType.Kind.CUT, 50.0, ct)
	assert_eq(h.health(BodyPart.Kind.ARM_L), ft.limb_max_health - 30.0)
	h.apply_damage(BodyPart.Kind.ARM_L, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_eq(h.health(BodyPart.Kind.ARM_L), 0.0)


func test_strong_cut_on_zeroed_limb_severs() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, ct.sever_energy + 1.0, ct)
	assert_true(h.is_severed(BodyPart.Kind.ARM_R))
	assert_signal_emitted_with_parameters(h, "limb_severed", [BodyPart.Kind.ARM_R])


func test_blunt_never_severs() -> void:
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.BLUNT, 9999.0, ct)
	assert_false(h.is_severed(BodyPart.Kind.ARM_R))


func test_weak_cut_does_not_sever() -> void:
	h.apply_damage(BodyPart.Kind.LEG_L, 9999.0, HitType.Kind.CUT, ct.sever_energy - 1.0, ct)
	assert_false(h.is_severed(BodyPart.Kind.LEG_L))


func test_severed_emits_only_once() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, 999.0, ct)
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, 999.0, ct)
	assert_signal_emit_count(h, "limb_severed", 1)


func test_zero_head_kills() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.HEAD, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_true(h.is_dead)
	assert_signal_emitted(h, "died")


func test_zero_limb_does_not_kill() -> void:
	h.apply_damage(BodyPart.Kind.LEG_R, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_false(h.is_dead)


func test_dead_body_ignores_damage() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.TORSO, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	h.apply_damage(BodyPart.Kind.HEAD, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_signal_emit_count(h, "died", 1)
	assert_eq(h.health(BodyPart.Kind.HEAD), h.max_health(BodyPart.Kind.HEAD))


func test_limb_strength_scales_with_health() -> void:
	assert_eq(h.limb_strength(BodyPart.Kind.ARM_R), 1.0)
	h.apply_damage(BodyPart.Kind.ARM_R, ft.limb_max_health, HitType.Kind.BLUNT, 50.0, ct)
	assert_almost_eq(h.limb_strength(BodyPart.Kind.ARM_R), ft.min_limb_strength, 1e-5)


func test_severed_limb_has_zero_strength() -> void:
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, 999.0, ct)
	assert_eq(h.limb_strength(BodyPart.Kind.ARM_R), 0.0)
