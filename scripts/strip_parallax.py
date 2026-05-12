"""
strip_parallax.py — v2
Moves all ParallaxLayer children to World, removes ParallaxBackground/Layer nodes.
Critically: inserts the reparented nodes AFTER the World node declaration so
Godot can resolve the parent path at load time.
"""
import re
import sys

SCENE_PATH = r"C:\Users\Peter Ellis\Documents\Claude Code\Beasts of England\scenes\act1\old_major_platformer.tscn"

with open(SCENE_PATH, "r", encoding="utf-8") as f:
    text = f.read()

lines = text.splitlines(keepends=True)

# Collect ParallaxLayer full paths
parallax_layer_paths = set()
for line in lines:
    m = re.match(r'\[node name="(\w+)" type="ParallaxLayer" parent="([^"]+)"', line)
    if m:
        parallax_layer_paths.add(f"{m.group(2)}/{m.group(1)}")

print(f"ParallaxLayer paths: {parallax_layer_paths}")

# Split the file into blocks.  A block = [header_line, ...body_lines]
# Non-node preamble = everything before the first [node ...] line.
preamble = []
blocks = []  # list of (header_line, body_lines) tuples

i = 0
while i < len(lines) and not lines[i].startswith("[node "):
    preamble.append(lines[i])
    i += 1

current_header = None
current_body = []
while i < len(lines):
    line = lines[i]
    if line.startswith("[node ") or line.startswith("[connection "):
        if current_header is not None:
            blocks.append((current_header, current_body))
        current_header = line
        current_body = []
    else:
        current_body.append(line)
    i += 1
if current_header is not None:
    blocks.append((current_header, current_body))

# Categorise blocks
skip_types = {"ParallaxBackground", "ParallaxLayer"}
normal_blocks = []       # pass through unchanged
reparented_blocks = []   # were inside a ParallaxLayer, need parent="World"
world_block_idx = None   # index in normal_blocks where World is declared

for header, body in blocks:
    # Parse header attrs
    type_m = re.search(r'type="([^"]+)"', header)
    parent_m = re.search(r'parent="([^"]+)"', header)
    name_m = re.search(r'name="([^"]+)"', header)

    node_type = type_m.group(1) if type_m else ""
    node_parent = parent_m.group(1) if parent_m else ""
    node_name = name_m.group(1) if name_m else ""

    # Drop ParallaxBackground and ParallaxLayer node declarations
    if node_type in skip_types:
        continue

    # Reparent children of any ParallaxLayer
    is_parallax_child = node_parent in parallax_layer_paths
    if is_parallax_child:
        new_header = header.replace(f'parent="{node_parent}"', 'parent="World"')
        reparented_blocks.append((new_header, body))
        continue

    # Normal node - track World
    if node_name == "World" and node_parent == ".":
        world_block_idx = len(normal_blocks)

    normal_blocks.append((header, body))

if world_block_idx is None:
    print("ERROR: World node not found!", file=sys.stderr)
    sys.exit(1)

print(f"World node at normal_blocks index: {world_block_idx}")
print(f"Reparented blocks: {len(reparented_blocks)}")

# Rebuild: insert reparented blocks right after World's block (and its immediate children)
# Actually, to be safe: insert them after all existing World/* children and just before
# the next top-level node (i.e., after the World block + all blocks whose parent starts with "World")
# Simpler: insert right after the World block. Existing World/* children are already
# after it; the new ones just join them — Godot resolves by name, order within World is fine.

# Find insertion point: right after the World block itself
insert_after = world_block_idx  # insert *after* this index

output_blocks = (
    normal_blocks[:insert_after + 1]
    + reparented_blocks
    + normal_blocks[insert_after + 1:]
)

# Reconstruct file text
out_lines = list(preamble)
for header, body in output_blocks:
    out_lines.append(header)
    out_lines.extend(body)

result = "".join(out_lines)

# Sanity checks
if "ParallaxBackground" in result:
    print("ERROR: ParallaxBackground still in output!", file=sys.stderr)
    sys.exit(1)
if '[node name="World"' not in result:
    print("ERROR: World node missing!", file=sys.stderr)
    sys.exit(1)

original_node_count = len([h for h, _ in blocks])
output_node_count = len(output_blocks)
print(f"Original node blocks: {original_node_count}")
print(f"Output node blocks:   {output_node_count}  (dropped {original_node_count - output_node_count}: 1 ParallaxBG + {len(parallax_layer_paths)} layers)")

with open(SCENE_PATH, "w", encoding="utf-8") as f:
    f.write(result)

print("Done. Scene file rewritten.")
