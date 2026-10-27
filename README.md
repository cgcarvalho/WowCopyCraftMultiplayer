# World of Copycraft Multiplayer

Protótipo multiplayer em Godot 4.4 (GDScript / Forward Plus).

## Executar

1. Abra `project.godot` no Godot 4.4 e aguarde a importação dos recursos.
2. Execute o projeto (F6 executa uma cena; use F5 para executar o projeto).
3. Em uma instância, escolha **Host Game**, selecione o personagem e marque **Estou pronto** no lobby.
4. Na outra instância, informe o IP ou hostname do host e escolha **Join Game**.
   Para testar na mesma máquina, use `127.0.0.1`. Selecione a classe e marque **Estou pronto**.
5. O host escolhe **Iniciar encontro** quando todos estiverem prontos; a luta começa após uma contagem de 3 segundos. É possível jogar solo usando o mesmo fluxo.

A conexão usa ENet/UDP na porta **8080**, com até quatro jogadores incluindo
   o host. Para jogar em LAN, permita essa porta no firewall do host.

Movimento: WASD. Alvo: clique esquerdo. Ataque básico: botão direito.
Habilidades: **1 / 2 / 3**; ultimate: **R ou 4**. Cura sem aliado selecionado usa o próprio personagem; Alt + cura força autocura.
**Arrow Rain:** pressione R/4 ou clique no ícone, mire com o mouse e confirme com clique esquerdo; Esc ou botão direito cancela sem gastar recurso. Consecration sempre consagra o chão sob o paladino.
**Tab:** seleciona o inimigo mais próximo. **F:** interrompe Cataclismo Arcano (16s de recarga, alcance 200 para Warrior e 650 para as demais classes).

## Validação

```sh
godot --headless --editor --path . --import
godot --headless --path . res://tests/regression.tscn
```

O teste usa o peer offline do Godot para verificar escudo, validação de
habilidades, cooldown, renovação de debuffs, alvo ausente e limpeza de jogadores.
Não substitui testes entre processos.

Antes de integrar alterações multiplayer, teste com duas instâncias: conexão,
seleção de personagens, movimento, dano/cura/escudo visíveis nas duas janelas,
entrada tardia de um terceiro jogador, desconexão e reutilização da vaga.
Teste também um endereço indisponível e uma porta já ocupada.

O servidor valida a identidade de quem lança, o conjunto de habilidades,
recurso da classe, cooldown, alcance e tempo de conjuração, e replica os atributos de combate.
O movimento continua sob autoridade do cliente; não há proteção completa
contra adulteração de posição. Novas tentativas restauram os personagens sem encerrar a conexão; não há ressurreição individual durante uma luta.

## Jefferson, o Arcanista

O encontro começa depois que todos confirmam a classe e o estado Pronto, e o host inicia. Jefferson
agora tem **480 HP** e uma presença visual maior, com flutuação, sombra e
interpolação visual da movimentação.

O servidor escolhe alvos combinando proximidade e ameaça causada por dano.
Uma pequena janela de compromisso com o alvo evita trocas constantes. Jefferson
acelera e desacelera, recua de jogadores próximos, circula na distância de
conjuração, contorna as duas árvores do mapa e evita áreas ofensivas dos jogadores.
O movimento fica limitado à arena. O desenho das árvores é específico deste mapa;
outros mapas precisarão fornecer seus próprios obstáculos.

### Magias

| Magia | Aviso | Efeito |
| --- | --- | --- |
| Ruptura Sombria | Círculo fixo por 2 s | 25 de dano em raio de 115; prioriza grupos próximos. |
| Orbes do Vazio | Direções em leque por 1 s | Três projéteis esquiváveis, 12 de dano cada; cinco na fase 2. |
| Lança Arcana | Faixa azul por 1,6 s | 22 de dano na linha; a mira não acompanha o jogador após o aviso. |
| Passo Astral | Portais de origem e destino por 1,1 s | Reposicionamento para longe de jogadores próximos, sem dano. |
| Égide Rúnica | Runas por 1,3 s | Escudo de 50, usado uma vez na transição de fase. |
| Vínculo Astral | Círculo dourado acompanha o marcado por 3 s | 48 de dano dividido entre jogadores dentro de raio 130. Agrupe-se. |
| Marcas do Caos | Círculos vermelhos acompanham jogadores por 3 s | Cada marca causa 18 em raio 95; sobreposição multiplica os impactos. Afaste-se. |
| Cataclismo Arcano | Canalização de 4 s na fase 2 | 42 em todo o grupo, evitado com interrupção F. |

A primeira fase tem 6 s de recuperação entre conjurações, além de seus avisos.
Abaixo ou exatamente em **50% da vida**, a fase 2 acelera o movimento, reduz a
recuperação para 4,2 s e amplia a salva de orbes. Há cooldowns individuais para
evitar repetir a mesma magia e impedir teleporte contínuo. O ataque corpo a corpo
continua causando 8 de dano com intervalo de 1,6 s.

O círculo, a linha e a direção dos tiros são definidos antes do impacto. A previsão
usada nos orbes é limitada a 90 unidades e fica travada no começo do aviso.
O dano considera o ponto central do personagem, não toda a extensão da imagem.
Projéteis usam teste de segmento entre frames para não atravessar alvos quando
um frame demora mais. O servidor controla todo o dano; clientes animam os sprites.

Clique no boss para selecioná-lo. Cura e escudo são para aliados; habilidades de
dano e ataques básicos podem atingi-lo. Áreas dos jogadores não causam dano aliado.
A luta termina com vitória ao zerar a vida do boss ou derrota quando não há
jogadores vivos. O encerramento cancela avisos, tiros e habilidades pendentes.
Após derrota, **Tentar novamente** restaura o grupo, os recursos e os cooldowns. Após vitória, cada participante escolhe uma melhoria e o host pode continuar. **Voltar à seleção** reinicia a expedição sem reconectar. Não há equipamentos ou ressurreição individual durante o combate.

Os efeitos usam um atlas original animado em `Art/Skills/Jefferson/SpellAtlas.png`.
Os estados da magia, mira, fase, efeitos de impacto e tiros ativos são replicados,
inclusive para quem entra no meio da luta. Clientes não escolhem magias nem dano.

### Testes

```sh
godot --headless --path . res://tests/boss_fight.tscn
godot --headless --path . res://tests/jefferson_tactics.tscn
```

Para testar replicação ENet, execute em dois terminais (porta UDP 18081):

```sh
# Terminal 1
godot --headless --path . res://tests/boss_network.tscn -- --server
# Terminal 2, após aparecer NETWORK_SERVER_READY
godot --headless --path . res://tests/boss_network.tscn -- --client
```

Os processos devem exibir `NETWORK_CLIENT_PASS` e `NETWORK_SERVER_PASS`.
O teste cobre entrada tardia, vida/posição, fase, tipo de magia, mira travada,
projéteis ativos, direção/movimento do boss, remetente adulterado, habilidade do
cliente, vitória e desconexão. O teste de táticas cobre aceleração, distância,
ameaça, árvores, limites, colisão dos orbes, esquiva da lança, escape, escudo e fase.

## Menu e leitura dos efeitos

O menu inicial reúne fundo, botões Host Game / Join Game, endereço e mensagens
na cena `Scenes/Components/MainScreen/MainScreen.tscn`. Containers centralizam o
painel e mantêm margens ao redimensionar a janela, sem posicionamento por script.
O fundo preserva sua proporção e o vídeo para durante a partida. É possível
usar Tab para navegar e Enter no endereço para entrar na partida. O projeto usa
uma referência de 1152 × 648 com ajuste de canvas para outras proporções de janela.

DoTs usam ícones acima do personagem e uma lista detalhada no alvo selecionado.
Os números mostram **tempo restante**, com destaque nos últimos 3 segundos.
Aplicações iguais são agrupadas com indicação de quantidade; a duração exibida
é a maior restante entre elas. A barra acompanha a expiração e os indicadores
somem ao remover o último efeito. Os sprites no mundo têm menor opacidade para
preservar a leitura do personagem e dos avisos de magia.

Os números de dano mantêm o tamanho durante a animação, têm contorno escuro e
separam impactos próximos. Dano periódico usa roxo; cura usa verde. Esses eventos
visuais são enviados pelo servidor também aos clientes multiplayer.

Teste adicional de duração, agrupamento, renovação, remoção e feedback dos DoTs:

```sh
godot --headless --path . res://tests/dot_presentation.tscn
```


## Classes e ultimates

Cada classe tem três habilidades e uma ultimate. A seleção mostra classe,
papel e repertório. Os valores são um primeiro ajuste de balanceamento para o protótipo.

| Personagem | Classe | Habilidade 1 | Habilidade 2 | Habilidade 3 | Ultimate (R / 4) |
| --- | --- | --- | --- | --- | --- |
| Aurora | Warlock | Shadow Bolt (4s) | Corruption (2s) | Curse of Death (2s) | Soul Reap (60s): 45 + 12 por DoT próprio no alvo, em área |
| Sir Gura | Warrior | Charge (10s): avanço e 16 de dano | Cleave (5s): 24 em área corpo a corpo | Second Wind (18s): cura 30 e proteção 15 | Bladestorm (60s): 12 de dano/s por 6s, acompanha o guerreiro |
| Charger | Paladin | Holy Light (8s): cura 32, conjuração 1,2s | Judgement (6s): 24 de dano sagrado | Consecration (16s): 8s no chão, 7 de dano/s e 3 de cura/s | Divine Dawn (65s): cura 40, proteção 35 e 35 de dano aos inimigos próximos |
| Lulu | Hunter | Aimed Shot (6s): 32 de dano, conjuração 1s | Poison Arrow (10s): 8 inicial + 4/s por 8s | Multi-Shot (9s): até 3 flechas de 18 | Arrow Rain (60s): área fixa, 12 de dano/s por 7s |

Sir Gura tem 150 HP e autoataque corpo a corpo de 10 a cada 0,9s. Charger tem
130 HP e golpe de 8 a cada 1,1s. Lulu tem 100 HP e flechas de 8 a cada 1,15s;
o dano acontece na chegada da flecha. Aurora tem 100 HP e projéteis sombrios de
6 a cada 1,3s.

O autoataque corpo a corpo de **Sir Gura e Charger** tem alcance de **160 unidades**,
medido entre os centros dos personagens. A validação do servidor e o indicador
visual de alvo usam esse mesmo alcance.

| Classe | Recurso | Geração e custos |
| --- | --- | --- |
| Warlock | Mana (100) | Regenera 3/s; Shadow Bolt e maldições mantêm os custos anteriores. |
| Warrior | Raiva (100), começa em 0 | +12 por autoataque acertado, +8 ao receber um golpe, +15 ao acertar Charge. Charge custa 0; Cleave 25, Second Wind 30, Bladestorm 80. |
| Paladin | Poder sagrado (5), começa em 2 | Autoataque e Judgement geram 1. Judgement custa 0; Holy Light 1, Consecration 2, Divine Dawn 5. |
| Hunter | Foco (100) | Regenera 8/s. Aimed Shot custa 25, Poison Arrow 20, Multi-Shot 30, Arrow Rain 60. |

**Passivas:** Aurora mantém Dot Master. Sir Gura acumula Ímpeto: +3% de dano por acerto básico, até cinco acúmulos, que expiram após 4s sem acertos. Charger concede aura de raio 220: aliados recebem +15% de cura e -5% de dano. Lulu ganha +15% de dano após 1s sem se mover; mover remove o bônus. Os recursos, custos e estados das passivas aparecem no HUD e nos tooltips.

Ataques e habilidades validam identidade, classe, equipe, alcance, vida, recurso da classe
e cooldown no servidor. O cooldown visual começa após confirmação do servidor.
As novas habilidades possuem ícones próprios, descrição de custo/recarga no tooltip
e efeitos distintos. O veneno da Lulu aparece no mesmo HUD dos DoTs da Aurora;
aplicações do mesmo arqueiro renovam o efeito. Áreas não causam dano aliado.

### Animação do Jefferson

`Art/Chars/Jefferson - The Wizard/JeffersonIdleAtlas.png` contém 36 quadros em grade
6×6: a espera usa 12 fps (3s), e a apresentação em movimento usa a mesma sequência
a 14 fps. A morte interrompe a animação. O atlas é incluído no repositório, sem
necessidade de acessar o Ludo durante o jogo. O vídeo do Ludo veio com quadriculado
embutido; a transparência foi reconstruída com a ferramenta de edição de imagens.
Detalhes e fonte em `Art/Chars/Jefferson - The Wizard/ANIMATION.md`.

### Testar as classes

```sh
godot --headless --path . res://tests/hero_classes.tscn
# Rede: dois terminais, porta UDP 18082
# Terminal 1:
godot --headless --path . res://tests/class_network.tscn -- --server
# Terminal 2, após CLASS_NETWORK_SERVER_READY:
godot --headless --path . res://tests/class_network.tscn -- --client
```

A suíte offline cobre os quatro repertórios, cooldown de Shadow Bolt, ultimates,
alcance, cura, áreas, autoataque por projétil, veneno e sua interface.
A suíte ENet cobre magia de classe indevida, dano único do projétil/veneno,
cura/escudo do paladino em aliado remoto e replicação dos indicadores de veneno.


### Ícones e tooltips das habilidades

Os ícones das classes seguem o estilo ilustrado dos originais, com moldura dourada e fundo de fantasia. Charge, Holy Light e Consecration reutilizam os PNGs originais. Os novos ícones vêm do atlas `Art/Skills/Classes/ClassIcons.png`, por recursos AtlasTexture.

Passar o mouse sobre uma habilidade mostra efeito, tecla, custo no recurso da classe, recarga, tempo de conjuração, alcance e alvo. O tooltip permanece disponível durante o cooldown; o timer continua bloqueando novos lançamentos. Os talentos ativos aparecem em verde no painel, com o tempo de conjuração modificado quando aplicável.

A seleção de personagens mostra os ícones originais e os nomes das **16 habilidades**.
Passar o mouse em qualquer parte de cada linha, incluindo ícone e nome, abre o mesmo
painel ilustrado da barra de combate. O papel da classe também tem tooltip de recurso
e passiva. A tela preserva a rolagem em janelas menores.

### Autoataque do Charger

Charger tem um atlas próprio de oito quadros de golpe de martelo, com preparação,
impacto, recuperação e retorno à postura inicial. O ciclo dura 1,1s e o impacto do
terceiro quadro coincide com a liberação do ataque a 35% do ciclo. O dano continua
validado no servidor. A animação de conjuração permanece separada; margens do atlas
alinham os pés e a escala é restaurada ao voltar para idle ou conjuração.
O nome da animação e o espelhamento usam a sincronização existente nos clientes.
Fonte e organização em `Art/Chars/Charger/ANIMATION.md`.

```sh
godot --headless --path . res://tests/skill_tooltips.tscn
```

A suíte verifica os tooltips das 16 habilidades no combate e na seleção, acesso
durante cooldown, talentos, troca de cena e o impacto do autoataque de Charger.
O teste ENet de classes verifica também animação, tamanho e espelhamento remotos.


## Ciclo cooperativo e progressão da expedição

O lobby mostra nomes, classes e estado Pronto de cada participante. O host inicia
somente com o grupo completo pronto. Trocar de classe cancela o estado Pronto.
Quem entra durante uma luta é espectador e participa depois de passar pelo lobby
na próxima rodada. Uma saída durante a contagem regressiva exige nova confirmação.

Vitória oferece **uma** melhoria por participante, validada pelo servidor:

- **Poder crescente:** +12% de dano, acumulável.
- **Vigor renovado:** +20% da vida base máxima por escolha.
- **Maestria:** recarga multiplicada por 0,88 a cada escolha, até mínimo de 45% da
  recarga base, e +15% de cura por escolha.

O host espera as escolhas do grupo antes de continuar. Cada vitória aumenta a
vida do próximo Jefferson em 15% da base de 480. Uma derrota preserva as melhorias
e a rodada; não concede novas escolhas. Voltar à seleção inicia uma expedição nova.
A progressão dura a sessão e não é salva em disco.

O reset invalida conjurações pendentes, limpa efeitos, projéteis e cooldowns,
restaura a vida e o recurso inicial de cada classe e reposiciona os jogadores.
Movimento durante conjuração cancela o efeito; o custo e a recarga já iniciados
são mantidos. A animação de morte e a coloração da fase 2 do boss são feitas na
apresentação; os eventos de dano, crítico, cura e escudo têm efeitos e sons próprios.
Os sons são originais, sintetizados em `Art/Audio`; testes headless não reproduzem áudio.

WASD e Charge respeitam os limites da arena e os dois troncos definidos em
`ArenaNavigation.gd`, com passos de colisão para evitar atravessar árvores.
O indicador de alvo mostra se o autoataque alcança o inimigo. Hover nas habilidades
exibe alcance e raio; a mira de Arrow Rain valida a posição no servidor antes de
consumir recurso. Outros mapas precisarão fornecer seus próprios obstáculos.

### Verificação completa

Com Godot 4.4.1 disponível e os recursos importados:

```sh
python3 tests/run_checks.py --godot godot --network
```

O runner executa nove suítes offline e quatro suítes ENet: três com dois processos
e uma com quatro jogadores reais. A nova
suíte de sessão cobre prontidão, contagem, mecanismos cooperativos, interrupção,
recompensas individuais, nova rodada, derrota, reset e troca de classe sem desconexão.
As portas locais usadas pelos testes são UDP 18081, 18082, 18083 e 18084.

## Talentos por personagem

Depois de selecionar a classe no lobby, abra **Árvore de talentos**. Cada personagem
dispõe de **três pontos** por expedição, sem precisar desbloquear níveis. Cada caminho
tem três talentos em sequência; você pode investir os três no mesmo caminho ou
combinar os primeiros níveis dos dois. Os pré-requisitos, a classe e o orçamento são
validados pelo host. Alterar ou redistribuir pontos cancela seu estado Pronto.

| Personagem | Caminho | Talento 1 → Talento 2 → Talento 3 |
| --- | --- | --- |
| Aurora | Aflição | +20% dano periódico → +2 mana/s → Soul Reap recebe +18 por DoT próprio, em vez de +12 |
| Aurora | Destruição | +25% dano de Shadow Bolt → conjuração de 0,7s → +25% dano de Soul Reap |
| Sir Gura | Berserker | +25% dano de Cleave → 16 raiva por ataque básico → +25% dano de Bladestorm |
| Sir Gura | Guardião | -10% dano recebido → Second Wind concede 30 de escudo → +20% da vida base |
| Charger | Luz | +20% cura realizada → Holy Light conjura em 0,8s → Divine Dawn cura 60 de base |
| Charger | Bastião | -10% dano recebido → Consecration tem raio 185 → Divine Dawn concede 50 de escudo |
| Lulu | Veneno | Poison Arrow causa 6/s → veneno dura 10s → +20% dano de Arrow Rain |
| Lulu | Pontaria | +25% dano de Aimed Shot → preparação de 0,7s → Mira firme concede +25% dano |

**Redistribuir pontos** é grátis no lobby. As escolhas ficam bloqueadas durante a
contagem e o combate, persistem nas próximas tentativas e são limpas ao trocar de
classe ou reiniciar a expedição pela seleção. Não são salvas em disco. É possível
iniciar sem gastar todos os pontos. Os tooltips das habilidades indicam os talentos
selecionados que afetam aquela habilidade; tempos e áreas usam os valores modificados.
A recarga base de Shadow Bolt continua sendo 4s.

## Resumo do combate

Vitória e derrota abrem a aba **Resumo do combate**. Cada jogador tem dano efetivo
e DPS, cura efetiva e HPS, proteção absorvida, dano recebido, interrupções, mecânicas
e mortes. Destaques separados reconhecem dano, cura, proteção e utilidade; empates
recebem o mesmo destaque. A aba **Melhorias e grupo** mantém as recompensas após a vitória.

O host registra os eventos e publica uma fotografia do resultado para todos os peers.
Clientes não enviam números de combate. O tempo exclui lobby e contagem regressiva;
a próxima tentativa começa com contadores zerados. Os resultados mantêm os jogadores
que desconectaram durante a luta e não incluem espectadores que chegaram depois.

- Dano conta a vida removida, sem excesso ao matar nem dano absorvido por escudos.
- Cura conta a vida realmente recuperada, sem sobrecura.
- Proteção pertence a quem concedeu o escudo e só conta quando absorve dano.
  Aumentos de um escudo mantêm a atribuição das parcelas anteriores.
- Mecânicas contam Ruptura/Lança evitadas, Marcas sem sobreposição e Vínculo dividido
  entre pelo menos dois jogadores. Cataclismo interrompido conta em Interrupções.
  Orbes, ataques básicos e habilidades de reposicionamento não dão pontos de mecânica.
- Mortes contam transições de vida positiva para zero causadas por dano do combate.

Teste específico de talentos, pré-requisitos, dano real, cura, proteção e resultados:

```sh
godot --headless --path . res://tests/talents_report.tscn
```

O teste ENet de sessão também verifica escolhas remotas, redistribuição, bloqueio
durante combate, tooltips modificados, atribuição de métricas e reset entre rodadas.
`party_report_network` verifica um grupo completo com nomes UTF-8 longos e o envio
confiável de resultados maiores que um pacote de sincronização padrão. O resumo
é enviado uma vez por RPC confiável e também para quem entra após o encerramento.

## Visão ampliada da arena

`ArenaCamera` usa uma câmera fixa para todo o grupo, com zoom de **0,75**. Os
personagens comuns aparecem 25% menores, e o enquadramento de referência passa a
mostrar um cenário de **1536 × 864 unidades**. A área navegável aumenta de
1050 × 370 para **1400 × 500**, aproximadamente 80% mais espaço de movimentação.

`ForestArena.gd` estende o terreno com os tiles existentes, preservando as bordas
da ilha e as duas árvores nas mesmas posições de colisão. A água continua além
das bordas para preencher janelas com outras proporções. Os limites de movimento,
as posições seguras do boss e a validação das áreas de magia usam a arena expandida.

O sprite de Jefferson passa de 420 para **630 unidades** de altura do quadro
(50% maior no mundo); depois do afastamento da câmera, ainda aparece maior do que
na visão anterior. A área de seleção, a sombra, a aura de fase 2 e seus efeitos
de proteção/teleporte acompanham o tamanho. O dano e as áreas ofensivas continuam
usando as distâncias reais de combate.

Vida, recursos, habilidades e conjurações ficam em `CombatHUD`, um CanvasLayer
independente da câmera. A barra de combate acompanha o rodapé em janelas mais altas.
Números de dano e indicadores de DoT são projetados do mundo
para a tela, mantendo o tamanho de leitura. As instruções dos avisos de magia
compensam o zoom e permanecem dentro da área visível. Seleção de alvos e mira no
chão usam as coordenadas de mundo transformadas pela câmera.

```sh
godot --headless --path . res://tests/arena_view.tscn
```

A suíte cobre terreno real na área nova, navegação e limites, separação do HUD,
projeção dos números e lançamento de magia no chão. O teste de boss em ENet
verifica também a câmera e o tamanho do Jefferson no cliente remoto.
