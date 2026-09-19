# Joguinho — Design

Data: 2026-09-19
Status: aguardando revisão do usuário

Este documento tem duas partes:
1. **Visão geral** do jogo completo e sua divisão em sub-projetos (contexto para todos os ciclos futuros).
2. **Spec do Sub-projeto 1 — Núcleo físico de combate**, que é o escopo do primeiro plano de implementação.

---

# Parte 1 — Visão geral

## Conceito

Jogo de PC de luta com armas brancas em 3D, arena livre, online, para um grupo fechado de amigos. Não há matchmaking, contas ou escala: existe **uma única sala**, um playground de PvP onde cada um entra, escolhe sua arma e luta com quem quiser.

## Pilares

1. **Espada** — cada arma é um objeto físico real: massa, comprimento, centro de massa e material determinam como ela se move, bate, choca e quebra. Cada arma pode ter golpes/habilidades próprios.
2. **Beleza** — duplo sentido: o jogo é visualmente espetacular (impacto, temas visuais por arma) **e** lutar com estilo é recompensado mecanicamente (medidor de estilo).
3. **Habilidade do jogador** — o resultado vem de controle, leitura, posicionamento, timing e uso do ambiente, não de estatísticas.

## Decisões globais

| Área | Decisão |
|---|---|
| Engine | Godot 4.6 + Jolt Physics |
| Linguagem | GDScript com tipagem estática; trechos críticos podem migrar para C++ (GDExtension) |
| Assets | Gerados proceduralmente por scripts Python no Blender 5.2 headless; saída `.glb` |
| Câmera | Alternável 1ª/3ª pessoa + lock-on opcional |
| Corpo | Ragdoll ativo "híbrido firme": pernas/locomoção assistidas, tronco/braços/arma física real, barra de equilíbrio; ao zerar, ragdoll total |
| Controle da arma | Mouse controla a **mão** que empunha; a lâmina reage pela física |
| Dano | Energia real no ponto de contato (massa efetiva × velocidade relativa²), tipo de golpe pela geometria (corte/contusão/perfuração), dano localizado, ferimentos afetam o corpo, desmembramento |
| Sala | Até 8 jogadores. Modo livre com respawn rápido + duelo formal opcional (rodadas, demais assistem) |
| Escolha de arma | Racks físicos na arena + menu como atalho |
| Balanceamento | Caótico/diversão — armas não precisam ser equivalentes |
| Fratura | Armas racham e quebram conforme energia, ângulo e material; jogador continua lutando com o pedaço; fragmento vira objeto pegável/arremessável; arma nova no respawn ou rack |
| Temas visuais | Cada arma tem uma direção visual (anime, sabre de luz, voxel/Minecraft, realista...). A tela de cada lutador segue o tema da sua arma; quem luta melhor/com mais estilo **invade** a tela do oponente com seu tema; espectadores veem o choque |
| Estilo | Medidor D→S (variedade, risco, parries, precisão; repetição derruba), com bônus mecânico, intensificação visual do tema e replay de highlights |
| Customização | Peças + cores do personagem; tema da arma aplica camada visual |
| Áudio | Choque/fratura sintetizados a partir dos dados físicos + bancos CC0; música por tema |
| Rede | Híbrido: cliente autoritativo sobre o próprio corpo; servidor autoritativo sobre interações (choque, acerto, dano, fratura, posse de armas) com compensação de lag |
| Servidor | Dedicado headless desde o início. Hospedado agora no PC do usuário (i5-14400, 32 GB); futuramente notebook dedicado ou VPS |
| Gráficos | Presets baixo/médio/alto (hardware do grupo é misto; PC do usuário tem Intel UHD 730 por enquanto) |
| Armas v1 | 3–4 bem diferentes (ex.: espada longa realista, sabre de luz, foice gigante, espada voxel) |

## Lista completa de mecânicas (aprovadas)

- **Lâmina:** mão segue o mouse; estocada em botão dedicado.
- **Defesa:** parry com mão livre, bloqueio com a lâmina, esquiva/dash, agarrar/desarmar.
- **Ataque:** especiais por arma, combos, feint, chute/empurrão, golpe carregado, golpe aéreo/mergulho, finalização, duas armas, arremessar arma.
- **Sistemas:** stamina, troca de pegada (1 mão / 2 mãos / invertida), lock-on opcional.
- **Movimento:** corrida, pulo, agachar, parkour leve.
- **Ambiente:** obstáculos travam golpes; cenário destrutível (o que quebra depende do cenário **e** da arma); objetos interativos (o que é pegável/arremessável depende do cenário); quedas/ring-out.
- **Corpo:** dano localizado, ferimento afeta corpo, desmembramento, ragdoll ativo.

## Sub-projetos

Cada um tem seu próprio ciclo spec → plano → implementação e termina jogável.

| # | Sub-projeto | Entrega |
|---|---|---|
| 1 | Núcleo físico de combate | Offline, jogador vs boneco/bot, arena cinza, 2 armas |
| 2 | Rede e sala | Servidor dedicado, 8 jogadores, modelo híbrido, respawn, racks/menu, duelo formal |
| 3 | Armas e fratura | Gerador de armas, rachadura/quebra, luta com o pedaço, especiais, 3–4 armas v1, duas armas, arremesso |
| 4 | Beleza | Impacto completo (hit stop, tremor, impact frames), medidor de estilo, temas + invasão, replay, áudio procedural |
| 5 | Mundo e personagem | Arenas (coliseu, octógono, playground), destruição, objetos, parkour, customização, presets gráficos |

Ordem: 1 → 2 → 3 → 4 → 5. A rede vem cedo porque o modelo híbrido molda toda a simulação.

---

# Parte 2 — Sub-projeto 1: Núcleo físico de combate

## Objetivo

Provar que controlar a mão com o mouse, sobre um corpo físico, com armas de massa real, é **gostoso, legível e habilidoso**. Se isso não funcionar, nada acima importa.

## Escopo

**Dentro:**
- Um lutador controlado pelo jogador e oponentes de treino (boneco, bot, espelho).
- Corpo ragdoll ativo híbrido firme com equilíbrio, vida por parte, ferimentos, desmembramento e morte.
- Controle de mão por mouse, tensão (LMB), mão livre (RMB), giro do fio, estocada, chute, troca de pegada, arremesso, esquiva, corrida, pulo, agachar.
- Câmera 1ª/3ª pessoa e lock-on.
- Colisão, dano por energia, tipos de golpe, evento `Clash`.
- Stamina.
- Efeitos mínimos: faísca, tremor de câmera e hit stop simples.
- 2 armas: espada longa (~1,4 kg) e marreta (~5 kg).
- Arena cinza com grade de medida e alguns obstáculos (parede, pilar) para testar "obstáculo trava golpe".
- Ferramentas de ajuste em jogo.
- Arquitetura pronta para rede: tick fixo, `InputCommand`, `sim/` isolado de `view/`.

**Fora (sub-projetos futuros):** rede; fratura; especiais por arma; duas armas; combos reconhecidos e medidor de estilo; temas visuais; áudio além de placeholders; destruição de cenário; parkour; customização; presets gráficos além do baixo; finalização; golpe aéreo como mecânica dedicada (pulo + golpe funciona naturalmente pela física).

## Arquitetura

### Camadas

- **`sim/`** — lógica pura de jogo. Não referencia nada de `view/`. Entrada: `InputCommand` por lutador por tick. Saída: estado dos corpos + eventos (`Clash`, `Hit`, `LimbSevered`, `BalanceLost`, `Died`). É o código que o servidor rodará no sub-projeto 2.
- **`view/`** — câmera, efeitos, HUD, debug. Apenas lê estado e escuta eventos.
- **`bot/`** — produz `InputCommand` como se fosse um jogador.

### Tick

- Física a **120 Hz fixo** (`physics_ticks_per_second = 120`), independente do FPS de renderização.
- Renderização interpola entre ticks.
- Input do mouse é acumulado por frame e convertido em um `InputCommand` por tick.

### `InputCommand`

Estrutura serializável por tick:
- `move: Vector2`, `sprint`, `jump`, `crouch`, `dodge`
- `hand_target: Vector3` (no espaço do ombro, dentro da esfera de alcance)
- `blade_roll: float`
- `tension: bool` (LMB), `free_hand_mode: bool` (RMB)
- `free_hand_target: Vector3`
- `thrust`, `kick`, `grip_toggle`, `throw`, `lock_on_toggle`
- `look_yaw_delta: float` (rotação resultante da mão ultrapassar a borda da esfera ou do mouse em lock-on)

## Lutador

### Estrutura

- **Esqueleto-alvo** (cinemático, invisível): executa locomoção procedural (passadas por IK) e fornece a pose desejada das pernas e postura base do tronco.
- **Corpo físico**: corpos rígidos Jolt por segmento — pelve, abdômen, peito, cabeça, braço/antebraço/mão ×2, coxa/canela/pé ×2 — conectados por juntas com limites anatômicos.
- **Músculos**: controladores PD por junta que aplicam torque em direção à pose alvo. Cada músculo tem `força_max`, `rigidez`, `amortecimento`. `força_max` é multiplicada pelo estado do membro (ferimento) e pela tensão.
- **Suporte da pelve**: mola do controlador de movimento até a pelve, que mantém o corpo firme. Sua força escala com o equilíbrio.

### Equilíbrio

- Barra de 0–100, regenera com o tempo quando o lutador não está sob impacto.
- Drenada por: impactos recebidos (proporcional à energia, maior para contusão), chute, perder a disputa de momentum num choque, parry sofrido, golpe pesado que erra (sobre-extensão), perna ferida.
- Em 0: mola da pelve desliga → tropeço ou queda em ragdoll total. Recupera e levanta após ~1 s (ajustável). Durante a queda o lutador está vulnerável.

### Vida por parte

- Partes: cabeça, tronco, braço E/D, perna E/D, cada uma com vida própria.
- Braço ferido: `força_max` e precisão do alvo da mão reduzidos proporcionalmente.
- Perna ferida: velocidade máxima reduzida, regeneração de equilíbrio reduzida.
- Membro com vida 0 + golpe de **corte** acima do limiar de desmembramento → membro é decepado (junta removida, segmento vira objeto solto). Braço da arma decepado → arma cai.
- Morte: cabeça ou tronco em 0.

### Stamina

- Gasta com: tensão (contínuo), estocada, chute, esquiva, corrida, parry.
- Sem stamina: tensão indisponível, esquiva indisponível, força muscular reduzida.

## Mão, arma e câmera

### Mão da arma

- O mouse move `hand_target` numa **esfera de alcance** à frente do ombro (raio = comprimento do braço).
- O braço é puxado pelos músculos até lá. A arma é presa à mão por uma **junta de pegada**; massa, comprimento e centro de massa produzem atraso, sobre-passagem e inércia naturalmente.
- Empurrar o alvo além da borda da esfera gera `look_yaw_delta` → gira corpo e câmera (permite golpes largos giratórios).
- **Tensão (LMB)**: músculos do braço/tronco a `força_max` elevada, maior energia de golpe, consome stamina. Manter tensão com a mão parada acumula **carga** (golpe carregado) até um teto.
- **Roda do mouse**: gira a arma no eixo longitudinal (alinha fio vs chapa).
- **F (estocada)**: impulso do alvo da mão ao longo do eixo da lâmina.
- **G (pegada)**: alterna 1 mão / 2 mãos / invertida. 2 mãos: segunda mão presa ao cabo, mais força e estabilidade, menor alcance e mão livre indisponível.
- **T (arremesso)**: solta a junta de pegada no pico de velocidade da mão; arma vira projétil físico. Recuperação: pegar do chão.

### Mão livre (RMB)

- Enquanto RMB estiver segurado, o mouse controla `free_hand_target`; a arma mantém a última posição.
- **Parry**: contato da mão livre com a **chapa/lateral** da lâmina inimiga com velocidade mínima, dentro de ~150 ms desde que o RMB foi pressionado → lâmina desviada, atacante perde equilíbrio. Contato com o **fio** ou fora da janela → dano no braço.
- **Agarrar**: contato da mão livre com pulso/antebraço inimigo + LMB → segura; puxar/torcer com o mouse pode forçar o inimigo a soltar a arma (**desarmar**), em disputa de força muscular.
- **Empurrar**: mão livre contra o tronco com velocidade → dreno de equilíbrio.

### Câmera

- **3ª pessoa**: sobre o ombro, colisão com cenário, afastamento automático para armas longas.
- **1ª pessoa**: na cabeça física, com estabilização (não segue todo solavanco do ragdoll).
- **V** alterna; **botão do meio** ativa lock-on (câmera e rotação do corpo orientadas ao alvo).

### Controles padrão (remapeáveis)

| Tecla | Ação |
|---|---|
| Mouse | Mão da arma (ou mão livre com RMB) |
| LMB | Tensão / carga / agarrar (com mão livre) |
| RMB | Modo mão livre |
| Roda | Girar fio |
| F | Estocada |
| X | Chute |
| G | Troca de pegada |
| T | Arremessar |
| WASD | Mover |
| Shift | Correr |
| Espaço | Pular |
| Ctrl | Agachar |
| C | Esquiva |
| Botão do meio | Lock-on |
| V | 1ª/3ª pessoa |

## Colisão e dano

### Colisão

- Armas com **colisão contínua** (qualidade de movimento `LinearCast` do Jolt). Critério: lâmina a 40 m/s não atravessa lâmina nem corpo.
- Cada arma define **zonas** por forma de colisão: `fio`, `chapa`, `ponta`, `guarda`, `cabo`, `cabeça`.
- Colisões arma↔cenário: obstáculo interrompe o golpe fisicamente (rebote) — o requisito "obstáculo trava golpe" é satisfeito pela física, sem regra especial.

### Energia do contato

```
v_rel   = velocidade relativa dos pontos de contato
m_ef    = massa efetiva do atacante no ponto (considera inércia rotacional: 1 / (1/m + (r×n)·I⁻¹(r×n)))
energia = 0.5 * m_ef * |v_rel|²
```

### Tipo do golpe

Determinado pela zona e pela geometria no contato:
- **Corte**: zona `fio` e ângulo entre `v_rel` e o plano da lâmina ≤ limiar. Dano alto em carne, pode desmembrar.
- **Perfuração**: zona `ponta` e `v_rel` alinhado ao eixo da lâmina. Energia concentrada; multiplicador alto em cabeça/tronco.
- **Contusão**: `chapa`, `cabeça`, `cabo`, `guarda`, ou `fio` fora do ângulo de corte. Dano menor, dreno de equilíbrio alto.

### Dano

```
se energia < limiar_raspão: sem dano
dano = (energia - limiar_raspão) * mult_tipo * mult_parte * mult_arma
```
Todos os multiplicadores e limiares são dados ajustáveis (painel de ajuste).

### Evento `Clash`

Emitido em todo contato arma↔arma (e arma↔mão livre):
`{ tick, energia, ângulo, pontos, arma_a, zona_a, arma_b, zona_b, lutador_a, lutador_b }`

- Resolução física (rebote) é do Jolt.
- Disputa de momentum: o lado com menor momentum no contato tem o alvo da mão empurrado e perde equilíbrio proporcional à diferença.
- Consumidores no SP1: faísca, tremor de câmera, hit stop simples (escala de tempo local; no SP2 passa a ser só visual). Nos SPs futuros: fratura, áudio, estilo.

## Treino

- **Boneco**: fixo (opcionalmente com arma parada em guarda), mostra dano, tipo e energia por parte.
- **Bot**: gera `InputCommand` com padrões de ataque (cortes horizontais/verticais, estocadas) e defesa (bloqueio, parry com probabilidade), dificuldade ajustável (tempo de reação, precisão).
- **Espelho**: grava a sequência de `InputCommand` do jogador e a reproduz num bot.

## Ferramentas de ajuste

- Painel em jogo (tecla F1) para editar ao vivo: massas, força/rigidez/amortecimento de músculos, limiares de dano e raspão, multiplicadores, janela de parry, custos de stamina, parâmetros de equilíbrio.
- Salvar/carregar perfis de ajuste (`.tres`).
- Câmera lenta (0.1×–1×), vetores de força e velocidade, números de energia e tipo em cada contato.

## Assets (gerados no Blender headless)

Scripts em `tools/blender/`, saída em `assets/generated/` (nunca editada à mão; regenerável por comando).

- **Manequim segmentado** (estilo boneco de teste): uma malha por segmento do corpo, com o mesmo esqueleto que o sub-projeto 5 usará para corpos customizados.
- **Espada longa**: ~1,4 kg, ~1,1 m, centro de massa ~10 cm à frente da guarda; zonas de colisão por forma.
- **Marreta**: ~5 kg, ~0,9 m, massa concentrada na cabeça.
- **Arena cinza**: chão com grade de 1 m, parede, pilar, degrau.

Massa e inércia vêm dos dados da arma (não da malha), para ajuste independente.

## Estrutura de pastas

```
joguinho/
  project.godot
  src/
    sim/
      fighter/    corpo, músculos, equilíbrio, vida, stamina
      weapon/     dados da arma, zonas, pegada
      combat/     contato → energia → dano, eventos
      input/      InputCommand
    view/         câmera, efeitos, HUD, debug
    bot/          boneco, bot, espelho
  tools/blender/
  assets/generated/
  tests/
  docs/superpowers/specs/
```

Regra: nada em `src/sim/` referencia `src/view/`.

## Testes

Framework: GUT.

- **Unidade**: massa efetiva e energia; classificação corte/perfuração/contusão; cálculo de dano e limiar de raspão; vida por parte e desmembramento; equilíbrio (dreno, queda, recuperação); stamina.
- **Cenários headless** (simulação real, sem renderização):
  - Lâmina a 40 m/s não atravessa lâmina nem corpo.
  - Com o mesmo comando de mão, a marreta leva mensuravelmente mais tempo que a espada para atingir sua velocidade de pico.
  - Estocada na cabeça do boneco é classificada como perfuração.
  - Golpe com chapa é contusão e drena mais equilíbrio que corte de mesma energia.
  - Obstáculo entre lutador e alvo impede o acerto.
  - Parry dentro da janela desvia; fora da janela fere o braço.
- **Desempenho**: 8 lutadores simulados headless cabem em 8,3 ms por tick no i5-14400.

## Critérios de pronto

1. 60 FPS no preset baixo na Intel UHD 730 com 2 lutadores em cena.
2. Todos os testes passam.
3. O usuário joga e aprova a sensação de peso, choque e parry.

## Riscos

- **Sensação do controle de mão**: é o maior risco. Mitigação: painel de ajuste ao vivo e iteração com o usuário desde a primeira versão jogável.
- **Estabilidade do ragdoll ativo** (tremores, explosões de junta): mitigação com limites de torque, amortecimento e testes de cenário.
- **Desempenho na GPU integrada**: arena cinza e manequim simples no SP1 mantêm custo baixo.
