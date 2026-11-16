# Animações e efeitos de combate

As folhas desta pasta foram geradas no Ludo.ai. As animações de Téo, Sir Gura
e Lulu usam como referência os sprites dos personagens já presentes no jogo.
As folhas foram exportadas com transparência, reduzidas e reunidas em células
de tamanho fixo. `SkillClips.tres` indica as regiões de cada quadro e os ciclos
de reprodução.

| Arquivos | Uso |
| --- | --- |
| `arrow`, `hammer`, `poison`, `rivet` | Chuva de flechas, martelo de Judgement, espuma do veneno e rebite |
| `beacon`, `coil`, `valve`, `pose_device` | Dispositivos, vapor e pose de instalação de Téo |
| `heal`, `consecration`, `reap` | Holy Light, Divine Dawn, runas do piso e Soul Reap |
| `pose_charge`, `pose_spin`, `pose_aimed` | Investida e giro de Sir Gura, preparação da mira de Lulu |
| `cataclysm`, `rune` | Coluna do Cataclismo e Condutor Rúnico |

O Godot combina as folhas com contornos de área, pulsos, trilhas e sinais de
alvo. Esses elementos recebem as posições e os tempos do combate.
