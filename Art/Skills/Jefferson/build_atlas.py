"""Build local SpriteFrames atlases from the documented Ludo MP4 frames.

Usage: python3 build_atlas.py /path/to/extracted/frames
Requires Pillow and numpy. No generation or network access.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import json, sys

root = Path(__file__).resolve().parent
source = Path(sys.argv[1])
files = sorted(source.glob('*.png'))
# Ludo's MP4 composites transparency over a fixed blurred checkerboard.
# Its first frame has a clear top row and left column. The checker is separable;
# reconstruct it, solve minimal foreground alpha, then keep emissive energy.
first = np.asarray(Image.open(files[0]).convert('RGB'), dtype=np.float32) / 255
mid = 200 / 255
background = mid + (first[:, 0, 0, None] - mid) * (first[0, :, 0, None].T - mid) / (first[0, 0, 0] - mid)
background = background[:, :, None]
clean = []
for file in files:
    rgb = np.asarray(Image.open(file).convert('RGB'), dtype=np.float32) / 255
    dark_alpha = 1 - np.min(rgb / background, axis=2)
    light_alpha = np.max((rgb - background) / (1 - background), axis=2)
    matte = np.clip(np.maximum(dark_alpha, light_alpha), 0, 1)
    emission = np.clip(rgb - (1 - matte[:, :, None]) * background, 0, 1)
    alpha = np.max(emission, axis=2)
    chroma = np.max(rgb, axis=2) - np.min(rgb, axis=2)
    alpha = np.where((alpha < 0.04) | ((chroma < 0.04) & (alpha < 0.12)), 0, alpha)
    straight = np.divide(emission, alpha[:,:,None], out=np.zeros_like(rgb), where=alpha[:,:,None] > 0)
    rgba = np.dstack((straight, alpha))
    frame = Image.fromarray(np.uint8(np.clip(rgba, 0, 1) * 255), 'RGBA')
    clean.append(frame)

# A fixed canvas for every frame preserves the source animation registration.
n = len(clean)
cols = 6
rows = (n + cols - 1) // cols
atlases = [('Vortex', (256, 256)), ('ArcaneLance', (512, 96))]
for name, cell in atlases:
    atlas = Image.new('RGBA', (cols*cell[0], rows*cell[1]))
    for i, frame in enumerate(clean):
        if name == 'ArcaneLance':
            data = np.array(frame)
            # Palette derivative of the same Ludo sequence: purple -> blue/cyan.
            red = data[:,:,0].copy()
            green = data[:,:,1].copy()
            blue = data[:,:,2].copy()
            data[:,:,0] = green
            data[:,:,1] = blue
            data[:,:,2] = red
            frame = Image.fromarray(data)
        inner = (cell[0] - 16, cell[1] - 16)
        frame = frame.convert('RGBa').resize(inner, Image.Resampling.LANCZOS).convert('RGBA')
        # Keep an eight-pixel clear gutter around each registered frame.
        atlas.paste(frame, ((i % cols) * cell[0] + 8, (i // cols) * cell[1] + 8))
    atlas.save(root / (name + '.png'), optimize=True)

clips = {
    'charge': ('Vortex', (list(range(min(8, n))) + list(range(min(8, n)-2, 0, -1))) * 4),
    'eruption': ('Vortex', list(range(n))),
    'orb': ('Vortex', list(range(min(8, n))) + list(range(min(8, n)-2, 0, -1))),
    'lance': ('ArcaneLance', list(range(n))),
    'sigil': ('Vortex', list(range(min(8, n))) + list(range(min(8, n)-2, 0, -1))),
}
parts = [f'[gd_resource type="SpriteFrames" load_steps={2*n+3} format=3]\n']
for index, (name, cell) in enumerate(atlases, 1):
    parts.append(f'[ext_resource type="Texture2D" path="res://Art/Skills/Jefferson/{name}.png" id="{index}"]\n')
for index, (name, cell) in enumerate(atlases, 1):
    for i in range(n):
        parts.append(f'[sub_resource type="AtlasTexture" id="{name}_{i}"]\natlas = ExtResource("{index}")\nregion = Rect2({i%cols*cell[0]}, {i//cols*cell[1]}, {cell[0]}, {cell[1]})\n')
records = []
for name, (atlas, indices) in clips.items():
    frames = ', '.join(f'{{"duration": 1.0, "texture": SubResource("{atlas}_{i}")}}' for i in indices)
    records.append('{\n"frames": [' + frames + '],\n"loop": ' + ('true' if name in ('orb', 'sigil') else 'false') + f',\n"name": &"{name}",\n"speed": 14.0\n' + '}')
parts.append('[resource]\nanimations = [' + ', '.join(records) + ']\n')
(root / 'LudoSpells.tres').write_text('\n'.join(parts))
print(json.dumps({'source_frames': n, 'clips': {k: len(v[1]) for k,v in clips.items()}}))
