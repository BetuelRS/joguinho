# SP1-A — Fundação e lógica pura de combate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar o projeto Godot com testes automatizados e toda a lógica de combate que não depende de física: comando de input, energia de contato, classificação do golpe, dano, vida por parte, equilíbrio, stamina, dados de armas e eventos.

**Architecture:** Tudo aqui vive em `src/sim/` como classes `RefCounted`/`Resource` puras, sem nós de cena e sem referência a `src/view/`. Os planos SP1-B/C/D ligam esta lógica aos corpos físicos Jolt. Todos os parâmetros ajustáveis ficam em dois `Resource`s (`CombatTuning`, `FighterTuning`) para o painel de ajuste futuro.

**Tech Stack:** Godot 4.6.3 (GDScript tipado), Jolt Physics (embutido no Godot 4.6), GUT 9.x para testes, PowerShell no Windows.

**Spec:** `docs/superpowers/specs/2026-09-19-joguinho-design.md` (Parte 2 — Sub-projeto 1)

## Global Constraints

- Engine: Godot 4.6 (`godot.exe` 4.6.3 no PATH); motor de física 3D `Jolt Physics`.
- Tick de física fixo: `physics_ticks_per_second = 120`.
- Nada em `src/sim/` referencia `src/view/`.
- GDScript com tipagem estática em todas as variáveis, parâmetros e retornos.
- Unidades SI: metros, quilogramas, segundos, joules.
- Espaço local da arma: origem na base da guarda, `+Y` ao longo da lâmina em direção à ponta, `+X` direção do fio principal, `+Z` normal da chapa.
- Espada longa ~1,4 kg, ~1,1 m, centro de massa ~10 cm à frente da guarda; marreta ~5 kg, ~0,9 m, massa concentrada na cabeça.
- Commits terminam com `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Structure

| Arquivo | Responsabilidade |
|---|---|
| `project.godot` | Configuração: Jolt, 120 Hz |
| `.gitignore` | Ignora `.godot/` |
| `tools/run_tests.ps1` | Importa o projeto e roda GUT headless; exit code = falhas |
| `addons/gut/` | Framework de testes (vendorizado) |
| `src/sim/input/input_command.gd` | `InputCommand`: comando por tick, serializável |
| `src/sim/combat/combat_math.gd` | `CombatMath`: massa efetiva, energia |
| `src/sim/combat/hit_type.gd` | `HitType.Kind`: CUT, THRUST, BLUNT |
| `src/sim/weapon/weapon_zone.gd` | `WeaponZone.Kind`: EDGE, FLAT, TIP, GUARD, HANDLE, HEAD |
| `src/sim/combat/hit_classifier.gd` | `HitClassifier`: zona + geometria → tipo |
| `src/sim/fighter/body_part.gd` | `BodyPart.Kind` + helpers |
| `src/sim/combat/combat_tuning.gd` | `CombatTuning` Resource: limiares e multiplicadores |
| `src/sim/combat/damage_calculator.gd` | `DamageCalculator`: energia → dano e dreno de equilíbrio |
| `src/sim/fighter/fighter_tuning.gd` | `FighterTuning` Resource: vida, equilíbrio, stamina |
| `src/sim/fighter/body_health.gd` | `BodyHealth`: vida por parte, desmembramento, morte |
| `src/sim/fighter/balance.gd` | `Balance`: barra, queda, recuperação |
| `src/sim/fighter/stamina.gd` | `Stamina`: gasto, regeneração, exaustão |
| `src/sim/weapon/weapon_section.gd` | `WeaponSection` Resource: bloco de massa da arma |
| `src/sim/weapon/weapon_data.gd` | `WeaponData` Resource: massa, CoM, inércia, zona por ponto |
| `src/sim/weapon/weapon_catalog.gd` | `WeaponCatalog`: espada longa e marreta |
| `src/sim/combat/hit_event.gd` | `HitEvent` |
| `src/sim/combat/clash_event.gd` | `ClashEvent` |
| `src/sim/combat/combat_resolver.gd` | `CombatResolver`: aplica acerto, disputa de momentum |
| `src/sim/combat/parry_judge.gd` | `ParryJudge`: decide se contato da mão livre é parry |
| `tests/...` | Um arquivo de teste por classe, espelhando `src/` |

---

### Task 1: Projeto Godot + GUT + script de testes

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `tools/run_tests.ps1`
- Create: `addons/gut/` (cópia do repositório GUT)
- Test: `tests/test_project_settings.gd`

**Interfaces:**
- Produces: comando `powershell -File tools/run_tests.ps1` que roda todos os testes em `res://tests` (com subpastas) e retorna exit code ≠ 0 se algum falhar.

- [ ] **Step 1: Criar `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Joguinho"
config/features=PackedStringArray("4.6", "Forward Plus")

[physics]

3d/physics_engine="Jolt Physics"
common/physics_ticks_per_second=120

[rendering]

renderer/rendering_method="forward_plus"
```

- [ ] **Step 2: Criar `.gitignore`**

```gitignore
.godot/
*.tmp
```

- [ ] **Step 3: Instalar GUT**

Listar tags e escolher a maior `v9.*`:

```powershell
git ls-remote --tags https://github.com/bitwes/Gut.git | Select-String "refs/tags/v9\." | Select-Object -Last 5
```

Clonar a tag escolhida (substitua `<TAG>` pela maior listada) e copiar só `addons/gut`:

```powershell
git clone --depth 1 --branch <TAG> https://github.com/bitwes/Gut.git "$env:TEMP\gut_src"
New-Item -ItemType Directory -Force addons | Out-Null
Copy-Item -Recurse "$env:TEMP\gut_src\addons\gut" addons\gut
Remove-Item -Recurse -Force "$env:TEMP\gut_src"
```

Conferir compatibilidade: abrir `addons/gut/plugin.cfg` e o README da tag; a versão escolhida deve declarar suporte a Godot 4.6 (ou 4.5+). Se não declarar, usar o branch `main` do GUT.

- [ ] **Step 4: Criar `tools/run_tests.ps1`**

```powershell
# Roda todos os testes GUT headless. Exit code != 0 se houver falha.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
# Importa recursos e atualiza o cache de class_name (necessário para testes headless).
godot --headless --path $root --import | Out-Null
godot --headless --path $root -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit @args
exit $LASTEXITCODE
```

`@args` permite passar filtros, ex.: `-gselect=test_input_command.gd`.

- [ ] **Step 5: Escrever o teste de configuração**

`tests/test_project_settings.gd`:

```gdscript
extends GutTest


func test_physics_engine_is_jolt() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_tick_is_120hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 120)
```

- [ ] **Step 6: Rodar os testes**

Run: `powershell -File tools/run_tests.ps1`
Expected: 2 testes passando, exit code 0.

Se `--import` não for reconhecido, rodar uma vez `godot --headless --path . --editor --quit` no lugar dele e ajustar o script.

- [ ] **Step 7: Commit**

```powershell
git add project.godot .gitignore tools/run_tests.ps1 addons/gut tests/test_project_settings.gd
git commit -m @'
chore: scaffold Godot project with Jolt, 120 Hz and GUT

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 2: `InputCommand`

**Files:**
- Create: `src/sim/input/input_command.gd`
- Test: `tests/sim/input/test_input_command.gd`

**Interfaces:**
- Produces:
  - `class_name InputCommand extends RefCounted`
  - campos: `tick: int`, `move: Vector2`, `sprint: bool`, `jump: bool`, `crouch: bool`, `dodge: bool`, `hand_target: Vector3`, `blade_roll: float`, `tension: bool`, `free_hand_mode: bool`, `free_hand_target: Vector3`, `thrust: bool`, `kick: bool`, `grip_toggle: bool`, `throw: bool`, `lock_on_toggle: bool`, `look_yaw_delta: float`
  - `func to_bytes() -> PackedByteArray`
  - `static func from_bytes(data: PackedByteArray) -> InputCommand`

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest


func _full_command() -> InputCommand:
	var c := InputCommand.new()
	c.tick = 4242
	c.move = Vector2(0.5, -1.0)
	c.sprint = true
	c.crouch = true
	c.hand_target = Vector3(0.25, -0.5, 0.75)
	c.blade_roll = 1.5
	c.tension = true
	c.free_hand_mode = true
	c.free_hand_target = Vector3(-0.25, 0.5, 0.125)
	c.thrust = true
	c.throw = true
	c.look_yaw_delta = -0.5
	return c


func test_roundtrip_preserves_values() -> void:
	var d := InputCommand.from_bytes(_full_command().to_bytes())
	assert_eq(d.tick, 4242)
	assert_eq(d.move, Vector2(0.5, -1.0))
	assert_eq(d.hand_target, Vector3(0.25, -0.5, 0.75))
	assert_eq(d.blade_roll, 1.5)
	assert_eq(d.free_hand_target, Vector3(-0.25, 0.5, 0.125))
	assert_eq(d.look_yaw_delta, -0.5)


func test_roundtrip_preserves_flags() -> void:
	var d := InputCommand.from_bytes(_full_command().to_bytes())
	assert_true(d.sprint)
	assert_true(d.crouch)
	assert_true(d.tension)
	assert_true(d.free_hand_mode)
	assert_true(d.thrust)
	assert_true(d.throw)
	assert_false(d.jump)
	assert_false(d.dodge)
	assert_false(d.kick)
	assert_false(d.grip_toggle)
	assert_false(d.lock_on_toggle)


func test_default_command_roundtrips_to_defaults() -> void:
	var d := InputCommand.from_bytes(InputCommand.new().to_bytes())
	assert_eq(d.tick, 0)
	assert_eq(d.move, Vector2.ZERO)
	assert_false(d.tension)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_input_command.gd`
Expected: FAIL — `InputCommand` não existe.

- [ ] **Step 3: Implementar**

`src/sim/input/input_command.gd`:

```gdscript
class_name InputCommand
extends RefCounted
## Comando de um lutador para um tick de simulação. Serializável para a rede (SP2).

const _FLAG_FIELDS: Array[StringName] = [
	&"sprint", &"jump", &"crouch", &"dodge", &"tension", &"free_hand_mode",
	&"thrust", &"kick", &"grip_toggle", &"throw", &"lock_on_toggle",
]

var tick: int = 0
var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var jump: bool = false
var crouch: bool = false
var dodge: bool = false
## Alvo da mão da arma, no espaço do ombro, dentro da esfera de alcance.
var hand_target: Vector3 = Vector3.ZERO
## Rotação da arma no próprio eixo (radianos).
var blade_roll: float = 0.0
var tension: bool = false
var free_hand_mode: bool = false
var free_hand_target: Vector3 = Vector3.ZERO
var thrust: bool = false
var kick: bool = false
var grip_toggle: bool = false
var throw: bool = false
var lock_on_toggle: bool = false
var look_yaw_delta: float = 0.0


func to_bytes() -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_32(tick)
	buf.put_float(move.x)
	buf.put_float(move.y)
	_put_vec3(buf, hand_target)
	buf.put_float(blade_roll)
	_put_vec3(buf, free_hand_target)
	buf.put_float(look_yaw_delta)
	var flags := 0
	for i in _FLAG_FIELDS.size():
		if get(_FLAG_FIELDS[i]):
			flags |= 1 << i
	buf.put_u16(flags)
	return buf.data_array


static func from_bytes(data: PackedByteArray) -> InputCommand:
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var c := InputCommand.new()
	c.tick = buf.get_32()
	var mx := buf.get_float()
	var my := buf.get_float()
	c.move = Vector2(mx, my)
	c.hand_target = _get_vec3(buf)
	c.blade_roll = buf.get_float()
	c.free_hand_target = _get_vec3(buf)
	c.look_yaw_delta = buf.get_float()
	var flags := buf.get_u16()
	for i in _FLAG_FIELDS.size():
		c.set(_FLAG_FIELDS[i], (flags & (1 << i)) != 0)
	return c


static func _put_vec3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_float(v.x)
	buf.put_float(v.y)
	buf.put_float(v.z)


static func _get_vec3(buf: StreamPeerBuffer) -> Vector3:
	var x := buf.get_float()
	var y := buf.get_float()
	var z := buf.get_float()
	return Vector3(x, y, z)
```

- [ ] **Step 4: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_input_command.gd`
Expected: 3 testes PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/sim/input tests/sim/input
git commit -m @'
feat(sim): add serializable InputCommand

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 3: `CombatMath` — massa efetiva e energia

**Files:**
- Create: `src/sim/combat/combat_math.gd`
- Test: `tests/sim/combat/test_combat_math.gd`

**Interfaces:**
- Produces:
  - `CombatMath.effective_mass(mass: float, inv_inertia: Basis, r: Vector3, normal: Vector3) -> float` — `r` = ponto de contato − centro de massa (mundo); `inv_inertia` = tensor de inércia inverso no mundo (mesmo formato de `PhysicsDirectBodyState3D.inverse_inertia_tensor`).
  - `CombatMath.contact_energy(m_eff: float, v_rel: Vector3) -> float`

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest


func _diag(x: float, y: float, z: float) -> Basis:
	return Basis(Vector3(x, 0, 0), Vector3(0, y, 0), Vector3(0, 0, z))


func test_effective_mass_at_center_equals_mass() -> void:
	var m := CombatMath.effective_mass(2.0, _diag(6, 6, 6), Vector3.ZERO, Vector3.UP)
	assert_almost_eq(m, 2.0, 1e-5)


func test_effective_mass_at_rod_tip() -> void:
	# Barra de 2 kg e 1 m: I = m L^2 / 12 = 1/6 -> inverso 6.
	# Ponta em r = 0.5 no eixo X, impacto em Y: 1/m_ef = 1/2 + 0.5*6*0.5 = 2.
	var m := CombatMath.effective_mass(2.0, _diag(0, 6, 6), Vector3(0.5, 0, 0), Vector3.UP)
	assert_almost_eq(m, 0.5, 1e-5)


func test_effective_mass_ignores_normal_length() -> void:
	var a := CombatMath.effective_mass(2.0, _diag(0, 6, 6), Vector3(0.5, 0, 0), Vector3.UP)
	var b := CombatMath.effective_mass(2.0, _diag(0, 6, 6), Vector3(0.5, 0, 0), Vector3.UP * 7.0)
	assert_almost_eq(a, b, 1e-5)


func test_contact_energy() -> void:
	assert_almost_eq(CombatMath.contact_energy(2.0, Vector3(3, 4, 0)), 25.0, 1e-5)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_combat_math.gd`
Expected: FAIL — `CombatMath` não existe.

- [ ] **Step 3: Implementar**

```gdscript
class_name CombatMath
extends RefCounted
## Física do contato: quanta massa "sente" o alvo e quanta energia o golpe carrega.


## Massa efetiva de um corpo rígido no ponto de contato, ao longo da normal.
## Ponta de arma girando -> massa efetiva baixa; perto do centro de massa -> massa cheia.
static func effective_mass(mass: float, inv_inertia: Basis, r: Vector3, normal: Vector3) -> float:
	var n := normal.normalized()
	var rxn := r.cross(n)
	var inverse := 1.0 / mass + rxn.dot(inv_inertia * rxn)
	return 1.0 / inverse


static func contact_energy(m_eff: float, v_rel: Vector3) -> float:
	return 0.5 * m_eff * v_rel.length_squared()
```

- [ ] **Step 4: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_combat_math.gd`
Expected: 4 PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/sim/combat/combat_math.gd tests/sim/combat/test_combat_math.gd
git commit -m @'
feat(sim): add effective mass and contact energy math

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 4: Enums de zona/tipo, `BodyPart`, `CombatTuning` e `HitClassifier`

**Files:**
- Create: `src/sim/combat/hit_type.gd`
- Create: `src/sim/weapon/weapon_zone.gd`
- Create: `src/sim/fighter/body_part.gd`
- Create: `src/sim/combat/combat_tuning.gd`
- Create: `src/sim/combat/hit_classifier.gd`
- Test: `tests/sim/combat/test_hit_classifier.gd`
- Test: `tests/sim/combat/test_combat_tuning.gd`

**Interfaces:**
- Produces:
  - `HitType.Kind { CUT, THRUST, BLUNT }`
  - `WeaponZone.Kind { EDGE, FLAT, TIP, GUARD, HANDLE, HEAD }`
  - `BodyPart.Kind { HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R }`, `BodyPart.ALL: Array[int]`, `BodyPart.is_limb(part: int) -> bool`, `BodyPart.is_vital(part: int) -> bool`, `BodyPart.is_arm(part: int) -> bool`, `BodyPart.is_leg(part: int) -> bool`
  - `CombatTuning` (Resource) com campos listados no código e métodos `type_mult(hit_type: int) -> float`, `part_mult(part: int) -> float`, `balance_per_joule(hit_type: int) -> float`
  - `HitClassifier.classify(zone: int, v_rel: Vector3, blade_axis: Vector3, edge_dir: Vector3, tuning: CombatTuning) -> int` (retorna `HitType.Kind`). `edge_dir` é a direção para fora do fio que fez contato (o chamador escolhe o lado).

- [ ] **Step 1: Escrever os testes**

`tests/sim/combat/test_hit_classifier.gd`:

```gdscript
extends GutTest

const AXIS := Vector3.UP        # lâmina aponta para +Y
const EDGE := Vector3.RIGHT     # fio aponta para +X
var tuning := CombatTuning.new()


func _classify(zone: int, v: Vector3) -> int:
	return HitClassifier.classify(zone, v, AXIS, EDGE, tuning)


func test_edge_moving_edge_first_is_cut() -> void:
	assert_eq(_classify(WeaponZone.Kind.EDGE, Vector3(10, 0, 0)), HitType.Kind.CUT)


func test_edge_moving_sideways_is_blunt() -> void:
	# Movendo pela chapa (Z): não corta.
	assert_eq(_classify(WeaponZone.Kind.EDGE, Vector3(0, 0, 10)), HitType.Kind.BLUNT)


func test_edge_within_cut_angle_is_cut() -> void:
	var v := Vector3(cos(deg_to_rad(30.0)), 0, sin(deg_to_rad(30.0))) * 10.0
	assert_eq(_classify(WeaponZone.Kind.EDGE, v), HitType.Kind.CUT)


func test_edge_beyond_cut_angle_is_blunt() -> void:
	var v := Vector3(cos(deg_to_rad(40.0)), 0, sin(deg_to_rad(40.0))) * 10.0
	assert_eq(_classify(WeaponZone.Kind.EDGE, v), HitType.Kind.BLUNT)


func test_tip_moving_along_axis_is_thrust() -> void:
	assert_eq(_classify(WeaponZone.Kind.TIP, Vector3(0, 8, 0)), HitType.Kind.THRUST)


func test_tip_moving_edge_first_is_cut() -> void:
	assert_eq(_classify(WeaponZone.Kind.TIP, Vector3(8, 0, 0)), HitType.Kind.CUT)


func test_flat_is_blunt() -> void:
	assert_eq(_classify(WeaponZone.Kind.FLAT, Vector3(10, 0, 0)), HitType.Kind.BLUNT)


func test_head_is_blunt() -> void:
	assert_eq(_classify(WeaponZone.Kind.HEAD, Vector3(0, 8, 0)), HitType.Kind.BLUNT)


func test_zero_velocity_is_blunt() -> void:
	assert_eq(_classify(WeaponZone.Kind.EDGE, Vector3.ZERO), HitType.Kind.BLUNT)
```

`tests/sim/combat/test_combat_tuning.gd`:

```gdscript
extends GutTest

var t := CombatTuning.new()


func test_type_mult_maps_each_type() -> void:
	assert_eq(t.type_mult(HitType.Kind.CUT), t.cut_mult)
	assert_eq(t.type_mult(HitType.Kind.THRUST), t.thrust_mult)
	assert_eq(t.type_mult(HitType.Kind.BLUNT), t.blunt_mult)


func test_part_mult_maps_each_part() -> void:
	assert_eq(t.part_mult(BodyPart.Kind.HEAD), t.head_mult)
	assert_eq(t.part_mult(BodyPart.Kind.TORSO), t.torso_mult)
	assert_eq(t.part_mult(BodyPart.Kind.ARM_L), t.arm_mult)
	assert_eq(t.part_mult(BodyPart.Kind.LEG_R), t.leg_mult)


func test_blunt_drains_more_balance_than_cut() -> void:
	assert_gt(t.balance_per_joule(HitType.Kind.BLUNT), t.balance_per_joule(HitType.Kind.CUT))


func test_body_part_helpers() -> void:
	assert_true(BodyPart.is_limb(BodyPart.Kind.ARM_R))
	assert_false(BodyPart.is_limb(BodyPart.Kind.HEAD))
	assert_true(BodyPart.is_vital(BodyPart.Kind.TORSO))
	assert_true(BodyPart.is_arm(BodyPart.Kind.ARM_L))
	assert_true(BodyPart.is_leg(BodyPart.Kind.LEG_L))
	assert_eq(BodyPart.ALL.size(), 6)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_hit_classifier.gd`
Expected: FAIL — classes não existem.

- [ ] **Step 3: Implementar enums**

`src/sim/combat/hit_type.gd`:

```gdscript
class_name HitType
extends RefCounted

enum Kind { CUT, THRUST, BLUNT }
```

`src/sim/weapon/weapon_zone.gd`:

```gdscript
class_name WeaponZone
extends RefCounted

enum Kind { EDGE, FLAT, TIP, GUARD, HANDLE, HEAD }
```

`src/sim/fighter/body_part.gd`:

```gdscript
class_name BodyPart
extends RefCounted

enum Kind { HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R }

const ALL: Array[int] = [Kind.HEAD, Kind.TORSO, Kind.ARM_L, Kind.ARM_R, Kind.LEG_L, Kind.LEG_R]


static func is_arm(part: int) -> bool:
	return part == Kind.ARM_L or part == Kind.ARM_R


static func is_leg(part: int) -> bool:
	return part == Kind.LEG_L or part == Kind.LEG_R


static func is_limb(part: int) -> bool:
	return is_arm(part) or is_leg(part)


static func is_vital(part: int) -> bool:
	return part == Kind.HEAD or part == Kind.TORSO
```

- [ ] **Step 4: Implementar `CombatTuning`**

`src/sim/combat/combat_tuning.gd`:

```gdscript
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
```

- [ ] **Step 5: Implementar `HitClassifier`**

`src/sim/combat/hit_classifier.gd`:

```gdscript
class_name HitClassifier
extends RefCounted
## Decide o tipo do golpe pela zona tocada e pela direção do movimento.


## `v_rel`: velocidade do ponto da arma relativa ao alvo.
## `blade_axis`: direção da guarda para a ponta.
## `edge_dir`: direção para fora do fio que tocou (o chamador escolhe o lado).
static func classify(zone: int, v_rel: Vector3, blade_axis: Vector3, edge_dir: Vector3, tuning: CombatTuning) -> int:
	if v_rel.length_squared() < 1e-8:
		return HitType.Kind.BLUNT
	var v := v_rel.normalized()
	var cut_cos := cos(deg_to_rad(tuning.cut_max_angle_deg))
	match zone:
		WeaponZone.Kind.TIP:
			if v.dot(blade_axis.normalized()) >= cos(deg_to_rad(tuning.thrust_max_angle_deg)):
				return HitType.Kind.THRUST
			if v.dot(edge_dir.normalized()) >= cut_cos:
				return HitType.Kind.CUT
			return HitType.Kind.BLUNT
		WeaponZone.Kind.EDGE:
			if v.dot(edge_dir.normalized()) >= cut_cos:
				return HitType.Kind.CUT
			return HitType.Kind.BLUNT
		_:
			return HitType.Kind.BLUNT
```

- [ ] **Step 6: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1`
Expected: todos os testes PASS (inclusive os das tasks anteriores).

- [ ] **Step 7: Commit**

```powershell
git add src/sim/combat src/sim/weapon/weapon_zone.gd src/sim/fighter/body_part.gd tests/sim/combat
git commit -m @'
feat(sim): classify hits as cut, thrust or blunt with tunable parameters

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 5: `DamageCalculator`

**Files:**
- Create: `src/sim/combat/damage_calculator.gd`
- Test: `tests/sim/combat/test_damage_calculator.gd`

**Interfaces:**
- Consumes: `CombatTuning`, `HitType.Kind`, `BodyPart.Kind` (Task 4)
- Produces:
  - `DamageCalculator.damage(energy: float, hit_type: int, part: int, weapon_mult: float, tuning: CombatTuning) -> float`
  - `DamageCalculator.balance_drain(energy: float, hit_type: int, tuning: CombatTuning) -> float`

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

var t := CombatTuning.new()  # graze 10, 0.5 dano/J, cut 1.0, thrust 1.3, head 2.0


func test_graze_does_no_damage() -> void:
	assert_eq(DamageCalculator.damage(9.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t), 0.0)
	assert_eq(DamageCalculator.damage(10.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t), 0.0)


func test_cut_on_torso() -> void:
	# (110 - 10) * 0.5 * 1.0 * 1.0 * 1.0 = 50
	assert_almost_eq(DamageCalculator.damage(110.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t), 50.0, 1e-4)


func test_thrust_on_head() -> void:
	# 100 * 0.5 * 1.3 * 2.0 = 130
	assert_almost_eq(DamageCalculator.damage(110.0, HitType.Kind.THRUST, BodyPart.Kind.HEAD, 1.0, t), 130.0, 1e-4)


func test_weapon_mult_scales_damage() -> void:
	var base := DamageCalculator.damage(110.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 1.0, t)
	var doubled := DamageCalculator.damage(110.0, HitType.Kind.CUT, BodyPart.Kind.TORSO, 2.0, t)
	assert_almost_eq(doubled, base * 2.0, 1e-4)


func test_graze_does_not_drain_balance() -> void:
	assert_eq(DamageCalculator.balance_drain(5.0, HitType.Kind.BLUNT, t), 0.0)


func test_blunt_drains_more_than_cut_at_same_energy() -> void:
	var blunt := DamageCalculator.balance_drain(100.0, HitType.Kind.BLUNT, t)
	var cut := DamageCalculator.balance_drain(100.0, HitType.Kind.CUT, t)
	assert_gt(blunt, cut)
	assert_almost_eq(blunt, 25.0, 1e-4)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_damage_calculator.gd`
Expected: FAIL — `DamageCalculator` não existe.

- [ ] **Step 3: Implementar**

```gdscript
class_name DamageCalculator
extends RefCounted
## Converte a energia de um contato em dano e dreno de equilíbrio.


static func damage(energy: float, hit_type: int, part: int, weapon_mult: float, tuning: CombatTuning) -> float:
	if energy <= tuning.graze_energy:
		return 0.0
	return (energy - tuning.graze_energy) * tuning.damage_per_joule \
		* tuning.type_mult(hit_type) * tuning.part_mult(part) * weapon_mult


static func balance_drain(energy: float, hit_type: int, tuning: CombatTuning) -> float:
	if energy <= tuning.graze_energy:
		return 0.0
	return energy * tuning.balance_per_joule(hit_type)
```

- [ ] **Step 4: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_damage_calculator.gd`
Expected: 6 PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/sim/combat/damage_calculator.gd tests/sim/combat/test_damage_calculator.gd
git commit -m @'
feat(sim): compute damage and balance drain from contact energy

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 6: `FighterTuning` e `BodyHealth`

**Files:**
- Create: `src/sim/fighter/fighter_tuning.gd`
- Create: `src/sim/fighter/body_health.gd`
- Test: `tests/sim/fighter/test_body_health.gd`

**Interfaces:**
- Consumes: `BodyPart`, `HitType`, `CombatTuning`
- Produces:
  - `FighterTuning` (Resource) — campos no código abaixo (vida, equilíbrio, stamina)
  - `BodyHealth.new(tuning: FighterTuning)`
  - `signal limb_severed(part: int)`, `signal died`
  - `health(part: int) -> float`, `max_health(part: int) -> float`, `is_severed(part: int) -> bool`, `is_dead: bool`
  - `apply_damage(part: int, amount: float, hit_type: int, energy: float, combat: CombatTuning) -> void`
  - `limb_strength(part: int) -> float` — 0 se decepado; `lerp(min_limb_strength, 1, vida/max)` caso contrário

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

var ft := FighterTuning.new()
var ct := CombatTuning.new()
var h: BodyHealth


func before_each() -> void:
	h = BodyHealth.new(ft)


func test_starts_full() -> void:
	for part in BodyPart.ALL:
		assert_eq(h.health(part), h.max_health(part))
	assert_false(h.is_dead)


func test_damage_reduces_and_clamps_at_zero() -> void:
	h.apply_damage(BodyPart.Kind.ARM_L, 30.0, HitType.Kind.CUT, 50.0, ct)
	assert_eq(h.health(BodyPart.Kind.ARM_L), ft.limb_max_health - 30.0)
	h.apply_damage(BodyPart.Kind.ARM_L, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_eq(h.health(BodyPart.Kind.ARM_L), 0.0)


func test_strong_cut_on_zeroed_limb_severs() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, ct.sever_energy + 1.0, ct)
	assert_true(h.is_severed(BodyPart.Kind.ARM_R))
	assert_signal_emitted_with_parameters(h, "limb_severed", [BodyPart.Kind.ARM_R])


func test_blunt_never_severs() -> void:
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.BLUNT, 9999.0, ct)
	assert_false(h.is_severed(BodyPart.Kind.ARM_R))


func test_weak_cut_does_not_sever() -> void:
	h.apply_damage(BodyPart.Kind.LEG_L, 9999.0, HitType.Kind.CUT, ct.sever_energy - 1.0, ct)
	assert_false(h.is_severed(BodyPart.Kind.LEG_L))


func test_severed_emits_only_once() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, 999.0, ct)
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, 999.0, ct)
	assert_signal_emit_count(h, "limb_severed", 1)


func test_zero_head_kills() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.HEAD, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_true(h.is_dead)
	assert_signal_emitted(h, "died")


func test_zero_limb_does_not_kill() -> void:
	h.apply_damage(BodyPart.Kind.LEG_R, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_false(h.is_dead)


func test_dead_body_ignores_damage() -> void:
	watch_signals(h)
	h.apply_damage(BodyPart.Kind.TORSO, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	h.apply_damage(BodyPart.Kind.HEAD, 9999.0, HitType.Kind.BLUNT, 50.0, ct)
	assert_signal_emit_count(h, "died", 1)
	assert_eq(h.health(BodyPart.Kind.HEAD), h.max_health(BodyPart.Kind.HEAD))


func test_limb_strength_scales_with_health() -> void:
	assert_eq(h.limb_strength(BodyPart.Kind.ARM_R), 1.0)
	h.apply_damage(BodyPart.Kind.ARM_R, ft.limb_max_health, HitType.Kind.BLUNT, 50.0, ct)
	assert_almost_eq(h.limb_strength(BodyPart.Kind.ARM_R), ft.min_limb_strength, 1e-5)


func test_severed_limb_has_zero_strength() -> void:
	h.apply_damage(BodyPart.Kind.ARM_R, 9999.0, HitType.Kind.CUT, 999.0, ct)
	assert_eq(h.limb_strength(BodyPart.Kind.ARM_R), 0.0)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_body_health.gd`
Expected: FAIL — classes não existem.

- [ ] **Step 3: Implementar `FighterTuning`**

`src/sim/fighter/fighter_tuning.gd`:

```gdscript
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
```

- [ ] **Step 4: Implementar `BodyHealth`**

`src/sim/fighter/body_health.gd`:

```gdscript
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
```

- [ ] **Step 5: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_body_health.gd`
Expected: 11 PASS.

- [ ] **Step 6: Commit**

```powershell
git add src/sim/fighter tests/sim/fighter
git commit -m @'
feat(sim): add per-part body health with severing and death

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 7: `Balance`

**Files:**
- Create: `src/sim/fighter/balance.gd`
- Test: `tests/sim/fighter/test_balance.gd`

**Interfaces:**
- Consumes: `FighterTuning`
- Produces:
  - `Balance.new(tuning: FighterTuning)`
  - `signal lost`, `signal recovered`
  - `value: float`, `is_down: bool`
  - `drain(amount: float) -> void` — ignorado enquanto caído
  - `step(dt: float, leg_strength: float = 1.0) -> void` — regeneração/recuperação por tick
  - `support_factor() -> float` — 0 se caído; `lerp(min_support_factor, 1, value/max)` caso contrário (usado pela mola da pelve no SP1-B)

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

var ft := FighterTuning.new()
var b: Balance


func before_each() -> void:
	b = Balance.new(ft)


func _advance(seconds: float, leg_strength: float = 1.0) -> void:
	var dt := 1.0 / 120.0
	for i in int(round(seconds / dt)):
		b.step(dt, leg_strength)


func test_starts_full_and_standing() -> void:
	assert_eq(b.value, ft.balance_max)
	assert_false(b.is_down)
	assert_eq(b.support_factor(), 1.0)


func test_drain_reduces_value() -> void:
	b.drain(30.0)
	assert_eq(b.value, ft.balance_max - 30.0)


func test_draining_to_zero_falls() -> void:
	watch_signals(b)
	b.drain(ft.balance_max + 5.0)
	assert_true(b.is_down)
	assert_eq(b.value, 0.0)
	assert_eq(b.support_factor(), 0.0)
	assert_signal_emitted(b, "lost")


func test_no_drain_while_down() -> void:
	watch_signals(b)
	b.drain(999.0)
	b.drain(999.0)
	assert_signal_emit_count(b, "lost", 1)


func test_recovers_after_recovery_time() -> void:
	watch_signals(b)
	b.drain(999.0)
	_advance(ft.balance_recovery_time - 0.1)
	assert_true(b.is_down)
	_advance(0.2)
	assert_false(b.is_down)
	assert_eq(b.value, ft.balance_recovered_value)
	assert_signal_emitted(b, "recovered")


func test_no_regen_before_delay() -> void:
	b.drain(50.0)
	_advance(ft.balance_regen_delay * 0.5)
	assert_eq(b.value, ft.balance_max - 50.0)


func test_regen_after_delay() -> void:
	b.drain(50.0)
	_advance(ft.balance_regen_delay + 1.0)
	assert_gt(b.value, ft.balance_max - 50.0)
	assert_lte(b.value, ft.balance_max)


func test_injured_legs_regen_slower() -> void:
	var healthy := Balance.new(ft)
	var injured := Balance.new(ft)
	healthy.drain(80.0)
	injured.drain(80.0)
	var dt := 1.0 / 120.0
	for i in 120:
		healthy.step(dt, 1.0)
		injured.step(dt, 0.3)
	assert_gt(healthy.value, injured.value)


func test_support_factor_scales_with_value() -> void:
	b.drain(ft.balance_max * 0.5)
	assert_almost_eq(b.support_factor(), lerpf(ft.min_support_factor, 1.0, 0.5), 1e-5)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_balance.gd`
Expected: FAIL — `Balance` não existe.

- [ ] **Step 3: Implementar**

```gdscript
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
```

- [ ] **Step 4: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_balance.gd`
Expected: 9 PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/sim/fighter/balance.gd tests/sim/fighter/test_balance.gd
git commit -m @'
feat(sim): add balance bar with fall and recovery

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 8: `Stamina`

**Files:**
- Create: `src/sim/fighter/stamina.gd`
- Test: `tests/sim/fighter/test_stamina.gd`

**Interfaces:**
- Consumes: `FighterTuning`
- Produces:
  - `Stamina.new(tuning: FighterTuning)`
  - `value: float`
  - `try_spend(amount: float) -> bool` — gasta só se houver o suficiente
  - `drain_continuous(rate_per_s: float, dt: float) -> bool` — gasta contínuo (tensão, corrida); retorna `false` se acabou
  - `step(dt: float) -> void` — regeneração após atraso
  - `is_exhausted() -> bool`
  - `strength_factor() -> float` — 1.0 ou `exhausted_strength`

- [ ] **Step 1: Escrever o teste**

```gdscript
extends GutTest

var ft := FighterTuning.new()
var s: Stamina
const DT := 1.0 / 120.0


func before_each() -> void:
	s = Stamina.new(ft)


func test_starts_full() -> void:
	assert_eq(s.value, ft.stamina_max)
	assert_false(s.is_exhausted())
	assert_eq(s.strength_factor(), 1.0)


func test_try_spend_succeeds_and_reduces() -> void:
	assert_true(s.try_spend(ft.cost_thrust))
	assert_eq(s.value, ft.stamina_max - ft.cost_thrust)


func test_try_spend_fails_without_enough() -> void:
	s.try_spend(ft.stamina_max - 5.0)
	assert_false(s.try_spend(10.0))
	assert_eq(s.value, 5.0)


func test_continuous_drain_until_exhausted() -> void:
	var sustained := true
	for i in 10000:
		sustained = s.drain_continuous(ft.tension_per_s, DT)
		if not sustained:
			break
	assert_false(sustained)
	assert_true(s.is_exhausted())
	assert_eq(s.value, 0.0)
	assert_eq(s.strength_factor(), ft.exhausted_strength)


func test_regen_waits_for_delay() -> void:
	s.try_spend(50.0)
	for i in int(ft.stamina_regen_delay * 0.5 / DT):
		s.step(DT)
	assert_eq(s.value, ft.stamina_max - 50.0)


func test_regen_after_delay_caps_at_max() -> void:
	s.try_spend(10.0)
	for i in int(10.0 / DT):
		s.step(DT)
	assert_eq(s.value, ft.stamina_max)


func test_spending_resets_regen_delay() -> void:
	s.try_spend(50.0)
	for i in int(ft.stamina_regen_delay * 0.9 / DT):
		s.step(DT)
	s.try_spend(1.0)
	for i in int(ft.stamina_regen_delay * 0.5 / DT):
		s.step(DT)
	assert_eq(s.value, ft.stamina_max - 51.0)
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_stamina.gd`
Expected: FAIL — `Stamina` não existe.

- [ ] **Step 3: Implementar**

```gdscript
class_name Stamina
extends RefCounted
## Energia para tensão, estocada, chute, esquiva, corrida e parry.

var value: float

var _tuning: FighterTuning
var _since_spend: float = 0.0


func _init(tuning: FighterTuning) -> void:
	_tuning = tuning
	value = tuning.stamina_max


func try_spend(amount: float) -> bool:
	if value < amount:
		return false
	value -= amount
	_since_spend = 0.0
	return true


func drain_continuous(rate_per_s: float, dt: float) -> bool:
	if value <= 0.0:
		return false
	value = maxf(0.0, value - rate_per_s * dt)
	_since_spend = 0.0
	return value > 0.0


func step(dt: float) -> void:
	_since_spend += dt
	if _since_spend >= _tuning.stamina_regen_delay:
		value = minf(_tuning.stamina_max, value + _tuning.stamina_regen_per_s * dt)


func is_exhausted() -> bool:
	return value <= 0.0


func strength_factor() -> float:
	return _tuning.exhausted_strength if is_exhausted() else 1.0
```

- [ ] **Step 4: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_stamina.gd`
Expected: 7 PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/sim/fighter/stamina.gd tests/sim/fighter/test_stamina.gd
git commit -m @'
feat(sim): add stamina with costs, regen delay and exhaustion

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 9: Dados de armas — `WeaponSection`, `WeaponData`, `WeaponCatalog`

**Files:**
- Create: `src/sim/weapon/weapon_section.gd`
- Create: `src/sim/weapon/weapon_data.gd`
- Create: `src/sim/weapon/weapon_catalog.gd`
- Test: `tests/sim/weapon/test_weapon_data.gd`
- Test: `tests/sim/weapon/test_weapon_catalog.gd`

**Interfaces:**
- Consumes: `WeaponZone.Kind`
- Produces:
  - `WeaponSection` (Resource): `enum Kind { POMMEL, HANDLE, GUARD, BLADE, SHAFT, HEAD }`, campos `kind: int`, `y_from: float`, `y_to: float`, `half_width: float` (X), `half_thickness: float` (Z), `mass: float`; `center_y() -> float`; `static make(kind: int, y_from: float, y_to: float, half_width: float, half_thickness: float, mass: float) -> WeaponSection`
  - `WeaponData` (Resource): `id: StringName`, `display_name: String`, `damage_mult: float`, `grip_primary: float`, `grip_secondary: float`, `double_edged: bool`, `tip_length: float`, `sections: Array[WeaponSection]`; `total_mass() -> float`, `center_of_mass() -> Vector3`, `inertia_about_com() -> Vector3` (momentos principais), `length() -> float`, `section_at(y: float) -> WeaponSection`, `zone_at(local_point: Vector3, local_normal: Vector3) -> int`
  - `WeaponCatalog.longsword() -> WeaponData`, `WeaponCatalog.hammer() -> WeaponData`, `WeaponCatalog.all() -> Array[WeaponData]`

A massa e a inércia vêm das seções (não da malha): SP1-B usa `total_mass()`, `center_of_mass()` e `inertia_about_com()` para configurar o `RigidBody3D` da arma; SP1-C usa `zone_at()` para cada contato.

- [ ] **Step 1: Escrever os testes**

`tests/sim/weapon/test_weapon_data.gd`:

```gdscript
extends GutTest


func _two_block_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.tip_length = 0.1
	w.double_edged = false
	w.sections = [
		WeaponSection.make(WeaponSection.Kind.HANDLE, -0.2, 0.0, 0.02, 0.02, 1.0),
		WeaponSection.make(WeaponSection.Kind.BLADE, 0.0, 0.8, 0.03, 0.005, 3.0),
	]
	return w


func test_total_mass_sums_sections() -> void:
	assert_almost_eq(_two_block_weapon().total_mass(), 4.0, 1e-5)


func test_center_of_mass_is_weighted_average() -> void:
	# (1 * -0.1 + 3 * 0.4) / 4 = 0.275
	assert_almost_eq(_two_block_weapon().center_of_mass(), Vector3(0, 0.275, 0), Vector3.ONE * 1e-5)


func test_length_spans_all_sections() -> void:
	assert_almost_eq(_two_block_weapon().length(), 1.0, 1e-5)


func test_inertia_single_box_matches_formula() -> void:
	var w := WeaponData.new()
	w.sections = [WeaponSection.make(WeaponSection.Kind.BLADE, 0.0, 1.0, 0.05, 0.01, 2.0)]
	var i := w.inertia_about_com()
	# Caixa 0.1 x 1.0 x 0.02, massa 2: Izz = m/12 (lx^2 + ly^2)
	assert_almost_eq(i.z, 2.0 / 12.0 * (0.01 + 1.0), 1e-5)
	assert_almost_eq(i.y, 2.0 / 12.0 * (0.01 + 0.0004), 1e-5)


func test_inertia_uses_parallel_axis() -> void:
	var w := _two_block_weapon()
	var com := w.center_of_mass().y
	var naive := 0.0
	for s in w.sections:
		var ly := s.y_to - s.y_from
		var lx := s.half_width * 2.0
		naive += s.mass / 12.0 * (lx * lx + ly * ly)
	assert_gt(w.inertia_about_com().z, naive)


func test_zone_tip() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0.03, 0.75, 0), Vector3.RIGHT), WeaponZone.Kind.TIP)


func test_zone_edge_on_primary_side() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0.03, 0.4, 0), Vector3.RIGHT), WeaponZone.Kind.EDGE)


func test_zone_single_edge_back_is_flat() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(-0.03, 0.4, 0), Vector3.LEFT), WeaponZone.Kind.FLAT)


func test_zone_double_edge_back_is_edge() -> void:
	var w := _two_block_weapon()
	w.double_edged = true
	assert_eq(w.zone_at(Vector3(-0.03, 0.4, 0), Vector3.LEFT), WeaponZone.Kind.EDGE)


func test_zone_flat_side() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0, 0.4, 0.005), Vector3.BACK), WeaponZone.Kind.FLAT)


func test_zone_handle() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0, -0.1, 0), Vector3.RIGHT), WeaponZone.Kind.HANDLE)


func test_zone_outside_clamps_to_nearest_section() -> void:
	assert_eq(_two_block_weapon().zone_at(Vector3(0, -0.5, 0), Vector3.RIGHT), WeaponZone.Kind.HANDLE)
	assert_eq(_two_block_weapon().zone_at(Vector3(0, 0.9, 0), Vector3.UP), WeaponZone.Kind.TIP)
```

`tests/sim/weapon/test_weapon_catalog.gd`:

```gdscript
extends GutTest


func test_longsword_matches_spec() -> void:
	var w := WeaponCatalog.longsword()
	assert_almost_eq(w.total_mass(), 1.4, 0.01)
	assert_almost_eq(w.length(), 1.1, 0.05)
	var com := w.center_of_mass().y
	assert_between(com, 0.08, 0.16, "CoM ~10 cm à frente da guarda")
	assert_true(w.double_edged)


func test_hammer_matches_spec() -> void:
	var w := WeaponCatalog.hammer()
	assert_almost_eq(w.total_mass(), 5.0, 0.01)
	assert_almost_eq(w.length(), 0.9, 0.05)
	assert_gt(w.center_of_mass().y, 0.55, "massa concentrada na cabeça")


func test_hammer_head_zone() -> void:
	var w := WeaponCatalog.hammer()
	assert_eq(w.zone_at(Vector3(0.09, 0.74, 0), Vector3.RIGHT), WeaponZone.Kind.HEAD)


func test_hammer_is_much_harder_to_swing() -> void:
	# Resistência a girar em torno da mão (eixo Z, pela pegada): I_com + m d^2.
	var sword := WeaponCatalog.longsword()
	var hammer := WeaponCatalog.hammer()
	var i_sword := sword.inertia_about_com().z + sword.total_mass() * pow(sword.center_of_mass().y - sword.grip_primary, 2)
	var i_hammer := hammer.inertia_about_com().z + hammer.total_mass() * pow(hammer.center_of_mass().y - hammer.grip_primary, 2)
	assert_gt(i_hammer, i_sword * 5.0)


func test_all_returns_both() -> void:
	var ids: Array[StringName] = []
	for w in WeaponCatalog.all():
		ids.append(w.id)
	assert_has(ids, &"longsword")
	assert_has(ids, &"hammer")
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_weapon`
Expected: FAIL — classes não existem.

- [ ] **Step 3: Implementar `WeaponSection`**

`src/sim/weapon/weapon_section.gd`:

```gdscript
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
```

- [ ] **Step 4: Implementar `WeaponData`**

`src/sim/weapon/weapon_data.gd`:

```gdscript
class_name WeaponData
extends Resource
## Definição física de uma arma. Espaço local: origem na base da guarda, +Y para a ponta,
## +X fio principal, +Z normal da chapa.

@export var id: StringName
@export var display_name: String
@export var damage_mult: float = 1.0
## Posição Y da mão principal e da segunda mão (pegada de duas mãos).
@export var grip_primary: float = 0.0
@export var grip_secondary: float = 0.0
@export var double_edged: bool = true
## Comprimento (m) a partir do fim da lâmina que conta como ponta.
@export var tip_length: float = 0.1
@export var sections: Array[WeaponSection] = []


func total_mass() -> float:
	var m := 0.0
	for s in sections:
		m += s.mass
	return m


func center_of_mass() -> Vector3:
	var acc := 0.0
	for s in sections:
		acc += s.mass * s.center_y()
	return Vector3(0.0, acc / total_mass(), 0.0)


## Momentos principais de inércia em torno do centro de massa (caixas + eixos paralelos).
func inertia_about_com() -> Vector3:
	var com_y := center_of_mass().y
	var inertia := Vector3.ZERO
	for s in sections:
		var lx := s.half_width * 2.0
		var ly := s.y_to - s.y_from
		var lz := s.half_thickness * 2.0
		var d := s.center_y() - com_y
		inertia.x += s.mass / 12.0 * (ly * ly + lz * lz) + s.mass * d * d
		inertia.y += s.mass / 12.0 * (lx * lx + lz * lz)
		inertia.z += s.mass / 12.0 * (lx * lx + ly * ly) + s.mass * d * d
	return inertia


func length() -> float:
	var lo := INF
	var hi := -INF
	for s in sections:
		lo = minf(lo, s.y_from)
		hi = maxf(hi, s.y_to)
	return hi - lo


## Seção que contém `y`; fora da arma, a seção mais próxima.
func section_at(y: float) -> WeaponSection:
	var best: WeaponSection = null
	var best_dist := INF
	for s in sections:
		if y >= s.y_from and y <= s.y_to:
			return s
		var dist := minf(absf(y - s.y_from), absf(y - s.y_to))
		if dist < best_dist:
			best_dist = dist
			best = s
	return best


func zone_at(local_point: Vector3, local_normal: Vector3) -> int:
	var s := section_at(local_point.y)
	match s.kind:
		WeaponSection.Kind.BLADE:
			if local_point.y >= s.y_to - tip_length:
				return WeaponZone.Kind.TIP
			if absf(local_normal.x) >= absf(local_normal.z) and (double_edged or local_normal.x > 0.0):
				return WeaponZone.Kind.EDGE
			return WeaponZone.Kind.FLAT
		WeaponSection.Kind.GUARD:
			return WeaponZone.Kind.GUARD
		WeaponSection.Kind.HEAD:
			return WeaponZone.Kind.HEAD
		_:
			return WeaponZone.Kind.HANDLE
```

- [ ] **Step 5: Implementar `WeaponCatalog`**

`src/sim/weapon/weapon_catalog.gd`:

```gdscript
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
```

- [ ] **Step 6: Rodar e ver passar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_weapon`
Expected: 17 PASS. Se `test_longsword_matches_spec` falhar no CoM, ajustar as massas de `POMMEL`/`BLADE` mantendo o total de 1,4 kg, sem mudar o teste.

- [ ] **Step 7: Commit**

```powershell
git add src/sim/weapon tests/sim/weapon
git commit -m @'
feat(sim): add weapon physical data, zones and SP1 catalog

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

### Task 10: Eventos, `CombatResolver` e `ParryJudge`

**Files:**
- Create: `src/sim/combat/hit_event.gd`
- Create: `src/sim/combat/clash_event.gd`
- Create: `src/sim/combat/combat_resolver.gd`
- Create: `src/sim/combat/parry_judge.gd`
- Test: `tests/sim/combat/test_combat_resolver.gd`
- Test: `tests/sim/combat/test_parry_judge.gd`

**Interfaces:**
- Consumes: `DamageCalculator`, `BodyHealth`, `Balance`, `CombatTuning`, `HitType`, `WeaponZone`, `BodyPart`
- Produces:
  - `HitEvent` (RefCounted): `tick: int`, `attacker_id: int`, `target_id: int`, `weapon_id: StringName`, `zone: int`, `part: int`, `hit_type: int`, `energy: float`, `point: Vector3`, `damage: float` (preenchido pelo resolver)
  - `ClashEvent` (RefCounted): `tick: int`, `energy: float`, `angle: float` (radianos entre as lâminas), `point: Vector3`, `weapon_a: StringName`, `zone_a: int`, `weapon_b: StringName`, `zone_b: int`, `fighter_a: int`, `fighter_b: int`, `momentum_a: float`, `momentum_b: float`
  - `CombatResolver.apply_hit(hit: HitEvent, weapon_mult: float, health: BodyHealth, balance: Balance, tuning: CombatTuning) -> void` — calcula `hit.damage`, aplica vida e dreno
  - `CombatResolver.clash_loser(clash: ClashEvent) -> int` — `fighter_a`/`fighter_b` de quem tinha menos momentum; `-1` se empate
  - `CombatResolver.clash_balance_drain(clash: ClashEvent, tuning: CombatTuning) -> float`
  - `ParryJudge.is_parry(zone_touched: int, hand_speed: float, time_since_free_hand: float, tuning: CombatTuning) -> bool`

Nota de spec: a janela do parry é contada desde o instante em que o RMB (modo mão livre) foi pressionado — é o que torna o parry uma leitura de timing.

- [ ] **Step 1: Escrever os testes**

`tests/sim/combat/test_combat_resolver.gd`:

```gdscript
extends GutTest

var ct := CombatTuning.new()
var ft := FighterTuning.new()


func _hit(part: int, hit_type: int, energy: float) -> HitEvent:
	var h := HitEvent.new()
	h.part = part
	h.hit_type = hit_type
	h.energy = energy
	return h


func test_apply_hit_damages_and_drains() -> void:
	var health := BodyHealth.new(ft)
	var balance := Balance.new(ft)
	var hit := _hit(BodyPart.Kind.TORSO, HitType.Kind.CUT, 110.0)
	CombatResolver.apply_hit(hit, 1.0, health, balance, ct)
	assert_almost_eq(hit.damage, 50.0, 1e-4)
	assert_almost_eq(health.health(BodyPart.Kind.TORSO), ft.torso_max_health - 50.0, 1e-4)
	assert_almost_eq(balance.value, ft.balance_max - 110.0 * ct.balance_per_joule_cut, 1e-4)


func test_graze_changes_nothing() -> void:
	var health := BodyHealth.new(ft)
	var balance := Balance.new(ft)
	var hit := _hit(BodyPart.Kind.HEAD, HitType.Kind.BLUNT, 5.0)
	CombatResolver.apply_hit(hit, 1.0, health, balance, ct)
	assert_eq(hit.damage, 0.0)
	assert_eq(health.health(BodyPart.Kind.HEAD), ft.head_max_health)
	assert_eq(balance.value, ft.balance_max)


func _clash(ma: float, mb: float) -> ClashEvent:
	var c := ClashEvent.new()
	c.fighter_a = 1
	c.fighter_b = 2
	c.momentum_a = ma
	c.momentum_b = mb
	return c


func test_clash_loser_is_lower_momentum() -> void:
	assert_eq(CombatResolver.clash_loser(_clash(10.0, 3.0)), 2)
	assert_eq(CombatResolver.clash_loser(_clash(2.0, 9.0)), 1)


func test_clash_tie_has_no_loser() -> void:
	assert_eq(CombatResolver.clash_loser(_clash(5.0, 5.0)), -1)


func test_clash_drain_proportional_to_difference() -> void:
	assert_almost_eq(CombatResolver.clash_balance_drain(_clash(10.0, 3.0), ct), 7.0 * ct.clash_balance_per_momentum, 1e-4)
	assert_eq(CombatResolver.clash_balance_drain(_clash(5.0, 5.0), ct), 0.0)
```

`tests/sim/combat/test_parry_judge.gd`:

```gdscript
extends GutTest

var ct := CombatTuning.new()  # janela 0.15 s, velocidade mínima 3 m/s


func test_flat_fast_in_window_is_parry() -> void:
	assert_true(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 5.0, 0.1, ct))


func test_edge_is_never_parry() -> void:
	assert_false(ParryJudge.is_parry(WeaponZone.Kind.EDGE, 5.0, 0.1, ct))


func test_slow_hand_is_not_parry() -> void:
	assert_false(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 1.0, 0.1, ct))


func test_late_is_not_parry() -> void:
	assert_false(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 5.0, 0.2, ct))


func test_window_boundary_is_inclusive() -> void:
	assert_true(ParryJudge.is_parry(WeaponZone.Kind.FLAT, 3.0, 0.15, ct))
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `powershell -File tools/run_tests.ps1 -gselect=test_combat_resolver.gd`
Expected: FAIL — classes não existem.

- [ ] **Step 3: Implementar eventos**

`src/sim/combat/hit_event.gd`:

```gdscript
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
```

`src/sim/combat/clash_event.gd`:

```gdscript
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
```

- [ ] **Step 4: Implementar `CombatResolver` e `ParryJudge`**

`src/sim/combat/combat_resolver.gd`:

```gdscript
class_name CombatResolver
extends RefCounted
## Aplica as consequências de acertos e choques no estado dos lutadores.


static func apply_hit(hit: HitEvent, weapon_mult: float, health: BodyHealth, balance: Balance, tuning: CombatTuning) -> void:
	hit.damage = DamageCalculator.damage(hit.energy, hit.hit_type, hit.part, weapon_mult, tuning)
	if hit.damage > 0.0:
		health.apply_damage(hit.part, hit.damage, hit.hit_type, hit.energy, tuning)
	balance.drain(DamageCalculator.balance_drain(hit.energy, hit.hit_type, tuning))


## Quem tinha menos momentum perde a linha. -1 em empate.
static func clash_loser(clash: ClashEvent) -> int:
	if is_equal_approx(clash.momentum_a, clash.momentum_b):
		return -1
	return clash.fighter_a if clash.momentum_a < clash.momentum_b else clash.fighter_b


static func clash_balance_drain(clash: ClashEvent, tuning: CombatTuning) -> float:
	return absf(clash.momentum_a - clash.momentum_b) * tuning.clash_balance_per_momentum
```

`src/sim/combat/parry_judge.gd`:

```gdscript
class_name ParryJudge
extends RefCounted
## Parry com a mão livre: tocar a chapa da lâmina inimiga, rápido, logo após pressionar RMB.


static func is_parry(zone_touched: int, hand_speed: float, time_since_free_hand: float, tuning: CombatTuning) -> bool:
	return zone_touched == WeaponZone.Kind.FLAT \
		and hand_speed >= tuning.parry_min_speed \
		and time_since_free_hand <= tuning.parry_window
```

- [ ] **Step 5: Rodar todos os testes**

Run: `powershell -File tools/run_tests.ps1`
Expected: todos PASS (≈ 70 testes), exit code 0.

- [ ] **Step 6: Commit**

```powershell
git add src/sim/combat tests/sim/combat
git commit -m @'
feat(sim): add hit/clash events, combat resolver and parry judge

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
'@
```

---

## Próximos planos do SP1 (escritos após concluir este)

- **SP1-B — Corpo físico e controle:** lutador ragdoll ativo (corpos Jolt + juntas + músculos PD), esqueleto-alvo com locomoção procedural por IK, mola da pelve ligada a `Balance.support_factor()`, mão da arma seguindo `InputCommand.hand_target` na esfera de alcance, giro por borda, tensão/carga, pegada 1/2 mãos/invertida, câmera 1ª/3ª e lock-on, coletor de input (mouse/teclado → `InputCommand`), arena cinza provisória.
- **SP1-C — Combate físico:** CCD nas armas, detecção de contatos → `zone_at` + `HitClassifier` + `CombatMath` → `HitEvent`/`ClashEvent`, disputa de momentum, mão livre (parry, agarrar/desarmar, empurrar), estocada, chute, esquiva, arremesso, desmembramento físico, obstáculo trava golpe, efeitos mínimos (faísca, tremor, hit stop).
- **SP1-D — Treino, assets e ajuste:** boneco, bot, espelho; painel F1 sobre `CombatTuning`/`FighterTuning`, câmera lenta e vetores; geradores Blender (manequim segmentado, espada, marreta, arena); testes de cenário headless, teste de desempenho de 8 lutadores e verificação de 60 FPS na UHD 730.
