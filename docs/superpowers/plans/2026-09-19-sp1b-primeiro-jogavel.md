# SP1-B — Corpo físico e primeiro jogável — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jogar pela primeira vez. Um lutador com corpo físico (ragdoll ativo "híbrido firme") anda pela arena cinza, a mão da arma segue o mouse, espada ou marreta com peso real, câmera 1ª/3ª pessoa, e um boneco que recebe dano, perde equilíbrio e cai.

**Architecture:** A lógica pura do SP1-A (`src/sim/`) ganha uma camada de nós físicos, também em `src/sim/` (corpos, juntas, controladores). Tudo roda em `_physics_process` a 120 Hz, lendo um `InputCommand` por tick. `src/view/` tem câmera, HUD e cena de sandbox. Controladores físicos são funções puras testáveis (`ControlMath`, `ReachMapper`) aplicadas por nós finos. O contato arma→corpo nesta etapa é o **básico** (energia → tipo → dano via `CombatResolver`). Choque arma↔arma com disputa, parry, agarrar etc. ficam no SP1-C.

**Tech Stack:** Godot 4.6.3, Jolt Physics, GDScript tipado, GUT 9.6.1.

**Spec:** `docs/superpowers/specs/2026-09-19-joguinho-design.md` (Parte 2). Pendências herdadas: seção "Pendências herdadas da revisão final do SP1-A" em `docs/superpowers/plans/2026-09-19-sp1a-fundacao.md`.

## Global Constraints

- Física a 120 Hz fixo. Todos os controladores rodam em `_physics_process` (ou `_integrate_forces`) com `delta` do tick.
- Nada em `src/sim/` referencia `src/view/`. Os controladores leem apenas `InputCommand`.
- GDScript com tipagem estática. Unidades SI.
- Espaço do lutador: `+Y` cima, `-Z` frente, `+X` direita. Altura ~1,8 m, massa ~70 kg.
- Espaço local da arma (SP1-A): origem na base da guarda, `+Y` para a ponta, `+X` fio principal, `+Z` normal da chapa.
- O corpo da arma usa `center_of_mass_mode = CUSTOM` e `inertia` vindos de `WeaponData` (nunca da malha); `continuous_cd = true`.
- Segmentos do próprio lutador não colidem entre si nem com a própria arma.
- Camadas de colisão: 1 = mundo, 2 = corpos, 3 = armas.
- Parâmetros ajustáveis vivem em `Resource`s de tuning (`HandTuning`, `LocomotionTuning`), nunca como números mágicos nos nós.
- Testes físicos usam `await wait_physics_frames(n)`; cada teste de cena usa `add_child_autofree`. Para acelerar, `before_all` pode usar `Engine.time_scale = 4.0` e restaurar em `after_all`.
- Ações únicas do `InputCommand` (`jump`, `dodge`, `thrust`, `kick`, `grip_toggle`, `throw`, `lock_on_toggle`) significam "apertado neste tick"; `sprint`, `crouch`, `tension`, `free_hand_mode` significam "segurado".
- `BodyHealth.limb_strength()` do braço da arma reduz **força** e **precisão** da mão.
- Lutador morto: `Balance` para de rodar, sem suporte da pelve (ragdoll), ignora input.
- Commits terminam com a linha `Co-Authored-By:` do modelo que implementou.

## File Structure

| Arquivo | Responsabilidade |
|---|---|
| `src/sim/control/control_math.gd` | `ControlMath`: torque PD entre orientações, força de mola limitada |
| `src/sim/control/hand_tuning.gd` | `HandTuning` Resource |
| `src/sim/control/locomotion_tuning.gd` | `LocomotionTuning` Resource |
| `src/sim/control/reach_mapper.gd` | `ReachMapper`: mouse → alvo da mão na esfera de alcance, com transbordo de giro e precisão |
| `src/sim/input/input_bindings.gd` | `InputBindings`: registra as ações padrão no `InputMap` |
| `src/sim/input/input_sampler.gd` | `InputSampler`: estado bruto de teclas/mouse → `InputCommand` por tick (puro) |
| `src/sim/weapon/weapon_body.gd` | `WeaponBody` (RigidBody3D) construído de `WeaponData` |
| `src/sim/fighter/fighter_body_spec.gd` | `FighterBodySpec`: dados dos segmentos e juntas do manequim |
| `src/sim/fighter/fighter_body.gd` | `FighterBody` (Node3D): constrói segmentos + juntas a partir do spec |
| `src/sim/fighter/locomotion.gd` | `Locomotion`: ponto de controle, suporte da pelve, postura, passadas |
| `src/sim/fighter/hand_controller.gd` | `HandController`: mão segue alvo, tensão, pegada 1/2 mãos, giro do fio |
| `src/sim/fighter/fighter.gd` | `Fighter` (Node3D): junta corpo + estado (vida/equilíbrio/stamina) + controladores; aplica `InputCommand` por tick |
| `src/sim/combat/contact_probe.gd` | `ContactProbe`: contato arma→segmento → `HitEvent` → `CombatResolver` (básico) |
| `src/view/player_input.gd` | `PlayerInput`: lê `Input` e alimenta o `Fighter` do jogador |
| `src/view/fighter_camera.gd` | `FighterCamera`: 3ª pessoa (SpringArm3D) / 1ª pessoa, V alterna, lock-on |
| `src/view/arena_builder.gd` | `ArenaBuilder`: chão com grade, parede, pilar, degrau (por código) |
| `src/view/hud.gd` | `Hud`: vida por parte, equilíbrio, stamina, último acerto |
| `src/view/sandbox.gd` + `scenes/sandbox.tscn` | Cena jogável: arena + jogador + boneco + troca de arma |
| `tests/...` | Um teste por unidade, espelhando `src/` |

---

### Task 1: `ControlMath`, `HandTuning`, `LocomotionTuning`

**Implementer:** executor (sonnet).

**Files:**
- Create: `src/sim/control/control_math.gd`, `src/sim/control/hand_tuning.gd`, `src/sim/control/locomotion_tuning.gd`
- Test: `tests/sim/control/test_control_math.gd`

**Interfaces:**
- Produces:
  - `ControlMath.pd_torque(current: Basis, target: Basis, rel_ang_vel: Vector3, stiffness: float, damping: float, max_torque: float) -> Vector3` — torque no espaço do mundo que gira `current` em direção a `target`; `rel_ang_vel` = velocidade angular do filho menos a do pai.
  - `ControlMath.spring_force(pos: Vector3, vel: Vector3, target: Vector3, target_vel: Vector3, stiffness: float, damping: float, max_force: float) -> Vector3`
  - `HandTuning` e `LocomotionTuning` com os campos do código abaixo.

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest


func test_pd_torque_zero_when_aligned_and_still() -> void:
	var t := ControlMath.pd_torque(Basis(), Basis(), Vector3.ZERO, 100.0, 10.0, 1000.0)
	assert_almost_eq(t, Vector3.ZERO, Vector3.ONE * 1e-5)


func test_pd_torque_points_along_rotation_axis() -> void:
	var target := Basis(Vector3.UP, deg_to_rad(90.0))
	var t := ControlMath.pd_torque(Basis(), target, Vector3.ZERO, 100.0, 0.0, 1000.0)
	assert_gt(t.y, 0.0)
	assert_almost_eq(t.y, 100.0 * PI / 2.0, 1e-3)
	assert_almost_eq(t.x, 0.0, 1e-4)


func test_pd_torque_takes_shortest_path() -> void:
	var target := Basis(Vector3.UP, deg_to_rad(-170.0))
	var t := ControlMath.pd_torque(Basis(), target, Vector3.ZERO, 1.0, 0.0, 1000.0)
	assert_lt(t.y, 0.0)


func test_pd_torque_damping_opposes_velocity() -> void:
	var t := ControlMath.pd_torque(Basis(), Basis(), Vector3(0, 5, 0), 0.0, 2.0, 1000.0)
	assert_almost_eq(t, Vector3(0, -10, 0), Vector3.ONE * 1e-5)


func test_pd_torque_is_clamped() -> void:
	var target := Basis(Vector3.RIGHT, deg_to_rad(120.0))
	var t := ControlMath.pd_torque(Basis(), target, Vector3.ZERO, 1000.0, 0.0, 50.0)
	assert_almost_eq(t.length(), 50.0, 1e-3)


func test_spring_force_pulls_toward_target() -> void:
	var f := ControlMath.spring_force(Vector3.ZERO, Vector3.ZERO, Vector3(1, 0, 0), Vector3.ZERO, 100.0, 0.0, 1000.0)
	assert_almost_eq(f, Vector3(100, 0, 0), Vector3.ONE * 1e-5)


func test_spring_force_damps_relative_velocity() -> void:
	var f := ControlMath.spring_force(Vector3.ZERO, Vector3(2, 0, 0), Vector3.ZERO, Vector3.ZERO, 0.0, 10.0, 1000.0)
	assert_almost_eq(f, Vector3(-20, 0, 0), Vector3.ONE * 1e-5)


func test_spring_force_is_clamped() -> void:
	var f := ControlMath.spring_force(Vector3.ZERO, Vector3.ZERO, Vector3(10, 0, 0), Vector3.ZERO, 100.0, 0.0, 300.0)
	assert_almost_eq(f.length(), 300.0, 1e-3)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_control_math.gd`
Expected: FAIL — `ControlMath` não existe.

- [ ] **Step 3: Implementar**

`src/sim/control/control_math.gd`:

```gdscript
class_name ControlMath
extends RefCounted
## Controladores físicos básicos: músculo (PD angular) e mola linear limitada.


static func pd_torque(current: Basis, target: Basis, rel_ang_vel: Vector3, stiffness: float, damping: float, max_torque: float) -> Vector3:
	var q_err := (target.get_rotation_quaternion() * current.get_rotation_quaternion().inverse()).normalized()
	if q_err.w < 0.0:
		q_err = -q_err
	var angle := q_err.get_angle()
	var torque := Vector3.ZERO
	if angle > 1e-6:
		torque = q_err.get_axis() * angle * stiffness
	torque -= rel_ang_vel * damping
	return torque.limit_length(max_torque)


static func spring_force(pos: Vector3, vel: Vector3, target: Vector3, target_vel: Vector3, stiffness: float, damping: float, max_force: float) -> Vector3:
	var f := (target - pos) * stiffness + (target_vel - vel) * damping
	return f.limit_length(max_force)
```

`src/sim/control/hand_tuning.gd`:

```gdscript
class_name HandTuning
extends Resource
## Parâmetros da mão da arma.

@export_group("Mouse")
## Radianos de giro do alvo por pixel de mouse.
@export var mouse_sensitivity: float = 0.004
@export var max_yaw_deg: float = 80.0
@export var min_pitch_deg: float = -70.0
@export var max_pitch_deg: float = 85.0
## Fração do alcance do braço onde a mão fica por padrão.
@export var default_extension: float = 0.8
## Velocidade com que o alvo suavizado persegue o mouse (1/s): braço ferido usa o mínimo.
@export var min_follow_rate: float = 6.0
@export var max_follow_rate: float = 40.0

@export_group("Força")
@export var hand_stiffness: float = 900.0
@export var hand_damping: float = 60.0
## Força máxima (N) do braço sem tensão. É o que faz arma pesada parecer pesada.
@export var arm_max_force: float = 350.0
@export var tension_force_mult: float = 1.6
@export var two_hand_force_mult: float = 1.5
## Fração da força da mão devolvida ao peito (reação).
@export var reaction_fraction: float = 0.5

@export_group("Pulso e giro")
@export var wrist_stiffness: float = 40.0
@export var wrist_damping: float = 4.0
@export var wrist_max_torque: float = 30.0
## Radianos por "clique" da roda do mouse.
@export var roll_step: float = deg_to_rad(15.0)

@export_group("Carga")
## Tempo (s) segurando tensão com a mão parada até a carga máxima.
@export var charge_time: float = 1.0
@export var charge_max_mult: float = 1.4
## Velocidade da mão (m/s) abaixo da qual ela conta como parada.
@export var charge_still_speed: float = 0.5
```

`src/sim/control/locomotion_tuning.gd`:

```gdscript
class_name LocomotionTuning
extends Resource
## Parâmetros de locomoção e postura.

@export_group("Movimento")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.8
@export var crouch_speed: float = 1.6
@export var acceleration: float = 18.0
@export var jump_speed: float = 4.2
@export var turn_rate: float = 10.0

@export_group("Pelve")
@export var stand_height: float = 1.0
@export var crouch_height: float = 0.7
@export var pelvis_stiffness: float = 6000.0
@export var pelvis_damping: float = 600.0
@export var pelvis_max_force: float = 2500.0
@export var upright_stiffness: float = 900.0
@export var upright_damping: float = 90.0
@export var upright_max_torque: float = 600.0
## Tempo (s) para a força de suporte voltar ao máximo depois de levantar.
@export var getup_ramp_time: float = 0.6

@export_group("Passadas")
@export var step_trigger_distance: float = 0.28
@export var step_duration: float = 0.22
@export var step_height: float = 0.12
@export var foot_stiffness: float = 1500.0
@export var foot_damping: float = 80.0
@export var foot_max_force: float = 700.0
@export var foot_lateral_offset: float = 0.11
## Quanto a posição-alvo do pé se adianta na direção da velocidade (s).
@export var step_lead_time: float = 0.12

@export_group("Músculos")
@export var spine_stiffness: float = 700.0
@export var spine_damping: float = 60.0
@export var spine_max_torque: float = 500.0
@export var leg_stiffness: float = 500.0
@export var leg_damping: float = 40.0
@export var leg_max_torque: float = 400.0
@export var neck_stiffness: float = 120.0
@export var neck_damping: float = 10.0
@export var neck_max_torque: float = 80.0
```

- [ ] **Step 4: Rodar e ver passar** — `powershell -File tools/run_tests.ps1 -gselect=test_control_math.gd` → 8 PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/sim/control tests/sim/control
git commit -m "feat(sim): add PD torque, spring force and control tuning resources"
```

---

### Task 2: `ReachMapper`

**Implementer:** executor (sonnet).

**Files:**
- Create: `src/sim/control/reach_mapper.gd`
- Test: `tests/sim/control/test_reach_mapper.gd`

**Interfaces:**
- Consumes: `HandTuning`
- Produces:
  - `ReachMapper.new(tuning: HandTuning)`
  - `yaw: float`, `pitch: float`, `extension: float`
  - `apply_mouse(delta_px: Vector2) -> float` — atualiza yaw/pitch; retorna o **transbordo** de yaw (rad) que deve girar o corpo (positivo = direita)
  - `desired_target(reach: float) -> Vector3` — alvo no espaço do ombro (+X direita, +Y cima, −Z frente)
  - `step(dt: float, reach: float, precision: float) -> Vector3` — alvo suavizado; `precision` 0..1 (vem de `limb_strength`) define a velocidade de perseguição entre `min_follow_rate` e `max_follow_rate`
  - `snap(reach: float) -> void` — suavizado = desejado (usado no spawn)

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

var t := HandTuning.new()
var m: ReachMapper


func before_each() -> void:
	m = ReachMapper.new(t)


func test_default_target_is_in_front_at_default_extension() -> void:
	var p := m.desired_target(0.7)
	assert_almost_eq(p, Vector3(0, 0, -0.7 * t.default_extension), Vector3.ONE * 1e-5)


func test_mouse_right_moves_hand_right() -> void:
	m.apply_mouse(Vector2(100, 0))
	assert_gt(m.desired_target(0.7).x, 0.0)


func test_mouse_up_moves_hand_up() -> void:
	m.apply_mouse(Vector2(0, -100))
	assert_gt(m.desired_target(0.7).y, 0.0)


func test_target_stays_on_reach_sphere() -> void:
	m.apply_mouse(Vector2(137, -59))
	assert_almost_eq(m.desired_target(0.7).length(), 0.7 * t.default_extension, 1e-5)


func test_pitch_is_clamped() -> void:
	m.apply_mouse(Vector2(0, -100000))
	assert_almost_eq(m.pitch, deg_to_rad(t.max_pitch_deg), 1e-5)
	m.apply_mouse(Vector2(0, 100000))
	assert_almost_eq(m.pitch, deg_to_rad(t.min_pitch_deg), 1e-5)


func test_yaw_overflow_is_returned_and_yaw_clamped() -> void:
	var limit := deg_to_rad(t.max_yaw_deg)
	var px := (limit + 0.5) / t.mouse_sensitivity
	var overflow := m.apply_mouse(Vector2(px, 0))
	assert_almost_eq(m.yaw, limit, 1e-5)
	assert_almost_eq(overflow, 0.5, 1e-4)


func test_negative_overflow() -> void:
	var limit := deg_to_rad(t.max_yaw_deg)
	var overflow := m.apply_mouse(Vector2(-(limit + 0.3) / t.mouse_sensitivity, 0))
	assert_almost_eq(overflow, -0.3, 1e-4)


func test_no_overflow_inside_limits() -> void:
	assert_eq(m.apply_mouse(Vector2(10, 0)), 0.0)


func test_low_precision_follows_slower() -> void:
	var precise := ReachMapper.new(t)
	var sloppy := ReachMapper.new(t)
	precise.snap(0.7)
	sloppy.snap(0.7)
	precise.apply_mouse(Vector2(300, 0))
	sloppy.apply_mouse(Vector2(300, 0))
	var goal := precise.desired_target(0.7)
	var a := precise.step(1.0 / 120.0, 0.7, 1.0)
	var b := sloppy.step(1.0 / 120.0, 0.7, 0.0)
	assert_lt(a.distance_to(goal), b.distance_to(goal))


func test_step_converges() -> void:
	m.snap(0.7)
	m.apply_mouse(Vector2(200, -100))
	var goal := m.desired_target(0.7)
	var p := Vector3.ZERO
	for i in 120:
		p = m.step(1.0 / 120.0, 0.7, 1.0)
	assert_almost_eq(p, goal, Vector3.ONE * 1e-3)
```

- [ ] **Step 2: Rodar e ver falhar** — `-gselect=test_reach_mapper.gd` → FAIL.

- [ ] **Step 3: Implementar**

```gdscript
class_name ReachMapper
extends RefCounted
## Mouse → alvo da mão numa esfera de alcance à frente do ombro.
## Espaço do ombro: +X direita, +Y cima, -Z frente.

var yaw: float = 0.0
var pitch: float = 0.0
var extension: float

var _tuning: HandTuning
var _smoothed: Vector3 = Vector3.ZERO


func _init(tuning: HandTuning) -> void:
	_tuning = tuning
	extension = tuning.default_extension


## Retorna quanto do giro horizontal passou do limite e deve girar o corpo.
func apply_mouse(delta_px: Vector2) -> float:
	yaw += delta_px.x * _tuning.mouse_sensitivity
	pitch -= delta_px.y * _tuning.mouse_sensitivity
	pitch = clampf(pitch, deg_to_rad(_tuning.min_pitch_deg), deg_to_rad(_tuning.max_pitch_deg))
	var limit := deg_to_rad(_tuning.max_yaw_deg)
	var overflow := 0.0
	if yaw > limit:
		overflow = yaw - limit
		yaw = limit
	elif yaw < -limit:
		overflow = yaw + limit
		yaw = -limit
	return overflow


func desired_target(reach: float) -> Vector3:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	return dir * reach * extension


func step(dt: float, reach: float, precision: float) -> Vector3:
	var rate := lerpf(_tuning.min_follow_rate, _tuning.max_follow_rate, clampf(precision, 0.0, 1.0))
	_smoothed = _smoothed.lerp(desired_target(reach), 1.0 - exp(-rate * dt))
	return _smoothed


func snap(reach: float) -> void:
	_smoothed = desired_target(reach)
```

- [ ] **Step 4: Rodar e ver passar** — 10 PASS.

- [ ] **Step 5: Commit** — `git add src/sim/control/reach_mapper.gd tests/sim/control/test_reach_mapper.gd` + `.uid`; mensagem `feat(sim): map mouse to hand target on reach sphere`.

---

### Task 3: `InputBindings` e `InputSampler`

**Implementer:** executor (sonnet).

**Files:**
- Create: `src/sim/input/input_bindings.gd`, `src/sim/input/input_sampler.gd`
- Test: `tests/sim/input/test_input_sampler.gd`

**Interfaces:**
- Produces:
  - `InputBindings.ensure_defaults() -> void` — cria no `InputMap` (se não existirem) as ações: `move_forward` W, `move_back` S, `move_left` A, `move_right` D, `sprint` Shift, `jump` Espaço, `crouch` Ctrl, `dodge` C, `tension` LMB, `free_hand` RMB, `thrust` F, `kick` X, `grip_toggle` G, `throw` T, `lock_on` botão do meio, `camera_toggle` V, `weapon_1` 1, `weapon_2` 2, `debug_panel` F1, `release_mouse` Esc.
  - `InputSampler.new(tuning: HandTuning)`; `held: Dictionary` (StringName → bool) e `pressed: Dictionary` (StringName → bool, apertado desde o último tick), `mouse_delta: Vector2`, `wheel_steps: int`
  - `InputSampler.build_command(tick: int, mapper: ReachMapper, roll: float, reach: float, precision: float, dt: float) -> InputCommand` — aplica `mouse_delta` ao `mapper` (transbordo → `look_yaw_delta`) exceto quando `free_hand` está segurado (aí o mouse move `free_hand_target` por um segundo `ReachMapper` interno); preenche o comando; **zera** `pressed`, `mouse_delta` e `wheel_steps` (consumidos).
  - `InputSampler.roll_delta(roll_step: float) -> float` é incorporado: `blade_roll = roll + wheel_steps * roll_step`.

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

var ht := HandTuning.new()
var s: InputSampler
var mapper: ReachMapper
const DT := 1.0 / 120.0


func before_each() -> void:
	s = InputSampler.new(ht)
	mapper = ReachMapper.new(ht)
	mapper.snap(0.7)


func test_bindings_register_actions() -> void:
	InputBindings.ensure_defaults()
	for a in [&"move_forward", &"tension", &"free_hand", &"thrust", &"camera_toggle", &"weapon_2"]:
		assert_true(InputMap.has_action(a), str(a))


func test_move_vector_from_held_keys() -> void:
	s.held[&"move_forward"] = true
	s.held[&"move_right"] = true
	var c := s.build_command(1, mapper, 0.0, 0.7, 1.0, DT)
	assert_almost_eq(c.move, Vector2(1, 1).normalized(), Vector2.ONE * 1e-5)


func test_held_flags_copy() -> void:
	s.held[&"sprint"] = true
	s.held[&"tension"] = true
	var c := s.build_command(1, mapper, 0.0, 0.7, 1.0, DT)
	assert_true(c.sprint)
	assert_true(c.tension)
	assert_false(c.crouch)


func test_pressed_is_one_shot() -> void:
	s.pressed[&"jump"] = true
	var first := s.build_command(1, mapper, 0.0, 0.7, 1.0, DT)
	var second := s.build_command(2, mapper, 0.0, 0.7, 1.0, DT)
	assert_true(first.jump)
	assert_false(second.jump)


func test_mouse_moves_hand_target() -> void:
	var before := s.build_command(1, mapper, 0.0, 0.7, 1.0, DT).hand_target
	s.mouse_delta = Vector2(200, 0)
	for i in 60:
		s.build_command(2 + i, mapper, 0.0, 0.7, 1.0, DT)
	var after := s.build_command(100, mapper, 0.0, 0.7, 1.0, DT).hand_target
	assert_gt(after.x, before.x)


func test_free_hand_mode_moves_free_hand_not_weapon_hand() -> void:
	var weapon_before := s.build_command(1, mapper, 0.0, 0.7, 1.0, DT).hand_target
	s.held[&"free_hand"] = true
	s.mouse_delta = Vector2(200, 0)
	var c := s.build_command(2, mapper, 0.0, 0.7, 1.0, DT)
	for i in 60:
		c = s.build_command(3 + i, mapper, 0.0, 0.7, 1.0, DT)
	assert_true(c.free_hand_mode)
	assert_almost_eq(c.hand_target, weapon_before, Vector3.ONE * 1e-4)
	assert_ne(c.free_hand_target, Vector3.ZERO)


func test_yaw_overflow_becomes_look_delta() -> void:
	s.mouse_delta = Vector2(100000, 0)
	var c := s.build_command(1, mapper, 0.0, 0.7, 1.0, DT)
	assert_gt(c.look_yaw_delta, 0.0)


func test_wheel_rotates_blade() -> void:
	s.wheel_steps = 2
	var c := s.build_command(1, mapper, 0.1, 0.7, 1.0, DT)
	assert_almost_eq(c.blade_roll, 0.1 + 2.0 * ht.roll_step, 1e-5)


func test_tick_is_set() -> void:
	assert_eq(s.build_command(77, mapper, 0.0, 0.7, 1.0, DT).tick, 77)
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar**

`src/sim/input/input_bindings.gd`:

```gdscript
class_name InputBindings
extends RefCounted
## Ações padrão do jogo. Remapeáveis depois pelo InputMap.


static func ensure_defaults() -> void:
	_key(&"move_forward", KEY_W)
	_key(&"move_back", KEY_S)
	_key(&"move_left", KEY_A)
	_key(&"move_right", KEY_D)
	_key(&"sprint", KEY_SHIFT)
	_key(&"jump", KEY_SPACE)
	_key(&"crouch", KEY_CTRL)
	_key(&"dodge", KEY_C)
	_key(&"thrust", KEY_F)
	_key(&"kick", KEY_X)
	_key(&"grip_toggle", KEY_G)
	_key(&"throw", KEY_T)
	_key(&"camera_toggle", KEY_V)
	_key(&"weapon_1", KEY_1)
	_key(&"weapon_2", KEY_2)
	_key(&"debug_panel", KEY_F1)
	_key(&"release_mouse", KEY_ESCAPE)
	_mouse(&"tension", MOUSE_BUTTON_LEFT)
	_mouse(&"free_hand", MOUSE_BUTTON_RIGHT)
	_mouse(&"lock_on", MOUSE_BUTTON_MIDDLE)


static func _key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


static func _mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
```

`src/sim/input/input_sampler.gd`:

```gdscript
class_name InputSampler
extends RefCounted
## Estado bruto de input → InputCommand por tick. Não lê `Input` diretamente (testável);
## quem alimenta `held`, `pressed`, `mouse_delta` e `wheel_steps` é o PlayerInput (view) ou um bot.

var held: Dictionary = {}
var pressed: Dictionary = {}
var mouse_delta: Vector2 = Vector2.ZERO
var wheel_steps: int = 0

var _tuning: HandTuning
var _free_mapper: ReachMapper


func _init(tuning: HandTuning) -> void:
	_tuning = tuning
	_free_mapper = ReachMapper.new(tuning)


func build_command(tick: int, mapper: ReachMapper, roll: float, reach: float, precision: float, dt: float) -> InputCommand:
	var c := InputCommand.new()
	c.tick = tick
	var mv := Vector2(
		float(_is(&"move_right")) - float(_is(&"move_left")),
		float(_is(&"move_forward")) - float(_is(&"move_back")))
	c.move = mv.normalized() if mv.length_squared() > 1.0 else mv
	c.sprint = _is(&"sprint")
	c.crouch = _is(&"crouch")
	c.tension = _is(&"tension")
	c.free_hand_mode = _is(&"free_hand")
	c.jump = _was(&"jump")
	c.dodge = _was(&"dodge")
	c.thrust = _was(&"thrust")
	c.kick = _was(&"kick")
	c.grip_toggle = _was(&"grip_toggle")
	c.throw = _was(&"throw")
	c.lock_on_toggle = _was(&"lock_on")
	if c.free_hand_mode:
		_free_mapper.apply_mouse(mouse_delta)
	else:
		c.look_yaw_delta = mapper.apply_mouse(mouse_delta)
	c.hand_target = mapper.step(dt, reach, precision)
	c.free_hand_target = _free_mapper.step(dt, reach, 1.0)
	c.blade_roll = roll + float(wheel_steps) * _tuning.roll_step
	pressed.clear()
	mouse_delta = Vector2.ZERO
	wheel_steps = 0
	return c


func _is(action: StringName) -> bool:
	return held.get(action, false)


func _was(action: StringName) -> bool:
	return pressed.get(action, false)
```

- [ ] **Step 4: Rodar e ver passar** — 9 PASS.

- [ ] **Step 5: Commit** — `feat(sim): add input bindings and per-tick input sampler`.

---

### Task 4: `WeaponBody`

**Implementer:** executor (sonnet).

**Files:**
- Create: `src/sim/weapon/weapon_body.gd`
- Test: `tests/sim/weapon/test_weapon_body.gd`

**Interfaces:**
- Consumes: `WeaponData`, `WeaponSection`, `WeaponCatalog`
- Produces:
  - `WeaponBody extends RigidBody3D`; `static func create(data: WeaponData) -> WeaponBody`
  - `data: WeaponData`
  - Configuração: `mass = data.total_mass()`, `center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM`, `center_of_mass = data.center_of_mass()`, `inertia = data.inertia_about_com()`, `continuous_cd = true`, `contact_monitor = true`, `max_contacts_reported = 8`, `collision_layer = 1 << 2` (camada 3), `collision_mask = (1 << 0) | (1 << 1) | (1 << 2)`.
  - Uma `CollisionShape3D` com `BoxShape3D` por seção (tamanho `(2·half_width, y_to−y_from, 2·half_thickness)`, posição no centro da seção) e uma `MeshInstance3D` `BoxMesh` correspondente (visual provisório, cinza metálico para lâmina/cabeça, marrom para cabo).
  - `grip_local(primary: bool) -> Vector3` = `Vector3(0, data.grip_primary ou grip_secondary, 0)`.
  - `point_velocity(world_point: Vector3) -> Vector3` = `linear_velocity + angular_velocity.cross(world_point - global_transform * center_of_mass)`.

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest


func test_mass_and_inertia_from_data() -> void:
	var data := WeaponCatalog.hammer()
	var w := WeaponBody.create(data)
	add_child_autofree(w)
	assert_almost_eq(w.mass, 5.0, 1e-3)
	assert_eq(w.center_of_mass_mode, RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM)
	assert_almost_eq(w.center_of_mass, data.center_of_mass(), Vector3.ONE * 1e-5)
	assert_almost_eq(w.inertia, data.inertia_about_com(), Vector3.ONE * 1e-5)
	assert_true(w.continuous_cd)


func test_one_shape_per_section() -> void:
	var data := WeaponCatalog.longsword()
	var w := WeaponBody.create(data)
	add_child_autofree(w)
	var shapes := 0
	for c in w.get_children():
		if c is CollisionShape3D:
			shapes += 1
	assert_eq(shapes, data.sections.size())


func test_collision_layer_is_weapons() -> void:
	var w := WeaponBody.create(WeaponCatalog.longsword())
	add_child_autofree(w)
	assert_eq(w.collision_layer, 1 << 2)


func test_falls_and_rests_on_floor() -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor)
	var w := WeaponBody.create(WeaponCatalog.longsword())
	w.position = Vector3(0, 1.0, 0)
	w.rotation = Vector3(0, 0, deg_to_rad(90))
	add_child_autofree(w)
	await wait_physics_frames(360)
	assert_between(w.global_position.y, -0.05, 0.3)
	assert_lt(w.linear_velocity.length(), 0.2)


func test_point_velocity_includes_rotation() -> void:
	var w := WeaponBody.create(WeaponCatalog.longsword())
	w.gravity_scale = 0.0
	add_child_autofree(w)
	w.angular_velocity = Vector3(0, 0, 10)
	var tip := w.global_transform * Vector3(0, 0.85, 0)
	assert_gt(w.point_velocity(tip).length(), 5.0)
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar**

```gdscript
class_name WeaponBody
extends RigidBody3D
## Corpo físico de uma arma. Massa, centro de massa e inércia vêm de WeaponData, nunca da malha.

const LAYER_WEAPONS := 1 << 2
const MASK_ALL := (1 << 0) | (1 << 1) | (1 << 2)

var data: WeaponData


static func create(weapon: WeaponData) -> WeaponBody:
	var w := WeaponBody.new()
	w.data = weapon
	w.name = String(weapon.id)
	w.mass = weapon.total_mass()
	w.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	w.center_of_mass = weapon.center_of_mass()
	w.inertia = weapon.inertia_about_com()
	w.continuous_cd = true
	w.contact_monitor = true
	w.max_contacts_reported = 8
	w.collision_layer = LAYER_WEAPONS
	w.collision_mask = MASK_ALL
	for s in weapon.sections:
		var size := Vector3(s.half_width * 2.0, s.y_to - s.y_from, s.half_thickness * 2.0)
		var center := Vector3(0.0, s.center_y(), 0.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = center
		w.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		mesh.position = center
		mesh.material_override = _material_for(s.kind)
		w.add_child(mesh)
	return w


func grip_local(primary: bool) -> Vector3:
	return Vector3(0.0, data.grip_primary if primary else data.grip_secondary, 0.0)


func point_velocity(world_point: Vector3) -> Vector3:
	var com_world := global_transform * center_of_mass
	return linear_velocity + angular_velocity.cross(world_point - com_world)


static func _material_for(kind: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match kind:
		WeaponSection.Kind.BLADE, WeaponSection.Kind.HEAD, WeaponSection.Kind.GUARD, WeaponSection.Kind.POMMEL:
			m.albedo_color = Color(0.72, 0.74, 0.78)
			m.metallic = 0.9
			m.roughness = 0.3
		_:
			m.albedo_color = Color(0.35, 0.22, 0.12)
			m.roughness = 0.8
	return m
```

- [ ] **Step 4: Rodar e ver passar** — 5 PASS.

- [ ] **Step 5: Commit** — `feat(sim): build weapon rigid body from weapon data`.

---

### Task 5: `FighterBodySpec` e `FighterBody` (ragdoll passivo)

**Implementer:** physics-engineer (opus).

**Files:**
- Create: `src/sim/fighter/fighter_body_spec.gd`, `src/sim/fighter/fighter_body.gd`
- Test: `tests/sim/fighter/test_fighter_body.gd`

**Interfaces:**
- Consumes: `BodyPart`
- Produces:
  - `FighterBodySpec` (RefCounted) com `segments: Array[Dictionary]` e `joints: Array[Dictionary]`; `static func default_human() -> FighterBodySpec`; `total_mass() -> float`; `reach() -> float` (distância ombro→centro da mão, braço estendido).
    - Segmento: `{name: StringName, shape: &"box"|&"capsule"|&"sphere", size: Vector3 (box: tamanho; capsule: (raio, altura total, 0); sphere: (raio,0,0)), mass: float, center: Vector3, part: int}`
    - Junta: `{name: StringName, a: StringName, b: StringName, anchor: Vector3, lower: Vector3 (graus, eixos X/Y/Z), upper: Vector3}`
  - `FighterBody extends Node3D`: `build(spec: FighterBodySpec) -> void`; `segments: Dictionary` (StringName → RigidBody3D); `joints: Dictionary` (StringName → Generic6DOFJoint3D); `segment_part: Dictionary` (RigidBody3D → int `BodyPart.Kind`); `sever(joint_name: StringName) -> void` (remove a junta); `set_ragdoll_collision_exceptions(extra: Array[PhysicsBody3D]) -> void` (segmentos não colidem entre si nem com `extra`, ex.: a própria arma); `center_of_mass_world() -> Vector3`.
  - Segmentos: `collision_layer = 1 << 1`, `collision_mask = (1 << 0) | (1 << 1) | (1 << 2)`, `continuous_cd = false`, `can_sleep = false`, `angular_damp = 1.0`, `linear_damp = 0.05`. Cada segmento tem `MeshInstance3D` provisório com a mesma forma (cor clara de manequim).

**Dados do manequim (`default_human`)** — em pé, voltado para −Z, lado direito = +X:

| Segmento | Forma | Tamanho | Massa | Centro | Parte |
|---|---|---|---|---|---|
| pelvis | box | (0.32, 0.16, 0.20) | 10 | (0, 1.00, 0) | TORSO |
| abdomen | box | (0.30, 0.18, 0.18) | 8 | (0, 1.17, 0) | TORSO |
| chest | box | (0.38, 0.28, 0.22) | 14 | (0, 1.40, 0) | TORSO |
| head | sphere | (0.11) | 5 | (0, 1.67, 0) | HEAD |
| upper_arm_r / _l | capsule | (0.05, 0.30) | 2.2 | (±0.25, 1.37, 0) | ARM_R / ARM_L |
| forearm_r / _l | capsule | (0.045, 0.27) | 1.4 | (±0.25, 1.085, 0) | ARM_R / ARM_L |
| hand_r / _l | box | (0.08, 0.10, 0.04) | 0.5 | (±0.25, 0.90, 0) | ARM_R / ARM_L |
| thigh_r / _l | capsule | (0.07, 0.44) | 8 | (±0.10, 0.70, 0) | LEG_R / LEG_L |
| shin_r / _l | capsule | (0.055, 0.42) | 4 | (±0.10, 0.27, 0) | LEG_R / LEG_L |
| foot_r / _l | box | (0.10, 0.06, 0.26) | 1.2 | (±0.10, 0.03, −0.05) | LEG_R / LEG_L |

| Junta | a → b | Âncora | Limites (graus, X/Y/Z) |
|---|---|---|---|
| spine_low | pelvis → abdomen | (0, 1.08, 0) | (−30,−30,−20) a (40,30,20) |
| spine_high | abdomen → chest | (0, 1.26, 0) | (−20,−30,−20) a (30,30,20) |
| neck | chest → head | (0, 1.55, 0) | (−40,−70,−30) a (40,70,30) |
| shoulder_r / _l | chest → upper_arm | (±0.25, 1.52, 0) | (−170,−90,−100) a (170,90,100) |
| elbow_r / _l | upper_arm → forearm | (±0.25, 1.22, 0) | flexão só em um sentido, 0–150°; torção do antebraço ±80° |
| wrist_r / _l | forearm → hand | (±0.25, 0.95, 0) | (−70,−60,−40) a (70,60,40) |
| hip_r / _l | pelvis → thigh | (±0.10, 0.92, 0) | flexão −110..40, abdução −30..60 (espelhado), torção ±40 |
| knee_r / _l | thigh → shin | (±0.10, 0.48, 0) | dobra só para trás, 0–150°; demais eixos travados |
| ankle_r / _l | shin → foot | (±0.10, 0.06, 0) | (−40,−10,−20) a (40,10,20) |

O sinal exato dos limites de cotovelo, joelho e quadril depende da convenção de eixos do `Generic6DOFJoint3D` + Jolt. **O implementador determina os sinais empiricamente** com os testes abaixo e registra a convenção num comentário no topo de `fighter_body_spec.gd`.

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

func before_all() -> void:
	Engine.time_scale = 4.0


func after_all() -> void:
	Engine.time_scale = 1.0


func _floor() -> StaticBody3D:
	var f := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(20, 1, 20)
	s.shape = b
	f.add_child(s)
	f.position = Vector3(0, -0.5, 0)
	add_child_autofree(f)
	return f


func _body() -> FighterBody:
	var body := FighterBody.new()
	add_child_autofree(body)
	body.build(FighterBodySpec.default_human())
	return body


func test_spec_mass_is_human() -> void:
	assert_between(FighterBodySpec.default_human().total_mass(), 65.0, 78.0)


func test_spec_reach_is_arm_length() -> void:
	assert_between(FighterBodySpec.default_human().reach(), 0.55, 0.7)


func test_builds_all_segments_and_joints() -> void:
	var body := _body()
	assert_eq(body.segments.size(), 16)
	assert_eq(body.joints.size(), 15)


func test_segment_parts_mapped() -> void:
	var body := _body()
	assert_eq(body.segment_part[body.segments[&"head"]], BodyPart.Kind.HEAD)
	assert_eq(body.segment_part[body.segments[&"forearm_r"]], BodyPart.Kind.ARM_R)
	assert_eq(body.segment_part[body.segments[&"shin_l"]], BodyPart.Kind.LEG_L)


func test_passive_ragdoll_collapses_stably() -> void:
	_floor()
	var body := _body()
	await wait_physics_frames(480)
	for seg in body.segments.values():
		var rb := seg as RigidBody3D
		assert_false(is_nan(rb.global_position.y))
		assert_gt(rb.global_position.y, -0.2, "nada atravessa o chão")
		assert_lt(rb.linear_velocity.length(), 0.5, "sem explosão/tremor")
	assert_lt(body.segments[&"head"].global_position.y, 0.6, "sem músculos, cai")


func test_knee_bends_backward_only() -> void:
	_floor()
	var body := _body()
	var shin: RigidBody3D = body.segments[&"shin_r"]
	shin.apply_central_impulse(Vector3(0, 0, -3))  # empurra a canela para a frente
	await wait_physics_frames(30)
	var thigh: RigidBody3D = body.segments[&"thigh_r"]
	var thigh_down := -thigh.global_basis.y
	var shin_down := -shin.global_basis.y
	# O joelho não dobra para a frente: a canela não passa à frente da coxa.
	assert_gt(thigh_down.cross(shin_down).x, -0.2)


func test_sever_detaches_segment() -> void:
	_floor()
	var body := _body()
	body.sever(&"elbow_r")
	assert_false(body.joints.has(&"elbow_r"))
	await wait_physics_frames(240)
	var d := body.segments[&"forearm_r"].global_position.distance_to(body.segments[&"upper_arm_r"].global_position)
	assert_gt(d, 0.05)
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar `FighterBodySpec`** com as tabelas acima (um `Dictionary` por linha, lados direito e esquerdo gerados por um helper que espelha X), `total_mass()` somando massas e `reach()` = distância da âncora do ombro direito ao centro da mão direita.

- [ ] **Step 4: Implementar `FighterBody`**

Referência (ajuste o que for preciso para os testes passarem, sem enfraquecê-los):

```gdscript
class_name FighterBody
extends Node3D
## Corpo físico do lutador: um RigidBody3D por segmento, ligados por Generic6DOFJoint3D com limites.

const LAYER_BODIES := 1 << 1
const MASK_ALL := (1 << 0) | (1 << 1) | (1 << 2)

var spec: FighterBodySpec
var segments: Dictionary = {}      # StringName -> RigidBody3D
var joints: Dictionary = {}        # StringName -> Generic6DOFJoint3D
var segment_part: Dictionary = {}  # RigidBody3D -> int


func build(body_spec: FighterBodySpec) -> void:
	spec = body_spec
	for s in spec.segments:
		var rb := _make_segment(s)
		add_child(rb)
		segments[s.name] = rb
		segment_part[rb] = s.part
	for j in spec.joints:
		var joint := _make_joint(j)
		add_child(joint)
		joint.node_a = joint.get_path_to(segments[j.a])
		joint.node_b = joint.get_path_to(segments[j.b])
		joints[j.name] = joint
	set_ragdoll_collision_exceptions([])


func set_ragdoll_collision_exceptions(extra: Array[PhysicsBody3D]) -> void:
	var all: Array = segments.values()
	for i in all.size():
		for k in range(i + 1, all.size()):
			(all[i] as RigidBody3D).add_collision_exception_with(all[k])
		for e in extra:
			(all[i] as RigidBody3D).add_collision_exception_with(e)


func sever(joint_name: StringName) -> void:
	if not joints.has(joint_name):
		return
	var j: Generic6DOFJoint3D = joints[joint_name]
	joints.erase(joint_name)
	j.queue_free()


func center_of_mass_world() -> Vector3:
	var acc := Vector3.ZERO
	var m := 0.0
	for rb in segments.values():
		acc += (rb as RigidBody3D).global_position * (rb as RigidBody3D).mass
		m += (rb as RigidBody3D).mass
	return acc / m


func _make_segment(s: Dictionary) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = String(s.name)
	rb.mass = s.mass
	rb.position = s.center
	rb.collision_layer = LAYER_BODIES
	rb.collision_mask = MASK_ALL
	rb.can_sleep = false
	rb.angular_damp = 1.0
	rb.linear_damp = 0.05
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	match s.shape:
		&"box":
			var b := BoxShape3D.new()
			b.size = s.size
			cs.shape = b
			var bm := BoxMesh.new()
			bm.size = s.size
			mi.mesh = bm
		&"capsule":
			var c := CapsuleShape3D.new()
			c.radius = s.size.x
			c.height = s.size.y
			cs.shape = c
			var cm := CapsuleMesh.new()
			cm.radius = s.size.x
			cm.height = s.size.y
			mi.mesh = cm
		_:
			var sp := SphereShape3D.new()
			sp.radius = s.size.x
			cs.shape = sp
			var sm := SphereMesh.new()
			sm.radius = s.size.x
			sm.height = s.size.x * 2.0
			mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.82, 0.74)
	mat.roughness = 0.7
	mi.material_override = mat
	rb.add_child(cs)
	rb.add_child(mi)
	return rb


func _make_joint(j: Dictionary) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	joint.name = String(j.name)
	joint.position = j.anchor
	var lo: Vector3 = j.lower
	var hi: Vector3 = j.upper
	joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(lo.x))
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(hi.x))
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(lo.y))
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(hi.y))
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(lo.z))
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(hi.z))
	return joint
```

- [ ] **Step 5: Rodar e ver passar** — 7 PASS. Se o ragdoll tremer, aumente `angular_damp`/iterações de solver do Jolt (`physics/jolt_physics_3d/simulation/velocity_steps`, `position_steps` em `project.godot`) e registre no relatório.

- [ ] **Step 6: Commit** — `feat(sim): build physical mannequin with limited joints`.

---

### Task 6: `Fighter` + `Locomotion` (ficar de pé, andar, cair, levantar)

**Implementer:** physics-engineer (opus).

**Files:**
- Create: `src/sim/fighter/locomotion.gd`, `src/sim/fighter/fighter.gd`
- Test: `tests/sim/fighter/test_locomotion.gd`

**Interfaces:**
- Consumes: `FighterBody`, `FighterBodySpec`, `LocomotionTuning`, `ControlMath`, `Balance`, `BodyHealth`, `Stamina`, `FighterTuning`, `CombatTuning`, `InputCommand`
- Produces:
  - `Fighter extends Node3D`:
    - `@export var fighter_id: int`, `locomotion_tuning: LocomotionTuning`, `hand_tuning: HandTuning`, `fighter_tuning: FighterTuning`, `combat_tuning: CombatTuning` (criados com `.new()` se nulos)
    - `body: FighterBody`, `locomotion: Locomotion`, `health: BodyHealth`, `balance: Balance`, `stamina: Stamina`
    - `facing_yaw: float` (rad; 0 = olhando para −Z)
    - `submit(cmd: InputCommand) -> void` — guarda o comando do próximo tick
    - `is_dead() -> bool`
    - `signal hit_received(hit: HitEvent)`
    - Em `_physics_process(dt)`: se morto, não aplica controle (ragdoll). Senão: `stamina.step`, `balance.step(dt, leg_strength)` onde `leg_strength = min(limb_strength(LEG_L), limb_strength(LEG_R))`, custo de corrida via `stamina.drain_continuous(sprint_per_s)`, depois `locomotion.physics_step(dt, cmd)`.
    - Ao `health.died`: desliga controladores (ragdoll total).
    - Ao `health.limb_severed(part)`: `body.sever(<junta raiz do membro>)` (`shoulder_*` para braço, `hip_*` para perna).
  - `Locomotion extends RefCounted`:
    - `Locomotion.new(body: FighterBody, fighter: Fighter, tuning: LocomotionTuning)`
    - `control_point: Vector3` (posição-alvo no chão sob a pelve), `velocity: Vector3`
    - `physics_step(dt: float, cmd: InputCommand) -> void`:
      1. **Ponto de controle:** acelera em direção a `move` (girado por `facing_yaw`) com `walk/sprint/crouch_speed` e `acceleration`; `facing_yaw += cmd.look_yaw_delta`; pulo = `jump_speed` vertical para pelve e peito se no chão.
      2. **Suporte da pelve:** `ControlMath.spring_force` da pelve até `control_point + (0, stand_height ou crouch_height, 0)` escalado por `balance.support_factor()` × rampa de levantar; força só vertical total + horizontal parcial.
      3. **Postura:** `pd_torque` na pelve e no peito para ficarem em pé com yaw = `facing_yaw`, escalado por `support_factor`; músculos da coluna e pescoço mantêm a pose neutra relativa ao pai (torque +/− no filho/pai).
      4. **Passadas:** cada pé tem posição plantada; quando a distância entre o "lar" do pé (abaixo do quadril + `foot_lateral_offset`, adiantado por `velocity * step_lead_time`) e o plantado passa de `step_trigger_distance` e o outro pé está plantado, inicia passo de `step_duration` com arco de `step_height`. Mola de pé (`foot_*`) puxa o pé ao alvo; músculos das pernas (`leg_*`) mantêm a pose neutra com força × `limb_strength` da perna.
      5. **Queda:** com `balance.is_down`, todas as forças de suporte/postura/pés param (ragdoll). Ao `balance.recovered`, rampa de `getup_ramp_time` reergue.
    - `is_grounded() -> bool` (raycast curto do pé mais baixo, máscara mundo)

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

const DT := 1.0 / 120.0


func before_all() -> void:
	Engine.time_scale = 4.0


func after_all() -> void:
	Engine.time_scale = 1.0


func _world() -> void:
	var f := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(40, 1, 40)
	s.shape = b
	f.add_child(s)
	f.position = Vector3(0, -0.5, 0)
	add_child_autofree(f)


func _fighter() -> Fighter:
	_world()
	var f := Fighter.new()
	add_child_autofree(f)
	return f


func _hold(f: Fighter, frames: int, cmd: InputCommand) -> void:
	for i in frames:
		f.submit(cmd)
		await wait_physics_frames(1)


func _head_y(f: Fighter) -> float:
	return f.body.segments[&"head"].global_position.y


func test_stands_upright_for_five_seconds() -> void:
	var f := _fighter()
	await _hold(f, 600, InputCommand.new())
	assert_gt(_head_y(f), 1.45, "de pé")
	var pelvis: RigidBody3D = f.body.segments[&"pelvis"]
	assert_lt(Vector2(pelvis.global_position.x, pelvis.global_position.z).length(), 0.3, "não deriva")


func test_walks_forward() -> void:
	var f := _fighter()
	await _hold(f, 120, InputCommand.new())
	var start: Vector3 = f.body.segments[&"pelvis"].global_position
	var cmd := InputCommand.new()
	cmd.move = Vector2(0, 1)
	await _hold(f, 240, cmd)
	var end: Vector3 = f.body.segments[&"pelvis"].global_position
	assert_lt(end.z - start.z, -3.0, "andou ~2 s para -Z")
	assert_gt(_head_y(f), 1.4, "continua de pé andando")


func test_sprint_is_faster_than_walk() -> void:
	var walk := await _distance_after(false)
	var sprint := await _distance_after(true)
	assert_gt(sprint, walk * 1.4)


func _distance_after(sprint: bool) -> float:
	var f := _fighter()
	await _hold(f, 60, InputCommand.new())
	var start: Vector3 = f.body.segments[&"pelvis"].global_position
	var cmd := InputCommand.new()
	cmd.move = Vector2(0, 1)
	cmd.sprint = sprint
	await _hold(f, 180, cmd)
	var d := f.body.segments[&"pelvis"].global_position.distance_to(start)
	f.queue_free()
	return d


func test_turns_with_look_delta() -> void:
	var f := _fighter()
	var cmd := InputCommand.new()
	cmd.look_yaw_delta = 0.01
	await _hold(f, 157, cmd)
	assert_almost_eq(wrapf(f.facing_yaw, -PI, PI), wrapf(1.57, -PI, PI), 0.05)


func test_falls_when_balance_lost_and_gets_up() -> void:
	var f := _fighter()
	await _hold(f, 120, InputCommand.new())
	f.balance.drain(9999.0)
	await _hold(f, 90, InputCommand.new())
	assert_lt(_head_y(f), 0.9, "caiu")
	await _hold(f, 300, InputCommand.new())
	assert_gt(_head_y(f), 1.4, "levantou")


func test_dead_fighter_stays_down() -> void:
	var f := _fighter()
	await _hold(f, 60, InputCommand.new())
	f.health.apply_damage(BodyPart.Kind.HEAD, 9999.0, HitType.Kind.BLUNT, 50.0, f.combat_tuning)
	await _hold(f, 480, InputCommand.new())
	assert_lt(_head_y(f), 0.6)
	assert_true(f.is_dead())


func test_crouch_lowers_head() -> void:
	var f := _fighter()
	await _hold(f, 120, InputCommand.new())
	var standing := _head_y(f)
	var cmd := InputCommand.new()
	cmd.crouch = true
	await _hold(f, 120, cmd)
	assert_lt(_head_y(f), standing - 0.2)


func test_severed_leg_limb_detaches() -> void:
	var f := _fighter()
	await _hold(f, 60, InputCommand.new())
	f.health.apply_damage(BodyPart.Kind.LEG_R, 9999.0, HitType.Kind.CUT, 9999.0, f.combat_tuning)
	assert_false(f.body.joints.has(&"hip_r"))
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar `Fighter` e `Locomotion`** seguindo a interface. Regras:
  - Todo torque de músculo entre pai e filho: `+t` no filho, `−t` no pai (conserva momento).
  - Nenhum número mágico: tudo de `LocomotionTuning`.
  - `Fighter._ready()` constrói `FighterBody` com `FighterBodySpec.default_human()`, posicionado em `global_position` e **girado por `facing_yaw`** (definido antes de entrar na árvore), cria estado (`BodyHealth`, `Balance`, `Stamina`) com `fighter_tuning`, conecta sinais.
  - O `Fighter` processa antes dos controladores dele: `process_physics_priority = -10`.

- [ ] **Step 4: Rodar e ver passar** — 8 PASS. Ajustes de tuning são esperados; se mudar padrões de `LocomotionTuning`, registre os valores e o motivo.

- [ ] **Step 5: Commit** — `feat(sim): active ragdoll locomotion with balance-driven support`.

---

### Task 7: `HandController` (mão no mouse, arma, tensão, pegada, giro)

**Implementer:** physics-engineer (opus).

**Files:**
- Create: `src/sim/fighter/hand_controller.gd`
- Modify: `src/sim/fighter/fighter.gd` (criar/equipar arma, chamar o controlador)
- Test: `tests/sim/fighter/test_hand_controller.gd`

**Interfaces:**
- Consumes: `Fighter`, `FighterBody`, `WeaponBody`, `WeaponData`, `HandTuning`, `ControlMath`, `Stamina`, `BodyHealth`
- Produces:
  - `Fighter.equip(data: WeaponData) -> WeaponBody` — remove a arma atual (se houver), cria `WeaponBody` na mão direita com a junta de pegada (`Generic6DOFJoint3D`: linear travado, angular limitado como pulso ±70°/±40°, giro ±180°), exceções de colisão com o próprio corpo; retorna a arma.
  - `Fighter.weapon: WeaponBody`
  - `Fighter.shoulder_transform() -> Transform3D` — ombro direito no mundo, orientado por `facing_yaw` (frame do `ReachMapper`)
  - `Fighter.reach() -> float` (de `FighterBodySpec.reach()`)
  - `Fighter.hand_precision() -> float` = `health.limb_strength(ARM_R)`
  - `HandController.new(fighter: Fighter, tuning: HandTuning)`; `physics_step(dt: float, cmd: InputCommand) -> void`:
    1. Alvo no mundo = `shoulder_transform() * cmd.hand_target`; velocidade-alvo por diferença finita.
    2. Força máxima = `arm_max_force × limb_strength(ARM_R) × stamina.strength_factor() × (tension_force_mult se tensão sustentada) × (two_hand_force_mult se duas mãos) × carga`. Tensão gasta `tension_per_s` via `drain_continuous`; se falhar, sem tensão.
    3. `spring_force` na mão direita; reação `−f × reaction_fraction` no peito.
    4. Pulso: `pd_torque` na arma em direção a "lâmina alinhada com o antebraço, girada `blade_roll` em torno do eixo da lâmina", limitado por `wrist_max_torque × limb_strength`; torque oposto na mão.
    5. `grip_toggle`: alterna 1 mão ↔ 2 mãos (cria/remove junta pino entre `hand_l` e a arma em `grip_secondary`; a mão esquerda é puxada para lá antes de prender, com mola) ↔ invertida (arma girada 180° no eixo X da pegada). Ciclo: 1 → 2 → invertida → 1.
    6. **Carga:** tensão segurada com a mão abaixo de `charge_still_speed` acumula até `charge_time`; o multiplicador `1 → charge_max_mult` vale até a tensão ser solta.
    7. Com `free_hand_mode`, a mão esquerda segue `cmd.free_hand_target` (ombro esquerdo) com a mesma mola (força × `limb_strength(ARM_L)`), e a mão direita segura a última posição.
    8. Morto ou caído: nenhuma força.

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest


func before_all() -> void:
	Engine.time_scale = 4.0


func after_all() -> void:
	Engine.time_scale = 1.0


func _world() -> void:
	var f := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(40, 1, 40)
	s.shape = b
	f.add_child(s)
	f.position = Vector3(0, -0.5, 0)
	add_child_autofree(f)


func _armed(weapon: WeaponData) -> Fighter:
	_world()
	var f := Fighter.new()
	add_child_autofree(f)
	f.equip(weapon)
	return f


func _cmd(target: Vector3, tension: bool = false) -> InputCommand:
	var c := InputCommand.new()
	c.hand_target = target
	c.tension = tension
	return c


func _hold(f: Fighter, frames: int, cmd: InputCommand) -> void:
	for i in frames:
		f.submit(cmd)
		await wait_physics_frames(1)


func _hand(f: Fighter) -> RigidBody3D:
	return f.body.segments[&"hand_r"]


## Ticks até a mão chegar a 10 cm do alvo, saindo de baixo-direita para cima-esquerda.
func _ticks_to_reach(weapon: WeaponData, tension: bool) -> int:
	var f := _armed(weapon)
	var r := f.reach() * 0.8
	var low_right := Vector3(0.5, -0.5, -0.7).normalized() * r
	var high_left := Vector3(-0.6, 0.6, -0.5).normalized() * r
	await _hold(f, 120, _cmd(low_right))
	for i in 240:
		f.submit(_cmd(high_left, tension))
		await wait_physics_frames(1)
		var goal := f.shoulder_transform() * high_left
		if _hand(f).global_position.distance_to(goal) < 0.1:
			f.queue_free()
			return i
	f.queue_free()
	return 999


func test_hand_reaches_target() -> void:
	assert_lt(await _ticks_to_reach(WeaponCatalog.longsword(), false), 60, "espada chega em < 0,5 s")


func test_hammer_is_slower_than_sword() -> void:
	var sword := await _ticks_to_reach(WeaponCatalog.longsword(), false)
	var hammer := await _ticks_to_reach(WeaponCatalog.hammer(), false)
	assert_gt(hammer, int(sword * 1.3), "peso aparece no controle")


func test_tension_makes_hammer_faster() -> void:
	var relaxed := await _ticks_to_reach(WeaponCatalog.hammer(), false)
	var tense := await _ticks_to_reach(WeaponCatalog.hammer(), true)
	assert_lt(tense, relaxed)


func test_tension_costs_stamina() -> void:
	var f := _armed(WeaponCatalog.longsword())
	var before := f.stamina.value
	await _hold(f, 120, _cmd(Vector3(0, 0, -0.5), true))
	assert_lt(f.stamina.value, before)


func test_injured_arm_is_slower() -> void:
	var healthy := await _ticks_to_reach(WeaponCatalog.longsword(), false)
	var f := _armed(WeaponCatalog.longsword())
	f.health.apply_damage(BodyPart.Kind.ARM_R, f.fighter_tuning.limb_max_health * 0.9, HitType.Kind.BLUNT, 50.0, f.combat_tuning)
	var r := f.reach() * 0.8
	var low_right := Vector3(0.5, -0.5, -0.7).normalized() * r
	var high_left := Vector3(-0.6, 0.6, -0.5).normalized() * r
	await _hold(f, 120, _cmd(low_right))
	var ticks := 999
	for i in 240:
		f.submit(_cmd(high_left))
		await wait_physics_frames(1)
		if _hand(f).global_position.distance_to(f.shoulder_transform() * high_left) < 0.1:
			ticks = i
			break
	assert_gt(ticks, healthy)


func test_weapon_follows_hand() -> void:
	var f := _armed(WeaponCatalog.longsword())
	await _hold(f, 120, _cmd(Vector3(0, 0, -0.5)))
	var grip_world := f.weapon.global_transform * f.weapon.grip_local(true)
	assert_lt(grip_world.distance_to(_hand(f).global_position), 0.08)


func test_blade_roll_rotates_weapon() -> void:
	var f := _armed(WeaponCatalog.longsword())
	await _hold(f, 120, _cmd(Vector3(0, 0, -0.5)))
	var edge_before := f.weapon.global_basis.x
	var c := _cmd(Vector3(0, 0, -0.5))
	c.blade_roll = deg_to_rad(90.0)
	await _hold(f, 120, c)
	assert_lt(absf(edge_before.dot(f.weapon.global_basis.x)), 0.5)


func test_grip_toggle_cycles_two_hands() -> void:
	var f := _armed(WeaponCatalog.longsword())
	await _hold(f, 60, _cmd(Vector3(0, -0.1, -0.5)))
	var c := _cmd(Vector3(0, -0.1, -0.5))
	c.grip_toggle = true
	await _hold(f, 1, c)
	await _hold(f, 120, _cmd(Vector3(0, -0.1, -0.5)))
	assert_true(f.hand_controller.two_handed)
	var second := f.weapon.global_transform * f.weapon.grip_local(false)
	assert_lt(second.distance_to(f.body.segments[&"hand_l"].global_position), 0.1)


func test_equip_replaces_weapon() -> void:
	var f := _armed(WeaponCatalog.longsword())
	var old := f.weapon
	f.equip(WeaponCatalog.hammer())
	await wait_physics_frames(2)
	assert_false(is_instance_valid(old) and old.is_inside_tree())
	assert_eq(f.weapon.data.id, &"hammer")
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar** conforme a interface. `Fighter` ganha `hand_controller: HandController`, chamado em `_physics_process` depois da locomoção.

- [ ] **Step 4: Rodar e ver passar** — 9 PASS; rodar também `test_locomotion.gd` (carregar arma não pode derrubar o lutador parado). Se precisar mexer em `HandTuning`, registre.

- [ ] **Step 5: Commit** — `feat(sim): mouse-driven weapon hand with tension, grip and roll`.

---

### Task 8: `ContactProbe` (acerto básico arma → corpo)

**Implementer:** physics-engineer (opus).

**Files:**
- Create: `src/sim/combat/contact_probe.gd`
- Modify: `src/sim/fighter/fighter.gd` (cria o probe da própria arma; expõe `receive_hit(hit: HitEvent, weapon_mult: float)`)
- Test: `tests/sim/combat/test_contact_probe.gd`

**Interfaces:**
- Consumes: `WeaponBody`, `WeaponData.zone_at/edge_dir_at`, `HitClassifier`, `CombatMath`, `CombatResolver`, `HitEvent`, `Fighter`
- Produces:
  - `ContactProbe.new(owner_fighter: Fighter, weapon: WeaponBody, tuning: CombatTuning)`
  - `pre_step() -> void` — chamado no início do tick: guarda velocidade linear/angular da arma (**antes** do passo de física; pendência M2 do SP1-A)
  - `post_step(tick: int) -> Array[HitEvent]` — lê contatos via `PhysicsServer3D.body_get_direct_state(weapon.get_rid())`; para cada contato com um segmento de **outro** `Fighter`:
    - ponto e normal no espaço local da arma → `zone_at`, `edge_dir_at` (convertido ao mundo)
    - `v_rel` = velocidade do ponto com as velocidades guardadas em `pre_step` − velocidade do ponto do segmento alvo
    - `r` = ponto − centro de massa da arma no mundo; `inv_inertia` do estado direto; normal do contato **orientada para fora da arma** (verificar o sinal uma vez e documentar)
    - `m_ef = CombatMath.effective_mass(...)`, `energy = contact_energy(m_ef, v_rel)`
    - `hit_type = HitClassifier.classify(...)`, `part = alvo.body.segment_part[segmento]`
    - **Recarga por par (arma, segmento): 0,25 s** — contatos contínuos não geram acertos a cada tick
    - `target.receive_hit(hit, weapon.data.damage_mult)` → `CombatResolver.apply_hit` + `hit_received.emit(hit)`
    - Acertos em parte já decepada são ignorados (pendência M10).
  - `Fighter.receive_hit(hit: HitEvent, weapon_mult: float) -> void`
  - `Fighter` chama `probe.pre_step()` no início e `probe.post_step(tick)` no fim do seu `_physics_process`.

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest


func before_all() -> void:
	Engine.time_scale = 2.0


func after_all() -> void:
	Engine.time_scale = 1.0


func _world() -> void:
	var f := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(40, 1, 40)
	s.shape = b
	f.add_child(s)
	f.position = Vector3(0, -0.5, 0)
	add_child_autofree(f)


## Atacante na origem olhando -Z, alvo a 1,1 m à frente virado para ele.
func _duel(weapon: WeaponData) -> Array[Fighter]:
	_world()
	var a := Fighter.new()
	a.fighter_id = 1
	add_child_autofree(a)
	a.equip(weapon)
	var d := Fighter.new()
	d.fighter_id = 2
	d.position = Vector3(0, 0, -1.1)
	d.facing_yaw = PI
	add_child_autofree(d)
	return [a, d]


func _hold(fs: Array[Fighter], frames: int, cmd: InputCommand) -> void:
	for i in frames:
		fs[0].submit(cmd)
		fs[1].submit(InputCommand.new())
		await wait_physics_frames(1)


func _swing(fs: Array[Fighter], tension: bool) -> Array[HitEvent]:
	var hits: Array[HitEvent] = []
	fs[1].hit_received.connect(func(h: HitEvent) -> void: hits.append(h))
	var r := fs[0].reach() * 0.9
	var wind := InputCommand.new()
	wind.hand_target = Vector3(0.7, 0.3, -0.2).normalized() * r
	await _hold(fs, 120, wind)
	var cut := InputCommand.new()
	cut.hand_target = Vector3(-0.7, 0.1, -0.6).normalized() * r
	cut.tension = tension
	await _hold(fs, 60, cut)
	return hits


func test_horizontal_swing_hits_target() -> void:
	var hits := await _swing(_duel(WeaponCatalog.longsword()), true)
	assert_gt(hits.size(), 0, "o golpe acerta")
	assert_gt(hits[0].energy, 0.0)
	assert_eq(hits[0].attacker_id, 1)
	assert_eq(hits[0].target_id, 2)


func test_hit_damages_target() -> void:
	var fs := _duel(WeaponCatalog.longsword())
	var hits := await _swing(fs, true)
	var total := 0.0
	for h in hits:
		total += h.damage
	assert_gt(total, 0.0)


func test_cooldown_prevents_hit_spam() -> void:
	var fs := _duel(WeaponCatalog.longsword())
	var hits := await _swing(fs, true)
	var per_part := {}
	for h in hits:
		per_part[h.part] = per_part.get(h.part, 0) + 1
	for part in per_part:
		assert_lte(per_part[part], 2, "no máximo 2 acertos na mesma parte num golpe de 0,5 s")


func test_hammer_hits_harder_than_sword() -> void:
	var sword_hits := await _swing(_duel(WeaponCatalog.longsword()), true)
	var hammer_hits := await _swing(_duel(WeaponCatalog.hammer()), true)
	assert_gt(sword_hits.size(), 0)
	assert_gt(hammer_hits.size(), 0)
	var best_sword := 0.0
	for h in sword_hits:
		best_sword = maxf(best_sword, h.energy)
	var best_hammer := 0.0
	for h in hammer_hits:
		best_hammer = maxf(best_hammer, h.energy)
	assert_gt(best_hammer, best_sword)


func test_own_weapon_never_hits_self() -> void:
	var fs := _duel(WeaponCatalog.longsword())
	var self_hits: Array[HitEvent] = []
	fs[0].hit_received.connect(func(h: HitEvent) -> void: self_hits.append(h))
	await _swing(fs, true)
	assert_eq(self_hits.size(), 0)
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar.** Se o teste de golpe não acertar por geometria (alcance/posição), ajuste a distância do alvo **no teste** para que a espada alcance o tronco, e registre; não mude a lógica para forçar acerto.

- [ ] **Step 4: Rodar e ver passar** — 5 PASS; suíte completa verde.

- [ ] **Step 5: Commit** — `feat(sim): basic weapon-to-body contact produces hits`.

---

### Task 9: Câmera, arena, HUD, entrada do jogador e cena jogável

**Implementer:** physics-engineer (opus).

**Files:**
- Create: `src/view/player_input.gd`, `src/view/fighter_camera.gd`, `src/view/arena_builder.gd`, `src/view/hud.gd`, `src/view/sandbox.gd`, `scenes/sandbox.tscn`
- Modify: `project.godot` (`run/main_scene="res://scenes/sandbox.tscn"`, janela 1600×900, MSAA 2×)
- Test: `tests/view/test_sandbox_smoke.gd`

**Interfaces / comportamento:**
- `PlayerInput extends Node`: `@export var fighter_path: NodePath`. Em `_ready`: `InputBindings.ensure_defaults()`, cria `InputSampler` e `ReachMapper`. Em `_unhandled_input`: acumula `InputEventMouseMotion.relative` em `sampler.mouse_delta` **só com o mouse capturado**; roda do mouse (`MOUSE_BUTTON_WHEEL_UP/DOWN`) em `wheel_steps`; clique captura o mouse; `release_mouse` solta. Em `_physics_process`: preenche `held` (`Input.is_action_pressed`) e `pressed` (`Input.is_action_just_pressed`) para todas as ações, monta o comando com `build_command(tick, mapper, roll_atual, fighter.reach(), fighter.hand_precision(), dt)`, guarda `roll_atual = cmd.blade_roll`, `fighter.submit(cmd)`. Teclas `weapon_1`/`weapon_2` chamam `fighter.equip(WeaponCatalog.longsword()/hammer())`.
- `FighterCamera extends Node3D`: `@export var fighter_path: NodePath`. **3ª pessoa:** `SpringArm3D` (comprimento 2,4 m + `weapon.data.length()`, colisão com camada mundo) sobre o ombro direito (0,35 m à direita, 1,65 m de altura), pitch −12°, yaw = `facing_yaw` suavizado. **1ª pessoa:** câmera na cabeça física com posição suavizada (filtro exponencial 20/s) e yaw = `facing_yaw`. `camera_toggle` alterna. `lock_on` alterna trava no `Fighter` mais próximo à frente (≤ 8 m): enquanto travado, o yaw do lutador é conduzido ao alvo (o `PlayerInput` injeta `look_yaw_delta` = diferença angular × 10 × dt).
- `ArenaBuilder` (estático): `build(parent: Node3D) -> void` cria: chão 30×30 m (StaticBody3D, material com grade de 1 m via shader simples ou textura procedural), 4 muros baixos de 1 m, uma parede 4×3 m, um pilar cilíndrico r 0,5 m, um degrau de 0,3 m; `DirectionalLight3D` com sombra, `WorldEnvironment` com céu procedural e névoa leve.
- `Hud extends CanvasLayer`: barras de equilíbrio e stamina do jogador; silhueta textual das 6 partes com vida do jogador e do boneco; "último acerto: tipo, energia (J), dano, parte"; mira na tela (ponto) mostrando a projeção do alvo da mão; ajuda de teclas (F1 alterna).
- `Sandbox extends Node3D` (`scenes/sandbox.tscn` só tem o nó raiz com o script): em `_ready` monta arena, cria jogador (`Fighter` id 1 em (0,0,3), espada) com `PlayerInput`, `FighterCamera`, `Hud`, e o **boneco** (`Fighter` id 2 em (0,0,0), `facing_yaw = PI`, sem arma, recebe `InputCommand` vazio a cada tick por um nó simples). Quando o boneco morre, renasce em 3 s no mesmo lugar.

- [ ] **Step 1: Escrever o teste de fumaça**

```gdscript
extends GutTest


func test_sandbox_runs_without_errors() -> void:
	var scene: PackedScene = load("res://scenes/sandbox.tscn")
	var root := scene.instantiate()
	add_child_autofree(root)
	await wait_physics_frames(360)
	var fighters := root.find_children("*", "Fighter", true, false)
	assert_eq(fighters.size(), 2)
	for f in fighters:
		assert_gt((f as Fighter).body.segments[&"head"].global_position.y, 1.3, "ambos de pé após 3 s")


func test_main_scene_is_sandbox() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/sandbox.tscn")
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar** os nós acima.

- [ ] **Step 4: Rodar a suíte completa** — tudo verde.

- [ ] **Step 5: Verificar jogando** — rodar `godot --path .` e confirmar manualmente (registrar no relatório o que foi visto; se não houver como ver a tela, dizer isso explicitamente):
  1. Mouse capturado ao clicar; Esc solta.
  2. Mover o mouse move a espada; passar do limite lateral gira o corpo.
  3. WASD anda; Shift corre; Ctrl agacha; Espaço pula.
  4. 1/2 troca espada ↔ marreta; a marreta é visivelmente mais lenta.
  5. Golpear o boneco mostra acerto no HUD; golpes fortes o derrubam; ele levanta; morto, renasce.
  6. V alterna 1ª/3ª pessoa; botão do meio trava no boneco.
  7. FPS exibido no HUD (F1) na Intel UHD 730.

- [ ] **Step 6: Commit** — `feat: first playable sandbox with camera, arena and training dummy`.

---

## Depois deste plano

- **SP1-C — Combate físico completo:** choque arma↔arma (`ClashEvent`, disputa de momentum com dreno aplicado ao perdedor), parry com mão livre (inclui **marreta: parry batendo no cabo** — decisão do dono do produto delegada, 2026-09-19), agarrar/desarmar, empurrar, estocada, chute, esquiva, arremesso, drenos sem acerto (golpe pesado errado, chute, parry sofrido), perna ferida reduz velocidade, efeitos (faísca, tremor, hit stop), eventos com tick e id.
- **SP1-D — Treino, assets e ajuste:** bot e espelho, painel F1 completo, geradores Blender (manequim, armas, arena), ajuste dos valores extremos, `@export_range`, teste de desempenho com 8 lutadores.
