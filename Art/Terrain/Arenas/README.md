# Pisos das arenas

As duas novas texturas foram geradas no **Ludo.ai**, no modo **Texture** com
repetição contínua, em 2026-11-04. Cada uma consumiu 0,5 crédito do plano Indie.
As fontes são imagens RGB opacas de 1024 × 1024; os PNGs locais são conversões
sem alteração do conteúdo visual, feitas com Pillow.

| Arquivo | Fonte Ludo |
| --- | --- |
| `Ruins.png` | https://storage.googleapis.com/ludo-assets/1ea5e6b91535c4b06955643dafb0bdc0.webp |
| `Glacier.png` | https://storage.googleapis.com/ludo-assets/ccbcdbeb374ef2a34b5b52ec0b2331d1.webp |

SHA-256 dos arquivos WebP originais:

- Ruínas: `67d02bf1936f1c30561e9830c52e84015d36a34037578b552293ccf0a3b2f08b`
- Glacial: `c2a2524b1936a7b6a63270247fc49559f2aea264101e1f07cd904b83ab73e203`

Direção solicitada: chão visto de cima, ortográfico, sem personagens, objetos,
interface, texto ou runas luminosas. Pintura de fantasia com contraste discreto
para manter os avisos das habilidades legíveis. Ruínas usam pedra antiga azul
acinzentada com pequenas juntas musgosas; o santuário usa gelo azulado com juntas
foscas. O Godot aplica modulação de cor para integrar cada piso à sua arena.

`ArenaScenery.gd` repete cada imagem a cada 512 unidades de mundo e recorta as
células das bordas. A clareira reutiliza os tiles, árvores e pedras já existentes
no projeto; as outras arenas também reutilizam as pedras existentes. As árvores
conservam seus cinco quadros de animação originais.

Os limites e passeios são desenhados no Godot. A decoração exterior não bloqueia
a área jogável; os únicos bloqueios dentro dela são os pontos declarados em
`ArenaCatalog.gd`. Não há efeitos de dano ou superfícies escorregadias escondidos.
O jogo usa apenas os arquivos locais e não precisa acessar o Ludo em runtime.
