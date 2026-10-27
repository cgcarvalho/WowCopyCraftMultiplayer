# Autoataque de Charger

`Charger Auto Attack.png` é um atlas RGBA original de oito poses de golpe de
martelo, gerado a partir dos sprites existentes `Charger Idle.png` e
`Charger Cast.png`. Mantém a armadura, o escudo solar, o cabelo ruivo e o estilo
renderizado do personagem. Não depende de serviços externos em execução.

- Imagem: 1774 × 887, quatro colunas e duas linhas, ordem por linha.
- Limites das células arredondados para pixels inteiros em `Charger.tscn`.
- Regiões `AtlasTexture` com margens alinham os pés entre os oito quadros.
- A escala local de 1,2 durante `auto_attack` aproxima a altura de 364 pixels
  do personagem em idle. Trocar para outra animação restaura a escala 1.
- Preparação nos quadros 1–2, impacto no quadro 3, sequência de recuperação
  nos quadros 4–8. O terceiro quadro coincide com o pedido de ataque a 35%
  do ciclo. O ciclo mantém o intervalo de autoataque de 1,1 segundo.
- A animação de conjuração original permanece separada. Espelhamento e o
  nome da animação usam a sincronização existente do personagem.
