# Sprites das magias de Jefferson

`SpellAtlas.png` é uma arte original gerada para este projeto com fundo transparente.
É um atlas de quatro colunas e quatro linhas, com quatro quadros por efeito:

1. Orbe violeta, apontando para a direita.
2. Lança elétrica azul, apontando para a direita.
3. Erupção rúnica no solo.
4. Anel rúnico para escudo e portais.

`Scenes/Skills/Jefferson/SpellVisual.gd` calcula o tamanho das células a partir da
textura e anima as colunas a 10 quadros por segundo. A orientação do tiro é aplicada
na renderização; não há necessidade de versões da textura para cada direção.
Os sprites têm função visual; as regras de dano usam geometria no servidor.
