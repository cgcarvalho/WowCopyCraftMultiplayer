# Ataques do Sir Gura

Os três sprites de efeitos foram gerados no portal Ludo.ai em 27/10/2026.
O cavaleiro mantém os desenhos existentes de armadura, barba e capa. As poses
existentes foram reorganizadas para a espada atingir o contato no momento do
ataque, em vez de completar a maior parte da animação depois do dano.

| Arquivo | Original do Ludo | Uso |
| --- | --- | --- |
| Ludo Basic Slash.png | [WebP](https://storage.googleapis.com/ludo-assets/b52654aa477299b239d981c322e5d40c.webp) | Rastro curto no ataque básico aceito pelo servidor |
| Ludo Cleave.png | [WebP](https://storage.googleapis.com/ludo-assets/f02c266cf93f0b9e0e2fb1fc6e7d639e.webp) | Arco largo da espada no Cleave |
| Ludo Bladestorm.png | [WebP](https://storage.googleapis.com/ludo-assets/65a202b61873d80b1a7b318a6626ec34.webp) | Anel de lâminas durante os seis segundos da ultimate |

Os originais têm transparência. Apenas as margens transparentes foram aparadas;
cada imagem foi dimensionada proporcionalmente para caber em 480×480 e colocada
num canvas transparente de 512×512. Não há dependência do site durante o jogo.
Cada efeito usa um sprite individual; escala, rotação e desaparecimento são
animados no Godot. `Ludo Reference.png` é um quadro recortado do idle já existente,
mantido como referência da identidade do personagem.

Prompts usados no Sprite Generator, modo Create:

- Basic: `fantasy sword slash arc visual effect, clean stylized cartoon game VFX, a curved crescent of silver-white blade sweep with warm amber/gold edge, small sweeping crescent moving left into a wide bright crescent at impact, then fragmenting and fading into light particles, flat pure green background, no character, no weapon holder, no scenery, no letters, no numbers, isolated VFX effect, transparent feeling`
- Cleave: `fantasy heavy cleave sword arc visual effect, clean stylized cartoon game VFX, a very wide and thick bright silver and amber/gold crescent sword arc, small sparks flying off the edges, builds up with anticipation then full wide crescent then fades, warm amber gold core with bright silver-white outer glow, flat pure green background, no character, no weapon holder, no scenery, no letters, no numbers, isolated VFX effect`
- Bladestorm: `fantasy bladestorm cyclone visual effect, clean stylized cartoon game VFX, circular silver and gold blade trails orbiting around a completely clear empty transparent center where a character will stand, clockwise rotational loop effect, transparent center, no character, no weapon holder, no scenery, no letters, no numbers, isolated ring VFX effect, flat pure green background`

## Reprodução e alinhamento

- Autoataque: 12 poses, ciclo de 0,9s. O quadro de contato é o quinto (índice 4),
  exibido aos 35% do ciclo, quando a requisição do golpe é enviada. A confirmação
  do servidor sincroniza esse contato e o rastro também nos outros clientes.
- Cleave: 14 poses em 0,65s, uma execução. Usa a duração do efeito existente.
- Bladestorm: sequência curta da espada em loop, giro visual e rastro circular
  ligados ao efeito real. Permite andar e preserva os seis ticks de dano.
- O deslocamento `(-7, -4)` compensa o canvas dos quadros de espada em relação
  ao idle. A camada especial mantém os pés apoiados durante o giro.
- Morte, fim do encontro e reset encerram os efeitos. Habilidades normais não
  interrompem a apresentação de um Bladestorm ativo.

Verificações: `tests/warrior_animations.tscn` e
`tests/warrior_animation_network.tscn` (ENet, UDP 18085).
