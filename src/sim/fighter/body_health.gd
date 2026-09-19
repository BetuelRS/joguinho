class_name BodyHealth
extends RefCounted
## Vida por parte do corpo, desmembramento e morte.

signal limb_severed(part: int)
signal died

var is_dead: bool = false

var _tuning: FighterTuning
var _health: Dictionary = {}   # int -> float
var _severed: Dictionary = {}  # int -> bool


func _init(tuning: FighterTuning) -> void:
	_tuning = tuning
	for part in BodyPart.ALL:
		_health[part] = max_health(part)
		_severed[part] = false


func max_health(part: int) -> float:
	if part == BodyPart.Kind.HEAD:
		return _tuning.head_max_health
	if part == BodyPart.Kind.TORSO:
		return _tuning.torso_max_health
	return _tuning.limb_max_health


func health(part: int) -> float:
	return _health[part]


func is_severed(part: int) -> bool:
	return _severed[part]


func apply_damage(part: int, amount: float, hit_type: int, energy: float, combat: CombatTuning) -> void:
	if is_dead:
		return
	_health[part] = maxf(0.0, _health[part] - amount)
	if _health[part] > 0.0:
		return
	if BodyPart.is_vital(part):
		is_dead = true
		died.emit()
	elif hit_type == HitType.Kind.CUT and energy >= combat.sever_energy and not _severed[part]:
		_severed[part] = true
		limb_severed.emit(part)


## Multiplicador de força do membro: 0 se decepado, cai com a vida até `min_limb_strength`.
func limb_strength(part: int) -> float:
	if _severed[part]:
		return 0.0
	return lerpf(_tuning.min_limb_strength, 1.0, _health[part] / max_health(part))
