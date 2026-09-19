class_name WeaponCatalog
extends RefCounted
## Armas do SP1. As armas fantasiosas chegam no SP3.


## ~1,4 kg, ~1,12 m, CoM ~14 cm à frente da guarda.
static func longsword() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"longsword"
	w.display_name = "Espada longa"
	w.double_edged = true
	w.tip_length = 0.12
	w.grip_primary = -0.06
	w.grip_secondary = -0.18
	w.sections = [
		WeaponSection.make(WeaponSection.Kind.POMMEL, -0.27, -0.24, 0.025, 0.025, 0.35),
		WeaponSection.make(WeaponSection.Kind.HANDLE, -0.24, 0.0, 0.015, 0.015, 0.15),
		WeaponSection.make(WeaponSection.Kind.GUARD, 0.0, 0.02, 0.10, 0.012, 0.20),
		WeaponSection.make(WeaponSection.Kind.BLADE, 0.02, 0.85, 0.025, 0.003, 0.70),
	]
	return w


## ~5 kg, ~0,9 m, massa concentrada na cabeça.
static func hammer() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"hammer"
	w.display_name = "Marreta"
	w.double_edged = false
	w.tip_length = 0.0
	w.grip_primary = -0.05
	w.grip_secondary = 0.25
	w.sections = [
		WeaponSection.make(WeaponSection.Kind.SHAFT, -0.12, 0.70, 0.018, 0.018, 1.2),
		WeaponSection.make(WeaponSection.Kind.HEAD, 0.70, 0.78, 0.09, 0.045, 3.8),
	]
	return w


static func all() -> Array[WeaponData]:
	return [longsword(), hammer()]
