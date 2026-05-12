"""Generate the dense Act 1 night-walk scene with 80+ prop instances."""
import random

ext_id = 1
ext_lines = []

def add_ext(rtype, path):
    global ext_id
    line = f'[ext_resource type="{rtype}" path="res://{path}" id="{ext_id}"]'
    val = f'ExtResource("{ext_id}")'
    ext_id += 1
    ext_lines.append(line)
    return val

SCRIPT = add_ext("Script", "scenes/act1/old_major_platformer.gd")
PLAYER = add_ext("PackedScene", "scenes/act1/player/old_major.tscn")
HUD = add_ext("PackedScene", "scenes/act1/ui/hearts_hud.tscn")
MOSES_CIRCLER = add_ext("Script", "scenes/act1/objects/moses_circler.gd")
GRASS = add_ext("Texture2D", "assets/sprites/tiles/grass_top.png")
SOIL = add_ext("Texture2D", "assets/sprites/tiles/soil_fill.png")
CABIN_FULL = add_ext("Texture2D", "assets/sprites/erw/cabin/cabin_full.png")
PINE_FULL = add_ext("Texture2D", "assets/sprites/erw/trees/pine_full.png")
PINE_MED = add_ext("Texture2D", "assets/sprites/erw/trees/pine_med.png")
PINE_SMALL = add_ext("Texture2D", "assets/sprites/erw/trees/pine_small.png")
PINE_TINY = add_ext("Texture2D", "assets/sprites/erw/trees/pine_tiny.png")
BARREL1 = add_ext("Texture2D", "assets/sprites/erw/props/barrel1.png")
BARREL2 = add_ext("Texture2D", "assets/sprites/erw/props/barrel2.png")
BARREL3 = add_ext("Texture2D", "assets/sprites/erw/props/barrel3.png")
CRATE1 = add_ext("Texture2D", "assets/sprites/erw/props/crate1.png")
CRATE2 = add_ext("Texture2D", "assets/sprites/erw/props/crate2.png")
BUCKET1 = add_ext("Texture2D", "assets/sprites/erw/props/bucket1.png")
SMOKE = add_ext("Texture2D", "assets/sprites/erw/props/chimney_smoke.png")
FENCE_MID = add_ext("Texture2D", "assets/sprites/erw/fence/f_mid.png")
FENCE_LEFT = add_ext("Texture2D", "assets/sprites/erw/fence/f_left.png")
FENCE_RIGHT = add_ext("Texture2D", "assets/sprites/erw/fence/f_right.png")
WELL = add_ext("Texture2D", "assets/sprites/tiles/erw_waterwell.png")
FLOWERS = [add_ext("Texture2D", f"assets/sprites/erw/flowers/flower{i}.png") for i in range(1, 7)]
MUSH = [add_ext("Texture2D", f"assets/sprites/erw/mushrooms/m{i}.png") for i in range(1, 5)]
STAR = add_ext("Texture2D", "assets/sprites/erw/props/star.png")
MOON = add_ext("Texture2D", "assets/sprites/erw/props/moon.png")
TUFT = add_ext("Texture2D", "assets/sprites/erw/props/grass_tuft.png")
MOSES = add_ext("Texture2D", "assets/sprites/characters/moses_flying.png")
LANTERN = add_ext("Texture2D", "assets/sprites/characters/lantern.png")
LIGHT = add_ext("Texture2D", "assets/sprites/ui/lantern_light.png")

sub_lines = [
    '[sub_resource type="RectangleShape2D" id="GroundShape"]',
    'size = Vector2(3400.0, 80.0)',
    '',
    '[sub_resource type="RectangleShape2D" id="BarnDoorShape"]',
    'size = Vector2(80.0, 160.0)',
    '',
]

nodes = []
nodes += [
    '[node name="OldMajorPlatformer" type="Node2D"]',
    f'script = {SCRIPT}',
    '',
    '[node name="CanvasModulate" type="CanvasModulate" parent="."]',
    'color = Color(0.32, 0.38, 0.62, 1)',
    '',
    '[node name="NightSky" type="ColorRect" parent="."]',
    'offset_left = -2000.0',
    'offset_top = -1000.0',
    'offset_right = 4800.0',
    'offset_bottom = 1000.0',
    'color = Color(0.04, 0.05, 0.12, 1)',
    '',
    '[node name="ParallaxBackground" type="ParallaxBackground" parent="."]',
    '',
    '[node name="DistantLayer" type="ParallaxLayer" parent="ParallaxBackground"]',
    'motion_scale = Vector2(0.05, 0)',
    '',
    '[node name="Moon" type="Sprite2D" parent="ParallaxBackground/DistantLayer"]',
    'position = Vector2(900, 100)',
    f'texture = {MOON}',
    'scale = Vector2(3, 3)',
    'modulate = Color(2.4, 2.3, 2.0, 1)',
    '',
    '[node name="HillsBack" type="Polygon2D" parent="ParallaxBackground/DistantLayer"]',
    'color = Color(0.55, 0.55, 0.7, 1)',
    'polygon = PackedVector2Array(-1000, 580, -650, 480, -300, 540, 50, 470, 350, 520, 700, 440, 1050, 500, 1400, 450, 1750, 510, 2100, 460, 2450, 500, 2450, 720, -1000, 720)',
    '',
    '[node name="HillsMid" type="Polygon2D" parent="ParallaxBackground/DistantLayer"]',
    'color = Color(0.42, 0.45, 0.6, 1)',
    'polygon = PackedVector2Array(-1000, 600, -700, 520, -400, 570, -100, 500, 200, 550, 500, 490, 800, 540, 1100, 480, 1400, 530, 1700, 470, 2000, 520, 2300, 500, 2450, 540, 2450, 720, -1000, 720)',
    '',
]

random.seed(11)
star_count = 30
for i in range(star_count):
    sx = random.randint(-400, 2700)
    sy = random.randint(20, 280)
    sscale = random.choice([1.0, 1.5, 2.0, 2.5])
    salpha = random.uniform(0.4, 1.0)
    nodes += [
        f'[node name="Star{i}" type="Sprite2D" parent="ParallaxBackground/DistantLayer"]',
        f'position = Vector2({sx}, {sy})',
        f'texture = {STAR}',
        f'scale = Vector2({sscale}, {sscale})',
        f'modulate = Color(2.5, 2.5, 2.3, {salpha:.2f})',
        '',
    ]

# Mid layer
nodes += [
    '[node name="MidLayer" type="ParallaxLayer" parent="ParallaxBackground"]',
    'motion_scale = Vector2(0.35, 0)',
    '',
]

cabin_positions = [(180, 470, 0.45), (1080, 480, 0.5), (1820, 470, 0.42)]
for i, (cx, cy, cs) in enumerate(cabin_positions):
    nodes += [
        f'[node name="DistantCabin{i}" type="Sprite2D" parent="ParallaxBackground/MidLayer"]',
        f'position = Vector2({cx}, {cy})',
        f'texture = {CABIN_FULL}',
        f'scale = Vector2({cs}, {cs})',
        '',
    ]

smoke_positions = [(180, 380), (1820, 390)]
for i, (sx, sy) in enumerate(smoke_positions):
    nodes += [
        f'[node name="Smoke{i}" type="Sprite2D" parent="ParallaxBackground/MidLayer"]',
        f'position = Vector2({sx}, {sy})',
        f'texture = {SMOKE}',
        'scale = Vector2(0.18, 0.18)',
        'modulate = Color(1.6, 1.6, 1.8, 0.55)',
        '',
    ]

tree_textures = {'full': PINE_FULL, 'med': PINE_MED, 'small': PINE_SMALL, 'tiny': PINE_TINY}
mid_trees = [(420, 490, 'med', 0.6), (640, 480, 'small', 0.85), (820, 490, 'full', 0.5),
             (1280, 490, 'med', 0.7), (1480, 480, 'full', 0.55), (2100, 490, 'small', 0.95)]
for i, (tx, ty, kind, ts) in enumerate(mid_trees):
    nodes += [
        f'[node name="MidTree{i}" type="Sprite2D" parent="ParallaxBackground/MidLayer"]',
        f'position = Vector2({tx}, {ty})',
        f'texture = {tree_textures[kind]}',
        f'scale = Vector2({ts}, {ts})',
        '',
    ]

# Near layer
nodes += [
    '[node name="NearLayer" type="ParallaxLayer" parent="ParallaxBackground"]',
    'motion_scale = Vector2(0.65, 0)',
    '',
]

near_trees = [(160, 530, 'full', 1.0), (560, 525, 'med', 1.15), (1180, 530, 'full', 1.05),
              (1660, 520, 'med', 1.2), (2160, 530, 'full', 0.95)]
for i, (tx, ty, kind, ts) in enumerate(near_trees):
    nodes += [
        f'[node name="NearTree{i}" type="Sprite2D" parent="ParallaxBackground/NearLayer"]',
        f'position = Vector2({tx}, {ty})',
        f'texture = {tree_textures[kind]}',
        f'scale = Vector2({ts}, {ts})',
        '',
    ]

nodes += [
    '[node name="Waterwell" type="Sprite2D" parent="ParallaxBackground/NearLayer"]',
    'position = Vector2(940, 555)',
    f'texture = {WELL}',
    'scale = Vector2(1.8, 1.8)',
    '',
]

prop_data = [
    (320, 560, BARREL1, 1.5),
    (820, 560, BARREL2, 1.4),
    (1500, 565, BARREL3, 1.5),
    (1380, 565, CRATE1, 1.3),
    (1980, 570, CRATE2, 1.4),
    (2280, 565, BUCKET1, 1.3),
]
for i, (px, py, tex, sc) in enumerate(prop_data):
    nodes += [
        f'[node name="Prop{i}" type="Sprite2D" parent="ParallaxBackground/NearLayer"]',
        f'position = Vector2({px}, {py})',
        f'texture = {tex}',
        f'scale = Vector2({sc}, {sc})',
        '',
    ]

fence_xs = [0, 80, 160, 240, 320, 1700, 1780, 1860]
for i, fx in enumerate(fence_xs):
    if i in (0, 5):
        tex = FENCE_LEFT
    elif i in (4, 7):
        tex = FENCE_RIGHT
    else:
        tex = FENCE_MID
    nodes += [
        f'[node name="BackFence{i}" type="Sprite2D" parent="ParallaxBackground/NearLayer"]',
        f'position = Vector2({fx}, 595)',
        f'texture = {tex}',
        'scale = Vector2(1.6, 1.6)',
        '',
    ]

# World
nodes += [
    '[node name="World" type="Node2D" parent="."]',
    '',
    '[node name="Ground" type="StaticBody2D" parent="World"]',
    'position = Vector2(1300.0, 600.0)',
    '',
    '[node name="CollisionShape2D" type="CollisionShape2D" parent="World/Ground"]',
    'shape = SubResource("GroundShape")',
    '',
    '[node name="GrassTop" type="TextureRect" parent="World/Ground"]',
    'offset_left = -1700.0',
    'offset_top = -40.0',
    'offset_right = 1700.0',
    'offset_bottom = -24.0',
    f'texture = {GRASS}',
    'expand_mode = 1',
    'stretch_mode = 1',
    '',
    '[node name="SoilFill" type="TextureRect" parent="World/Ground"]',
    'offset_left = -1700.0',
    'offset_top = -24.0',
    'offset_right = 1700.0',
    'offset_bottom = 200.0',
    f'texture = {SOIL}',
    'expand_mode = 1',
    'stretch_mode = 1',
    '',
]

flower_pos = [
    (280, 575, FLOWERS[0], 1.5),
    (520, 580, FLOWERS[1], 1.4),
    (920, 578, FLOWERS[2], 1.6),
    (1320, 575, FLOWERS[3], 1.5),
    (1620, 580, FLOWERS[4], 1.4),
    (2080, 578, FLOWERS[5], 1.5),
]
for i, (fx, fy, tex, sc) in enumerate(flower_pos):
    nodes += [
        f'[node name="Flower{i}" type="Sprite2D" parent="World"]',
        f'position = Vector2({fx}, {fy})',
        f'texture = {tex}',
        f'scale = Vector2({sc}, {sc})',
        '',
    ]

mush_pos = [
    (360, 583, MUSH[0], 1.6),
    (780, 583, MUSH[1], 1.4),
    (1500, 583, MUSH[2], 1.7),
    (1860, 583, MUSH[3], 1.5),
]
for i, (mx, my, tex, sc) in enumerate(mush_pos):
    nodes += [
        f'[node name="Mushroom{i}" type="Sprite2D" parent="World"]',
        f'position = Vector2({mx}, {my})',
        f'texture = {tex}',
        f'scale = Vector2({sc}, {sc})',
        '',
    ]

random.seed(99)
tuft_xs = [random.randint(100, 2300) for _ in range(8)]
for i, tx in enumerate(tuft_xs):
    nodes += [
        f'[node name="Tuft{i}" type="Sprite2D" parent="World"]',
        f'position = Vector2({tx}, 582)',
        f'texture = {TUFT}',
        'scale = Vector2(2.2, 2.2)',
        '',
    ]

front_fence_xs = [80, 160, 1480, 1560, 2200, 2280]
for i, fx in enumerate(front_fence_xs):
    tex = FENCE_LEFT if i % 2 == 0 else FENCE_RIGHT
    nodes += [
        f'[node name="FrontFence{i}" type="Sprite2D" parent="World"]',
        f'position = Vector2({fx}, 620)',
        f'texture = {tex}',
        'scale = Vector2(2.2, 2.2)',
        '',
    ]

# Player + lantern + light
nodes += [
    f'[node name="OldMajor" parent="World" instance={PLAYER}]',
    'position = Vector2(180.0, 470.0)',
    '',
    '[node name="Lantern" type="Sprite2D" parent="World/OldMajor"]',
    'position = Vector2(-40.0, 50.0)',
    f'texture = {LANTERN}',
    'scale = Vector2(0.85, 0.85)',
    '',
    '[node name="LanternGlow" type="PointLight2D" parent="World/OldMajor"]',
    'position = Vector2(-40.0, 50.0)',
    'energy = 1.9',
    'texture_scale = 2.6',
    'range_layer_max = 0',
    f'texture = {LIGHT}',
    '',
    '[node name="Camera2D" type="Camera2D" parent="World/OldMajor"]',
    'enabled = true',
    'zoom = Vector2(1.5, 1.5)',
    'limit_left = -100',
    'limit_right = 2700',
    'limit_top = -100',
    'limit_bottom = 720',
    'position_smoothing_enabled = true',
    'position_smoothing_speed = 4.0',
    '',
    '[node name="MosesNest" type="Node2D" parent="World"]',
    'position = Vector2(1500.0, 200.0)',
    '',
    '[node name="Moses" type="Sprite2D" parent="World/MosesNest"]',
    f'texture = {MOSES}',
    'scale = Vector2(1.1, 1.1)',
    f'script = {MOSES_CIRCLER}',
    '',
    '[node name="BarnDoor" type="Area2D" parent="World"]',
    'position = Vector2(2400.0, 500.0)',
    '',
    '[node name="CollisionShape2D" type="CollisionShape2D" parent="World/BarnDoor"]',
    'shape = SubResource("BarnDoorShape")',
    '',
    '[node name="BarnVisual" type="Sprite2D" parent="World/BarnDoor"]',
    'position = Vector2(-20.0, -200.0)',
    f'texture = {CABIN_FULL}',
    'scale = Vector2(1.4, 1.4)',
    '',
    f'[node name="HeartsHUD" parent="." instance={HUD}]',
    '',
    '[connection signal="body_entered" from="World/BarnDoor" to="." method="on_barn_reached"]',
]

header = f'[gd_scene load_steps={ext_id + 1} format=3 uid="uid://act1_platformer"]'
content = '\n'.join([header, ''] + ext_lines + [''] + sub_lines + nodes)

with open("scenes/act1/old_major_platformer.tscn", "w", encoding="utf-8") as f:
    f.write(content)

# Counts
node_count = content.count('[node name="') - 1
sprite_count = content.count('type="Sprite2D"')
print(f"Wrote dense scene: {node_count} total nodes, {sprite_count} Sprite2D instances")
