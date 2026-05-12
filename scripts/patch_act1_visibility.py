"""Move start position to mid-level so screenshot captures density; spread stars wider."""
import re
from pathlib import Path

path = Path("scenes/act1/old_major_platformer.tscn")
text = path.read_text(encoding="utf-8")

# Move OldMajor start from x=180 to x=1100 (middle of level)
text = re.sub(
    r'(\[node name="OldMajor" parent="World"[^\n]+\]\nposition = Vector2\()180\.0, 470\.0(\))',
    r'\g<1>1100.0, 470.0\g<2>',
    text,
)

# Significantly enlarge ALL star scales by another 1.5x for visibility
def grow_stars(m):
    pre, sx, sy = m.group(1), float(m.group(2)), float(m.group(3))
    return f'{pre}({sx * 1.5:.1f}, {sy * 1.5:.1f})'

text = re.sub(
    r'(\[node name="Star\d+"[^\[]+scale = Vector2)\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?)\)',
    grow_stars,
    text,
    flags=re.MULTILINE,
)

# Reposition some stars to be in mid-camera view (x=1100 ± 640)
# Stars 0-9 → keep
# Stars 10-29 → cluster around mid-level so they're always visible regardless of camera
lines = text.split('\n')
star_indices_seen = 0
for i, line in enumerate(lines):
    m = re.match(r'\[node name="Star(\d+)"', line)
    if m:
        idx = int(m.group(1))
        if idx >= 10:
            # Find the next position line in same block
            for j in range(i + 1, min(i + 5, len(lines))):
                pm = re.match(r'position = Vector2\((-?\d+), (-?\d+)\)', lines[j])
                if pm:
                    # Reposition: cluster around x=1100
                    new_x = 200 + ((idx * 137) % 2000)
                    new_y = 60 + ((idx * 73) % 320)
                    lines[j] = f'position = Vector2({new_x}, {new_y})'
                    break

text = '\n'.join(lines)
path.write_text(text, encoding="utf-8")
print("Patched: player at x=1100, stars enlarged + repositioned")
