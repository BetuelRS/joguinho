class_name Balance
extends RefCounted
## Barra de equilíbrio. Zerada, o lutador cai em ragdoll e levanta após `balance_recovery_time`.

signal lost
signal recovered

var value: float
var is_down: bool = false

var _tuning: FighterTuning
var _since_impact: float = 0.0
var _down_time: float = 0.0


func _init(tuning: FighterTuning) -> void:
	_tuning = tuning
	value = tuning.balance_max


func drain(amount: float) -> void:
	if is_down or amount <= 0.0:
		return
	value -= amount
	_since_impact = 0.0
	if value <= 0.0:
		value = 0.0
		is_down = true
		_down_time = 0.0
		lost.emit()


func step(dt: float, leg_strength: float = 1.0) -> void:
	if is_down:
		_down_time += dt
		if _down_time >= _tuning.balance_recovery_time:
			is_down = false
			value = _tuning.balance_recovered_value
			_since_impact = 0.0
			recovered.emit()
		return
	_since_impact += dt
	if _since_impact >= _tuning.balance_regen_delay:
		value = minf(_tuning.balance_max, value + _tuning.balance_regen_per_s * leg_strength * dt)


func support_factor() -> float:
	if is_down:
		return 0.0
	return lerpf(_tuning.min_support_factor, 1.0, value / _tuning.balance_max)
