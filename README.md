# World of Copycraft Multiplayer

Protótipo multiplayer em Godot 4.4 (GDScript / Forward Plus).

## Executar

1. Abra `project.godot` no Godot 4.4 e aguarde a importação dos recursos.
2. Execute o projeto (F6 executa uma cena; use F5 para executar o projeto).
3. Em uma instância, escolha **Host Game** e selecione o personagem.
4. Na outra instância, informe o IP ou hostname do host e escolha **Join Game**.
   Para testar na mesma máquina, use `127.0.0.1`.

A conexão usa ENet/UDP na porta **8080**, com até quatro jogadores incluindo
   o host. Para jogar em LAN, permita essa porta no firewall do host.

Movimento: WASD. Alvo: clique esquerdo. Ataque básico: botão direito.
Habilidades: **1 / 2 / 3**; ultimate: **R ou 4**. Cura sem aliado selecionado usa o próprio personagem; Alt + cura força autocura.
Arrow Rain sem alvo usa sua posição; Consecration sempre consagra o chão sob o paladino.

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
mana, cooldown e tempo de conjuração, e replica os atributos de combate.
O movimento continua sob autoridade do cliente; não há proteção completa
contra adulteração de posição. Respawn e reinício de encontro ainda não estão implementados.

## Jefferson, o Arcanista

O encontro começa quando o primeiro jogador seleciona um personagem. Jefferson
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
Para outra tentativa, reinicie a sessão. Ainda não há loot ou respawn.

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
6 a cada 1,3s. Todos têm 100 de mana e regeneram 3/s.

Ataques e habilidades validam identidade, classe, equipe, alcance, vida, mana
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

Passar o mouse sobre uma habilidade mostra efeito, tecla, custo de mana, recarga, tempo de conjuração, alcance e alvo. O tooltip permanece disponível durante o cooldown; o timer continua bloqueando novos lançamentos. Os rótulos das habilidades na seleção também exibem os detalhes ao passar o mouse.
