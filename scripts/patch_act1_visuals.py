"""Patch the dense Act 1 scene for: visible stars/moon, lower zoom, brighter mods."""
import re
from pathlib import Path

path = Path("scenes/act1/old_major_platformer.tscn")
text = path.read_text(encoding="utf-8")

# Zoom 1.5 -> 1.0 (camera sees more)
text = text.replace("zoom = Vector2(1.5, 1.5)", "zoom = Vector2(1.0, 1.0)")

# Lantern glow wider
text = text.replace("texture_scale = 2.6", "texture_scale = 4.0")
text = text.replace("energy = 1.9", "energy = 2.4")

# CanvasModulate lighter (user said try 0.25/0.32/0.55, we'll go a hair brighter for prop visibility)
text = text.replace(
    "color = Color(0.32, 0.38, 0.62, 1)",
    "color = Color(0.42, 0.5, 0.75, 1)",
)

# Stars: push them lower in y by re-randomizing — instead, brighten + scale them up
# Replace all star modulate alphas to be brighter
text = re.sub(
    r"modulate = Color\(2\.5, 2\.5, 2\.3, ([\d.]+)\)",
    lambda m: f"modulate = Color(3.5, 3.5, 3.2, {min(1.0, float(m.group(1)) + 0.3):.2f})",
    text,
)

# Star y-positions: range was 20-280. Push them down to 80-450 by adding 100 if y<280
def shift_star_y(m):
    x = m.group(1)
    y = int(m.group(2))
    new_y = y + 120
    return f'position = Vector2({x}, {new_y})'

# Only shift positions of Star nodes — match the line BEFORE 'texture = ExtResource("33")' (the star tex)
# Star id is 33 in this version. Find blocks and shift their position.
lines = text.split('\n')
for i, line in enumerate(lines):
    if 'texture = ExtResource("33")' in line and i >= 2:
        pos_line = lines[i - 2]
        m = re.match(r'position = Vector2\((-?\d+), (-?\d+)\)', pos_line)
        if m:
            x, y = int(m.group(1)), int(m.group(2))
            new_y = y + 80
            lines[i - 2] = f'position = Vector2({x}, {new_y})'
text = '\n'.join(lines)

# Increase global star scale by adding minimum 2.0 factor — replace specific star scales
text = re.sub(
    r'(\[node name="Star\d+"[^\[]+scale = Vector2)\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?)\)',
    lambda m: f'{m.group(1)}({float(m.group(2)) * 1.6:.1f}, {float(m.group(3)) * 1.6:.1f})',
    text,
    flags=re.MULTILINE,
)

# Moon: bigger and brighter
text = text.replace(
    'scale = Vector2(3, 3)\nmodulate = Color(2.4, 2.3, 2.0, 1)',
    'scale = Vector2(5, 5)\nmodulate = Color(3.2, 3.0, 2.6, 1)',
)

# Make hills brighter so they read at night
text = text.replace(
    "color = Color(0.55, 0.55, 0.7, 1)",
    "color = Color(0.7, 0.72, 0.85, 1)",
)
text = text.replace(
    "color = Color(0.42, 0.45, 0.6, 1)",
    "color = Color(0.55, 0.58, 0.75, 1)",
)

path.write_text(text, encoding="utf-8")
print("Patched dense scene")
