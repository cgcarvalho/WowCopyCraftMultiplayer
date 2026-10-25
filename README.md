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
contra adulteração de posição. Equipes, vitória e respawn ainda não estão implementados.
