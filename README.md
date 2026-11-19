# SHIN: A Lenda do Samurai das Sombras

Jogo 3D de ação e aventura em terceira pessoa, feito em **Godot 4 (GDScript)**, para **Windows e Android**.

Shin Kurogane, último guerreiro do clã Kurogane, desperta numa floresta de bambu depois que o exército de
**Lorde Akuma** arrasou sua aldeia sob a Lua Sangrenta. Ele precisa recuperar a espada lendária **Tsukikage**
antes de Akuma e encerrar a guerra num duelo final no castelo.

---

## Como executar

1. Instale o **Godot 4.3** (ou mais recente da série 4.x), versão padrão (não-.NET): <https://godotengine.org/download>
2. Abra o Godot → **Importar** → selecione o arquivo `project.godot` desta pasta.
3. Pressione **F5** (Executar projeto).

Na primeira abertura o Godot importa os áudios (`assets/audio`), o que leva alguns segundos.

### Atalhos de teste (opcional)
Para começar direto em uma fase, execute pela linha de comando:

```bash
godot --path . -- --level=3            # Fase 3
godot --path . -- --level=5 --stage=3  # Fase 5, direto no chefe final
```

---

## Exportar

### Windows
1. No Godot: **Editor → Gerenciar Modelos de Exportação → Baixar e instalar**.
2. **Projeto → Exportar…** → preset **Windows Desktop** → **Exportar Projeto** (gera `build/windows/SHIN.exe`).

### Android
1. Instale os modelos de exportação (como acima), o **Android SDK** e um **JDK 17**.
2. Em **Editor → Configurações do Editor → Exportar → Android**, informe o caminho do SDK e do keystore de debug
   (o Godot pode gerar um automaticamente).
3. **Projeto → Exportar…** → preset **Android** → **Exportar Projeto** (gera `build/android/SHIN.apk`, arm64).

O jogo usa o renderizador **Compatibilidade (OpenGL ES 3 / WebGL2)**, que funciona na maioria dos celulares
Android e em PCs modestos. A orientação no celular é horizontal (paisagem com sensor).

---

## Controles

| Ação | Computador | Celular |
|---|---|---|
| Mover (8 direções) | W A S D | Joystick virtual (esquerda) |
| Câmera | Mouse (roda: zoom) | Arrastar na metade direita |
| Correr | Shift | Joystick até o fim |
| Ataque leve (combo ×3) | Clique esquerdo | Botão ATAQUE |
| Ataque pesado | Segurar clique esquerdo | Segurar ATAQUE |
| Defender | Clique direito (segurar) | Botão DEFESA (segurar) |
| Aparar | F | Botão APARAR |
| Esquivar / saltar | Espaço | Botão ESQUIVA |
| Habilidade especial | Q | Botão ESPECIAL |
| Interagir | E | Botão ✋ |
| Pausar | Esc | Botão ❚❚ (topo) / Voltar |

Controle (gamepad) também é suportado: analógicos, X ataque, RB defesa, LB aparar, A esquiva, Y especial,
B interagir, Start pausa.

**Dicas de combate:** apertar F (ou começar a defender) no instante exato do golpe **apara** o ataque e deixa o
inimigo atordoado. O brilho na lâmina inimiga avisa que um ataque vem aí. Círculos vermelhos no chão indicam ataques
que não podem ser defendidos — saia deles ou esquive no momento do impacto (a esquiva tem invulnerabilidade).

---

## Campanha (45–60 min para um iniciante)

| Fase | Duração | Tipo | Conteúdo |
|---|---|---|---|
| 1 — O Despertar da Floresta | 8–10 min | Tutorial | Movimento, corrida, saltos com esquiva, bonecos de treino, defesa e aparar, 3 soldados, primeiro pergaminho |
| 2 — A Aldeia Esquecida | 8–12 min | Combate | Aldeia em chamas, patrulhas, emboscada com arqueiros (torre de vigia), samurai de elite, resgate do ancião Genzo |
| 3 — O Templo das Sombras | 10–12 min | Exploração | Floresta noturna, corredor de espinhos e flechas, ponte com lâminas pendulares, escadaria, Kuroha (elite), espada Tsukikage (desbloqueia o especial) |
| 4 — O Caminho da Lua Vermelha | 8–12 min | Desafio | Trilha de cerejeiras, arena com 3 ondas (guerreiros, arqueiros, elites), miniboss **General Raiga** |
| 5 — O Último Duelo | 10–14 min | Chefe final | Pátio do castelo, arqueiros nas muralhas, **Lorde Akuma** em duas etapas, amanhecer e final |

Cada fase tem objetivos claros (painel no canto superior direito + feixe de luz indicando o destino), diálogos curtos,
câmera cinematográfica de abertura, letterbox nas cenas e **santuários de salvamento** (lanternas de pedra que
acendem ao se aproximar). Ao morrer, você volta ao último santuário; a opção **Continuar** do menu retoma o progresso.

---

## Sistemas implementados

- **Jogador** (`scripts/player/player.gd`): movimento relativo à câmera em 8 direções, caminhada/corrida,
  combo leve de 3 golpes, golpe pesado (quebra guarda), defesa com custo de resistência e quebra de guarda,
  **aparar com janela de precisão** (0,24 s; defender no instante exato também apara), esquiva com salto e
  invulnerabilidade, dano/atordoamento/morte, vida + resistência + **Ki**, habilidade especial
  **Corte da Lua Crescente** (giro em área + onda cortante), mira assistida leve, *hit-stop* e tremor de câmera.
- **Câmera** em terceira pessoa com `SpringArm3D` (não atravessa paredes), mouse/touch/analógico e tomadas cinematográficas.
- **Animações** (`scripts/player/character_model.gd`): modelo humanoide procedural com poses-chave interpoladas —
  descanso, andar, correr, 3 ataques, pesado, defesa, aparar, esquiva, dano, atordoado, morte, especial, arco, etc.
- **IA** (`scripts/enemies/enemy.gd`): soldados, samurais de elite e arqueiros com patrulha, detecção por
  distância + campo de visão + linha de visada, alerta aos aliados, perseguição limitada a uma área (*leash*),
  retorno à patrulha ao perder o jogador, circulação em volta do jogador, limite de atacantes simultâneos,
  defesa ocasional, reação a golpes (postura/*poise*), atordoamento ao serem aparados; arqueiros mantêm distância
  e disparam flechas com antecipação.
- **Chefes** (`scripts/enemies/boss.gd`): General Raiga (combos, investida, golpe sísmico, fúria a 50%) e
  Lorde Akuma (2 etapas: combos, investida, ondas de sangue; na 2ª etapa teleporte às costas, pilares da Lua
  Sangrenta, aura e céu que muda).
- **Armadilhas**: espinhos cíclicos com aviso, lâminas pendulares, torres de flechas.
- **Interface**: menu inicial (com Shin em 3D), HUD (vida, resistência, Ki, objetivo, chefe), pausa com lista de
  controles, configurações (volumes, sensibilidade, inverter Y, qualidade, touch, tela cheia, FPS), vitória e derrota,
  controles touchscreen desenhados em tela.
- **Áudio**: música japonesa original (taiko, shakuhachi, koto, shamisen) que alterna entre exploração, combate e
  chefe; ambientes (vento, fogo, grilos); efeitos de espada, passos, impactos, flechas, gongo.
- **Efeitos**: partículas de folhas, pétalas, brasas, vagalumes e cinzas; faíscas, poeira, rastros de corte,
  ondas de choque, avisos no chão; fogo com luz tremulante; neblina e iluminação dinâmica por fase.
- **Otimização**: renderizador de compatibilidade, vegetação e objetos repetidos em `MultiMesh`, três níveis de
  qualidade (sombras, luzes extras, partículas, resolução 3D), materiais e malhas compartilhados.

---

## Estrutura do projeto

```
project.godot            configuração (renderizador, janela, autoloads, camadas)
export_presets.cfg       presets de exportação Windows e Android
scenes/main.tscn         cena principal
scripts/
  autoload/game.gd       estado global, mapeamento de controles, configurações, salvamento
  autoload/audio.gd      música com crossfade, ambientes e efeitos 2D/3D
  core/main.gd           fluxo menu ⇄ fases, pausa, vitória/derrota, fades
  player/                jogador, câmera e modelo/animação procedural
  enemies/               IA dos inimigos, projéteis, orbes de cura e chefes
  levels/                base das fases (etapas, salvamento, diálogos) e as 5 fases
  world/props.gd         construção procedural de cenários, céu e materiais
  world/objects.gd       bonecos de treino, santuários, armadilhas, interações
  fx/fx.gd               efeitos visuais
  ui/                    HUD, menus, configurações, controles touch
assets/audio/            áudio gerado por tools/gen_audio.py
tools/gen_audio.py       sintetizador do áudio (Python + numpy)
tools/tests/             bot de teste automatizado e cenas de verificação
docs/CREDITOS.md         origem e licença de todos os recursos
```

Todo o conteúdo visual (personagens, armaduras, armas, casas, templo, castelo, vegetação) é **gerado por código**
a partir de primitivas do Godot — não há modelos, texturas ou animações externas. Veja `docs/CREDITOS.md`.

---

## Testes automatizados

O bot em `tools/tests/autotest.gd` joga a campanha inteira sozinho (avança diálogos, vai aos objetivos,
combate inimigos e chefes) e imprime cada etapa concluída:

```bash
godot --headless --path . -- --level=1 --autotest
```

`tools/tests/combat_probe.gd` verifica a IA em combate real (`-- --level=1 --stage=4 --probe=idle` ou `--probe=block`).

Para regenerar o áudio: `python3 tools/gen_audio.py`.
