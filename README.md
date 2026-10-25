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
Habilidades: teclas numéricas; Alt + tecla lança no próprio personagem.
Habilidades de área sem alvo usam a posição do lançador.

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

## Primeiro boss: Jefferson Wizard

Ao selecionar o primeiro personagem, o encontro começa automaticamente.
Jefferson tem **300 HP**, escolhe o jogador vivo mais próximo, persegue e causa
**8 de dano corpo a corpo**, com intervalo de **1,6 segundo** entre ataques.

A cada **6 segundos** (após uma abertura de 3 segundos), ele marca um círculo
na posição de um jogador. O círculo fica **fixo** por **2 segundos**; saia dele
antes da detonação para evitar **25 de dano**. O boss para de andar durante o aviso.
O dano considera a posição do personagem, não a extensão da imagem.

Clique no boss para selecioná-lo. Habilidades de dano e ataques básicos podem
atingi-lo; cura e escudo são para aliados. Áreas dos jogadores não atingem aliados.
A barra superior mostra a vida do boss e o tempo restante do aviso.

A luta termina com **vitória** ao zerar a vida do boss ou **derrota** quando não
há jogadores vivos. Avisos e habilidades pendentes são cancelados. Para outra
tentativa, reinicie a sessão. Ainda não há fases, loot, aggro por ameaça ou respawn.
O servidor controla a IA, as posições dos avisos e os danos; clientes recebem o
estado do encontro, inclusive ao entrar com a luta em andamento.

### Testes do boss

```sh
godot --headless --path . res://tests/boss_fight.tscn
```

Para testar replicação real, execute em dois terminais (porta UDP 18081):

```sh
# Terminal 1
godot --headless --path . res://tests/boss_network.tscn -- --server
# Terminal 2, após aparecer NETWORK_SERVER_READY
godot --headless --path . res://tests/boss_network.tscn -- --client
```

Os processos encerram automaticamente. Os logs devem mostrar
`NETWORK_CLIENT_PASS` e `NETWORK_SERVER_PASS`. Este teste cobre entrada tardia,
vida/posição/aviso do boss, ataque com identidade adulterada, habilidade do cliente,
vitória e desconexão.
