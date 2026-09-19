class_name ClashEvent
extends RefCounted
## Choque arma↔arma (ou arma↔mão livre). Consumido por efeitos (SP1), fratura (SP3), áudio e estilo (SP4).

var tick: int = 0
var energy: float = 0.0
## Ângulo entre as lâminas no contato (radianos).
var angle: float = 0.0
var point: Vector3 = Vector3.ZERO
var weapon_a: StringName
var zone_a: int = WeaponZone.Kind.EDGE
var weapon_b: StringName
var zone_b: int = WeaponZone.Kind.EDGE
var fighter_a: int = -1
var fighter_b: int = -1
## Momentum (kg·m/s) de cada arma no ponto de contato.
var momentum_a: float = 0.0
var momentum_b: float = 0.0
