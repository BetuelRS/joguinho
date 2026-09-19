class_name WeaponSection
extends Resource
## Bloco de massa da arma, alinhado ao eixo Y local. Base para massa, inércia e zonas.

enum Kind { POMMEL, HANDLE, GUARD, BLADE, SHAFT, HEAD }

@export var kind: Kind = Kind.BLADE
@export var y_from: float = 0.0
@export var y_to: float = 0.0
@export var half_width: float = 0.0
@export var half_thickness: float = 0.0
@export var mass: float = 0.0


func center_y() -> float:
	return (y_from + y_to) * 0.5


static func make(kind: int, y_from: float, y_to: float, half_width: float, half_thickness: float, mass: float) -> WeaponSection:
	var s := WeaponSection.new()
	s.kind = kind
	s.y_from = y_from
	s.y_to = y_to
	s.half_width = half_width
	s.half_thickness = half_thickness
	s.mass = mass
	return s
