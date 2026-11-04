# Animações das magias de Jefferson

A sequência original foi gerada no **Ludo.ai**, modelo **Forge**, em 2026-11-04.
É um vórtice violeta isolado que pulsa, lança raios e se dissipa, sem personagem.

- Referência: https://storage.googleapis.com/ludo-assets/677665b33b9061ffcf43284e603ed0d9.webp
- Vídeo original: https://storage.googleapis.com/ludo-assets/7ba51e8ee6fb6635f7fddf5105a546f1.mp4
- SHA-256 do MP4: `d02f8355280d8ce2e668039e91b14bc9be6a3731239ba4bff98cf26289f93b04`
- Exportação real: **36 quadros de 640 × 640, 2,75 segundos**.

Prompt de movimento:

> Small central glow expands into circular purple magic burst then dissipates
> to black over 2 seconds. Fixed camera, no character appears at any frame.
> Violet purple energy vortex pulsing with luminous tendrils radiating outward
> and fading.

O MP4 exportado tinha um quadriculado cinza incorporado, apesar do pedido de
fundo preto. `build_atlas.py` reconstrói esse fundo fixo a partir das bordas do
primeiro quadro e recupera a transparência da energia. O centro escuro também
fica transparente, evitando que escudos e portais escondam o personagem.
O redimensionamento usa alfa pré-multiplicado e margem transparente de 8 pixels
por célula para impedir contaminação entre quadros.

`LudoSpells.tres` substitui o atlas antigo de quatro quadros:

| Clipe | Quadros | Uso |
| --- | ---: | --- |
| `charge` | 56 | Primeiros 8 quadros em ida e volta, repetidos 4 vezes durante a preparação |
| `eruption` | 36 | Sequência completa, tocada uma vez no impacto |
| `orb` | 14 | Primeiros 8 quadros em ida e volta para manter a energia do projétil |
| `lance` | 36 | Sequência completa com paleta azul/ciano e proporção horizontal |
| `sigil` | 14 | Mesma sequência pulsante para portais, escudo e mecanismos cooperativos |

`Vortex.png` contém 6 × 6 células de 256 × 256. `ArcaneLance.png` contém
6 × 6 células de 512 × 96; é uma derivação do mesmo vídeo, com troca dos canais
de cor e proporção horizontal. **Não são cinco gerações independentes**:
a sequência do Ludo é reutilizada e adaptada pelo jogo para as oito habilidades.
As rotações, expansões, contrações e dissipações são controladas no Godot.
A animação corporal existente recebe antecipação e recuo; não foi gerado um
novo ciclo de poses do corpo.

A preparação e o impacto usam o tempo restante replicado pelo servidor, sem
reiniciar a sequência para quem entra durante uma conjuração. Orbes usam a
idade replicada do projétil; portais e escudos pulsantes usam um relógio visual
local. Marcas do Caos e Cataclismo guardam as posições reais do impacto.
Uma interrupção contrai e dissipa o sigilo sem produzir a explosão.
Os sprites não alteram dano, alcance, colisão ou duração das habilidades.
Os contornos e textos dos avisos permanecem separados dos efeitos.

Os PNGs e o recurso SpriteFrames estão incluídos: o jogo funciona sem acesso
à internet, ao Ludo ou às ferramentas de conversão.

Para reconstruir os atlas, baixe o MP4 acima, extraia os quadros e rode
`build_atlas.py` com Python 3, Pillow e numpy:

```sh
ffmpeg -i jefferson-vortex.mp4 -fps_mode passthrough frames/%03d.png
python3 Art/Skills/Jefferson/build_atlas.py frames
```
