# Referência do guerreiro de duas armas

Personagem inspirado na foto enviada pelo usuário em 25 de novembro de 2026.
O nome escolhido pelo usuário é **Tiagolas, Lâminas Gêmeas**.

`Reference.png` foi criada com a ferramenta de geração de imagens integrada,
usando a foto como referência de aparência e `Art/Chars/Teo/Idle.png` como
referência do estilo do jogo. O resultado mantém cabelo curto escuro, sorriso,
estrutura do rosto e braços fortes, com armadura sem mangas e uma espada em
cada mão. A fotografia original não faz parte do repositório.

Prompt de referência: criar um guerreiro de duas espadas em corpo inteiro,
centralizado sobre fundo transparente, com margens em torno dos pés e das
lâminas; preservar os traços e o sorriso do homem em primeiro plano da foto;
usar contorno escuro e pintura estilizada de fantasia, couraça azul-acinzentada,
couro marrom, duas espadas de aço, sem elmo, escudo, capa, cenário ou texto.

`Portrait.webp` enquadra o rosto em 192 × 192 para a máscara circular do HUD.
`Idle.png` normaliza o corpo para 260 de altura numa célula de 384 × 384.

## Animações e ícones finais — Ludo.ai

As nove sequências foram geradas no Sprite Generator do **Ludo.ai**, com o
modelo **Hydra**, duração de três segundos e a mesma `Reference.png`:
espera (`idle`), caminhada (`walk`), dois golpes alternados (`auto_attack`),
corte cruzado (`cross`), investida (`dash`), guarda (`guard`), giro da ultimate
(`spin`), reação ao acerto (`hit`) e morte (`death`). Os prompts preservam as
duas espadas, o rosto sorridente, a armadura, o enquadramento e o apoio dos pés.
Espera, caminhada e giro pedem continuidade; reação e morte pedem uma ação única.

O pacote exportado em 25/11/2026 foi
`tiagolas-laminas-gemeas-spritesheets.zip` (Smooth Art, células de 615 × 456).
As fontes `WCC-DUAL-AUTO-A-flu`, `WCC-DUAL-CROSS-One-` e
`WCC-DUAL-DASH-A-sho` têm 30 quadros; `WCC-DUAL-HIT-One-br`, 25;
`WCC-DUAL-IDLE-Subtl`, `WCC-DUAL-WALK-A-sea`, `WCC-DUAL-GUARD-One-`,
`WCC-DUAL-SPIN-A-sea` e `WCC-DUAL-DEATH-One-`, 36.

Os atlas WebP finais usam células transparentes de 384 × 384, quatro colunas,
18 quadros por ação (12 para `hit`). A escala de cada sequência usa o corpo do
primeiro quadro com 260 de altura, centro X = 192 e pés Y = 310; a âncora é
mantida nos demais quadros para preservar o movimento. Uma suavização de borda
reduz cortes bruscos nos efeitos das lâminas. `Animations.tres` reproduz
espera em 3 s, caminhada e ataque em 1 s, habilidades em 0,55 s, giro e morte
em 0,8 s e reação em 0,25 s. Apenas espera, caminhada, ataque e giro repetem.
`cast` reaproveita o corte cruzado para compatibilidade com o personagem-base.

Os seis ícones também foram criados no **Ludo.ai**, Image Generator,
UI Element. `SkillIcons.webp` tem 512 × 768, em duas colunas e três linhas:
Corte Cruzado / Passo de Aço, Guarda de Lâminas / Dança das Lâminas,
Frenesi Cruzado / Guarda Vingativa. As skills e maestrias usam recortes de
256 × 256 desse atlas, sem reutilizar ícones de outras classes.
