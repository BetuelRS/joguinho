class_name HitEvent
extends RefCounted
## Acerto de arma em corpo. `damage` é preenchido pelo CombatResolver.

var tick: int = 0
var attacker_id: int = -1
var target_id: int = -1
var weapon_id: StringName
var zone: int = WeaponZone.Kind.EDGE
var part: int = BodyPart.Kind.TORSO
var hit_type: int = HitType.Kind.BLUNT
var energy: float = 0.0
var point: Vector3 = Vector3.ZERO
var damage: float = 0.0
