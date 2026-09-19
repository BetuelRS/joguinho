class_name FighterTuning
extends Resource
## Parâmetros ajustáveis do corpo do lutador.

@export_group("Vida")
@export var head_max_health: float = 60.0
@export var torso_max_health: float = 120.0
@export var limb_max_health: float = 80.0
## Força de um membro com vida zero (mas não decepado).
@export var min_limb_strength: float = 0.3

@export_group("Equilíbrio")
@export var balance_max: float = 100.0
@export var balance_regen_per_s: float = 25.0
## Tempo sem impacto antes de o equilíbrio começar a regenerar.
@export var balance_regen_delay: float = 0.5
## Tempo no chão antes de levantar.
@export var balance_recovery_time: float = 1.0
@export var balance_recovered_value: float = 40.0
## Força mínima da mola da pelve com equilíbrio quase zero (fração de 1).
@export var min_support_factor: float = 0.6

@export_group("Stamina")
@export var stamina_max: float = 100.0
@export var stamina_regen_per_s: float = 20.0
@export var stamina_regen_delay: float = 0.6
@export var cost_thrust: float = 12.0
@export var cost_kick: float = 15.0
@export var cost_dodge: float = 20.0
@export var cost_parry: float = 8.0
@export var tension_per_s: float = 15.0
@export var sprint_per_s: float = 10.0
## Multiplicador de força muscular quando a stamina acaba.
@export var exhausted_strength: float = 0.6
## Stamina precisa voltar a este valor para sair da exaustão.
@export var exhaustion_recover_threshold: float = 25.0
