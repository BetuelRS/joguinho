extends GutTest

var ct := CombatTuning.new()
var ft := FighterTuning.new()


func _hit(part: int, hit_type: int, energy: float) -> HitEvent:
	var h := HitEvent.new()
	h.part = part
	h.hit_type = hit_type
	h.energy = energy
	return h


func test_apply_hit_damages_and_drains() -> void:
	var health := BodyHealth.new(ft)
	var balance := Balance.new(ft)
	var hit := _hit(BodyPart.Kind.TORSO, HitType.Kind.CUT, 110.0)
	CombatResolver.apply_hit(hit, 1.0, health, balance, ct)
	assert_almost_eq(hit.damage, 50.0, 1e-4)
	assert_almost_eq(health.health(BodyPart.Kind.TORSO), ft.torso_max_health - 50.0, 1e-4)
	assert_almost_eq(balance.value, ft.balance_max - 110.0 * ct.balance_per_joule_cut, 1e-4)


func test_graze_changes_nothing() -> void:
	var health := BodyHealth.new(ft)
	var balance := Balance.new(ft)
	var hit := _hit(BodyPart.Kind.HEAD, HitType.Kind.BLUNT, 5.0)
	CombatResolver.apply_hit(hit, 1.0, health, balance, ct)
	assert_eq(hit.damage, 0.0)
	assert_eq(health.health(BodyPart.Kind.HEAD), ft.head_max_health)
	assert_eq(balance.value, ft.balance_max)


func _clash(ma: float, mb: float) -> ClashEvent:
	var c := ClashEvent.new()
	c.fighter_a = 1
	c.fighter_b = 2
	c.momentum_a = ma
	c.momentum_b = mb
	return c


func test_clash_loser_is_lower_momentum() -> void:
	assert_eq(CombatResolver.clash_loser(_clash(10.0, 3.0)), 2)
	assert_eq(CombatResolver.clash_loser(_clash(2.0, 9.0)), 1)


func test_clash_tie_has_no_loser() -> void:
	assert_eq(CombatResolver.clash_loser(_clash(5.0, 5.0)), -1)


func test_clash_drain_proportional_to_difference() -> void:
	assert_almost_eq(CombatResolver.clash_balance_drain(_clash(10.0, 3.0), ct), 7.0 * ct.clash_balance_per_momentum, 1e-4)
	assert_eq(CombatResolver.clash_balance_drain(_clash(5.0, 5.0), ct), 0.0)
