# Inimigos menores e ícones de maestria

Arte e animações criadas no **Ludo.ai**, no Image Generator e no Sprite Generator,
para a implementação de maestrias e ondas em novembro de 2026. Os três conceitos
usaram direção lateral, fundo transparente, proporção compatível com os heróis
e silhuetas distintas: conjurador de manto com magia violeta, guerreiro pesado
com escudo rúnico e sabueso arcano quadrúpede.

Cada personagem tem referência própria. As sequências de movimento, ação,
reação e morte foram geradas a partir da mesma referência do personagem;
o Guarda também recebeu uma sequência específica de proteção. Não se trata
de reutilizar a animação dos heróis ou mudar apenas a cor de Jefferson.

## Recursos finais

- `acolyte_idle`, `acolyte_walk`, `acolyte_action`, `acolyte_hit`, `acolyte_death`.
- `guard_idle`, `guard_walk`, `guard_action`, `guard_protect`, `guard_hit`, `guard_death`.
- `hound_idle`, `hound_walk`, `hound_action`, `hound_hit`, `hound_death`.
- `MasteryIcons.webp`: dez ícones em duas colunas e cinco linhas, nesta ordem:
  Contágio Sombrio / Eco Voraz; Tempestade de Arrasto / Guarda Compartilhada;
  Luz em Cadeia / Piso Protetor; Infecção Residual / Linha Perfurante;
  Rebite Condutor / Circuito de Amparo.
- `EnemyClips.tres`: SpriteFrames compartilhado com todas as 16 sequências.

## Exportação e preparação

Os originais foram baixados pelo **Download All** do Sprite Generator em PNG
com transparência, nos arquivos `ludo-sprites (5).zip`, `(6).zip` e `(7).zip`.
As folhas originais tinham 36 quadros, exceto avanço do Sabueso (20), reação do
Guarda (35) e reação do Acólito (25). As exportações também incluíam referências,
variantes dos ícones e recursos antigos; apenas os novos recursos desta entrega
foram incorporados ao projeto.

As folhas finais preservam 12 amostras igualmente espaçadas por sequência e
16 por morte. Os atlas WebP têm quatro colunas, células transparentes de
320 × 256 e recorte explícito por AtlasTexture. A preparação preserva a âncora
do primeiro quadro durante toda a sequência e normaliza a altura de referência
para 127 (Acólito), 125 (Guarda) e 79 unidades (Sabueso), com apoio dos pés em
Y=234 da célula. As bordas externas dos quadros exportados recebem transição
curta de transparência para suavizar efeitos que saem do enquadramento original.

Parado e caminhada repetem a 12 quadros/s; ação, proteção, reação e morte tocam
uma vez. A morte dura 0,8 segundo e a reação 0,25 segundo. As poses de ação
e proteção são calculadas pelo tempo replicado de preparação e recuperação;
quem entra durante o aviso já vê a pose correspondente ao seu progresso.
A lógica de dano, os contornos dos perigos e a área de seleção usam
coordenadas do jogo, independentes da extensão da ilustração.

As maestrias reutilizam os efeitos de combate existentes quando apropriado
(elos, cura, escudo, flechas e rebites), mantendo a autoria visual e a leitura
dos avisos de perigo. Os ícones novos usam o atlas próprio descrito acima.
