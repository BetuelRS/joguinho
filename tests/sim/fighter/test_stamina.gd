extends GutTest

var ft := FighterTuning.new()
var s: Stamina
const DT := 1.0 / 120.0


func before_each() -> void:
	s = Stamina.new(ft)


func test_starts_full() -> void:
	assert_eq(s.value, ft.stamina_max)
	assert_false(s.is_exhausted())
	assert_eq(s.strength_factor(), 1.0)


func test_try_spend_succeeds_and_reduces() -> void:
	assert_true(s.try_spend(ft.cost_thrust))
	assert_eq(s.value, ft.stamina_max - ft.cost_thrust)


func test_try_spend_fails_without_enough() -> void:
	s.try_spend(ft.stamina_max - 5.0)
	assert_false(s.try_spend(10.0))
	assert_eq(s.value, 5.0)


func test_continuous_drain_until_exhausted() -> void:
	var sustained := true
	for i in 10000:
		sustained = s.drain_continuous(ft.tension_per_s, DT)
		if not sustained:
			break
	assert_false(sustained)
	assert_true(s.is_exhausted())
	assert_eq(s.value, 0.0)
	assert_eq(s.strength_factor(), ft.exhausted_strength)


func test_regen_waits_for_delay() -> void:
	s.try_spend(50.0)
	for i in int(ft.stamina_regen_delay * 0.5 / DT):
		s.step(DT)
	assert_eq(s.value, ft.stamina_max - 50.0)


func test_regen_after_delay_caps_at_max() -> void:
	s.try_spend(10.0)
	for i in int(10.0 / DT):
		s.step(DT)
	assert_eq(s.value, ft.stamina_max)


func test_spending_resets_regen_delay() -> void:
	s.try_spend(50.0)
	for i in int(ft.stamina_regen_delay * 0.9 / DT):
		s.step(DT)
	s.try_spend(1.0)
	for i in int(ft.stamina_regen_delay * 0.5 / DT):
		s.step(DT)
	assert_eq(s.value, ft.stamina_max - 51.0)
