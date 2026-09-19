class_name CombatTuning
extends Resource
## Parâmetros ajustáveis do combate. Editados ao vivo pelo painel de ajuste (SP1-D).

@export_group("Dano")
## Abaixo desta energia (J) o contato é raspão: sem dano, sem dreno.
@export var graze_energy: float = 10.0
@export var damage_per_joule: float = 0.5
@export var cut_mult: float = 1.0
@export var thrust_mult: float = 1.3
@export var blunt_mult: float = 0.6
@export var head_mult: float = 2.0
@export var torso_mult: float = 1.0
@export var arm_mult: float = 0.7
@export var leg_mult: float = 0.8
## Energia mínima (J) de um corte para decepar um membro já zerado.
@export var sever_energy: float = 120.0

@export_group("Classificação")
@export var cut_max_angle_deg: float = 35.0
@export var thrust_max_angle_deg: float = 25.0

@export_group("Equilíbrio")
@export var balance_per_joule_cut: float = 0.05
@export var balance_per_joule_thrust: float = 0.08
@export var balance_per_joule_blunt: float = 0.25
## Dreno de equilíbrio por unidade de diferença de momentum (kg·m/s) num choque.
@export var clash_balance_per_momentum: float = 4.0

@export_group("Parry")
## Tempo (s) desde que o RMB foi pressionado em que um contato conta como parry.
@export var parry_window: float = 0.15
## Velocidade mínima (m/s) da mão livre no contato.
@export var parry_min_speed: float = 3.0


func type_mult(hit_type: int) -> float:
	match hit_type:
		HitType.Kind.CUT:
			return cut_mult
		HitType.Kind.THRUST:
			return thrust_mult
		_:
			return blunt_mult


func part_mult(part: int) -> float:
	if part == BodyPart.Kind.HEAD:
		return head_mult
	if part == BodyPart.Kind.TORSO:
		return torso_mult
	if BodyPart.is_arm(part):
		return arm_mult
	return leg_mult


func balance_per_joule(hit_type: int) -> float:
	match hit_type:
		HitType.Kind.CUT:
			return balance_per_joule_cut
		HitType.Kind.THRUST:
			return balance_per_joule_thrust
		_:
			return balance_per_joule_blunt
