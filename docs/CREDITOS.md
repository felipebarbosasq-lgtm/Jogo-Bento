# Créditos e origem dos recursos

O projeto **não utiliza nenhum recurso pago nem de terceiros** além da própria engine.

| Recurso | Origem | Licença |
|---|---|---|
| Engine | [Godot Engine 4.3](https://godotengine.org) | MIT |
| Código (GDScript) | Escrito para este projeto (`scripts/`) | Do projeto |
| Personagens (Shin, soldados, elites, arqueiros, General Raiga, Lorde Akuma, ancião Genzo) | Montados em código a partir de primitivas (caixas, cilindros, esferas, prismas) em `scripts/player/character_model.gd` | Do projeto |
| Animações | Procedurais: poses-chave interpoladas em código (`character_model.gd`) | Do projeto |
| Cenários (bambuzal, aldeia, templo, ponte, montanhas, cerejeiras, castelo) | Gerados em código (`scripts/world/props.gd` e `scripts/levels/`) | Do projeto |
| Céu | Shader de céu procedural (lua, estrelas, nuvens) em `props.gd` | Do projeto |
| Efeitos visuais | Partículas e malhas procedurais (`scripts/fx/fx.gd`) | Do projeto |
| Música (menu, exploração, combate, chefe, vitória, derrota) | Sintetizada por `tools/gen_audio.py` (taiko, flauta estilo shakuhachi, koto, shamisen — escalas japonesas *in* e *yo*) | Do projeto |
| Efeitos sonoros e ambientes | Sintetizados por `tools/gen_audio.py` (ruído filtrado, osciladores, envelopes) | Do projeto |
| Fonte | Fonte padrão embutida no Godot | MIT (Godot) |
| Ícone | `icon.svg`, desenhado para o projeto | Do projeto |

A imagem de referência do samurai fornecida orientou a identidade visual do protagonista: cabelo preto
despenteado, armadura japonesa preta com cordões vermelhos, faixa (obi) vermelha, emblema circular no peito,
katana e wakizashi na cintura.
