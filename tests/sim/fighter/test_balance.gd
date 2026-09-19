extends GutTest

var ft := FighterTuning.new()
var b: Balance


func before_each() -> void:
	b = Balance.new(ft)


func _advance(seconds: float, leg_strength: float = 1.0) -> void:
	var dt := 1.0 / 120.0
	for i in int(round(seconds / dt)):
		b.step(dt, leg_strength)


func test_starts_full_and_standing() -> void:
	assert_eq(b.value, ft.balance_max)
	assert_false(b.is_down)
	assert_eq(b.support_factor(), 1.0)


func test_drain_reduces_value() -> void:
	b.drain(30.0)
	assert_eq(b.value, ft.balance_max - 30.0)


func test_draining_to_zero_falls() -> void:
	watch_signals(b)
	b.drain(ft.balance_max + 5.0)
	assert_true(b.is_down)
	assert_eq(b.value, 0.0)
	assert_eq(b.support_factor(), 0.0)
	assert_signal_emitted(b, "lost")


func test_no_drain_while_down() -> void:
	watch_signals(b)
	b.drain(999.0)
	b.drain(999.0)
	assert_signal_emit_count(b, "lost", 1)


func test_recovers_after_recovery_time() -> void:
	watch_signals(b)
	b.drain(999.0)
	_advance(ft.balance_recovery_time - 0.1)
	assert_true(b.is_down)
	_advance(0.2)
	assert_false(b.is_down)
	assert_eq(b.value, ft.balance_recovered_value)
	assert_signal_emitted(b, "recovered")


func test_no_regen_before_delay() -> void:
	b.drain(50.0)
	_advance(ft.balance_regen_delay * 0.5)
	assert_eq(b.value, ft.balance_max - 50.0)


func test_regen_after_delay() -> void:
	b.drain(50.0)
	_advance(ft.balance_regen_delay + 1.0)
	assert_gt(b.value, ft.balance_max - 50.0)
	assert_lte(b.value, ft.balance_max)


func test_injured_legs_regen_slower() -> void:
	var healthy := Balance.new(ft)
	var injured := Balance.new(ft)
	healthy.drain(80.0)
	injured.drain(80.0)
	var dt := 1.0 / 120.0
	for i in 120:
		healthy.step(dt, 1.0)
		injured.step(dt, 0.3)
	assert_gt(healthy.value, injured.value)


func test_support_factor_scales_with_value() -> void:
	b.drain(ft.balance_max * 0.5)
	assert_almost_eq(b.support_factor(), lerpf(ft.min_support_factor, 1.0, 0.5), 1e-5)
