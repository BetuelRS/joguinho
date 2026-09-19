class_name Stamina
extends RefCounted
## Energia para tensão, estocada, chute, esquiva, corrida e parry.

var value: float

var _tuning: FighterTuning
var _since_spend: float = 0.0
var _exhausted: bool = false


func _init(tuning: FighterTuning) -> void:
	_tuning = tuning
	value = tuning.stamina_max


func try_spend(amount: float) -> bool:
	if amount < 0.0:
		return false
	if _exhausted:
		return false
	if value < amount:
		return false
	value -= amount
	_since_spend = 0.0
	if value <= 0.0:
		_exhausted = true
	return true


func drain_continuous(rate_per_s: float, dt: float) -> bool:
	if rate_per_s <= 0.0 or dt <= 0.0:
		return not _exhausted
	if _exhausted:
		return false
	value = maxf(0.0, value - rate_per_s * dt)
	_since_spend = 0.0
	if value <= 0.0:
		_exhausted = true
	return value > 0.0


func step(dt: float) -> void:
	_since_spend += dt
	if _since_spend >= _tuning.stamina_regen_delay:
		value = minf(_tuning.stamina_max, value + _tuning.stamina_regen_per_s * dt)
	if _exhausted and value >= _tuning.exhaustion_recover_threshold:
		_exhausted = false


func is_exhausted() -> bool:
	return _exhausted


func strength_factor() -> float:
	return _tuning.exhausted_strength if is_exhausted() else 1.0
