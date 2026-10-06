"""Original, animated mesh gifts. Blender 4.5; no flattened emoji animation."""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

TAU = math.tau
HERE = Path(__file__).resolve().parent
CATALOG = json.loads((HERE / "catalog.json").read_text())
parser = argparse.ArgumentParser()
parser.add_argument("--scene", required=True, choices=[s["id"] for s in CATALOG["scenes"]])
parser.add_argument("--output", default="cinematic-preview")
parser.add_argument("--samples", type=int, default=8)
parser.add_argument("--poster-only", action="store_true")
parser.add_argument("--geometry-only", action="store_true")
parser.add_argument("--poster-frame", type=int)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
spec = next(s for s in CATALOG["scenes"] if s["id"] == args.scene)
rng = random.Random(int(hashlib.sha256(args.scene.encode()).hexdigest()[:8], 16))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = args.samples
scene.render.resolution_x = CATALOG["width"]
scene.render.resolution_y = CATALOG["height"]
scene.render.resolution_percentage = 100
scene.render.fps = CATALOG["fps"]
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.render.image_settings.compression = 12
scene.world.color = (.012, .019, .038)
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.012, .019, .038, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .3
scene.view_settings.view_transform = "AgX"
scene.frame_start = 1
scene.frame_end = spec["duration"] * scene.render.fps
out = Path(args.output) / args.scene
out.mkdir(parents=True, exist_ok=True)

def material(name, color, metal=0, rough=.32, emission=0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*color, 1)
    shader = m.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return m

black = material("Stealth graphite", (.025, .031, .043), .78, .27)
gold = material("Champagne gold", (.83, .48, .14), .8, .23)
silver = material("Brushed steel", (.48, .58, .67), .85, .21)
cyan = material("Blue glass", (.02, .44, .85), .5, .17, 3)
red = material("Rose velvet", (.53, .011, .052), .05, .38)
pink = material("Rose quartz", (.9, .12, .37), .35, .27)
green = material("Living leaves", (.027, .21, .078), .1, .4)
ivory = material("Porcelain", (.88, .82, .69), .14, .23)
fire = material("Amber flame", (1, .21, .025), .05, .36, 7)
hot = material("White hot flame", (1, .83, .48), .05, .25, 14)
blue = material("Ice crystal", (.055, .32, .72), .5, .23, .4)
purple = material("Amethyst", (.28, .07, .6), .65, .26)
palette = [pink, cyan, gold, purple, green]
accent = palette[int(hashlib.sha256(args.scene.encode()).hexdigest()[-2:], 16) % 5]

def finish(obj, mat, parent=None, smooth=True):
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    if smooth and hasattr(obj.data, "polygons"):
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj

def empty(name):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    return o

def cone(name, r1, r2, depth, loc, mat, parent=None, vertices=32):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    return finish(o, mat, parent)

def sphere(name, loc, scale, mat, parent=None, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return finish(o, mat, parent)

def box(name, loc, scale, mat, parent=None, bevel=.045):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    if bevel:
        mod = o.modifiers.new("Crafted edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return finish(o, mat, parent, False)

def ring(name, radius, loc, mat, parent=None, thickness=.035):
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8, major_radius=radius,
                                   minor_radius=thickness, location=loc)
    o = bpy.context.object
    o.name = name
    return finish(o, mat, parent)

def tube(name, points, radius, mat, parent=None):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for p, co in zip(spline.bezier_points, points):
        p.co = co
        p.handle_left_type = p.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(o)
    return finish(o, mat, parent)

def mesh(name, verts, faces, mat, parent=None, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    return finish(o, mat, parent, smooth)

def key(o, frame, prop, value):
    setattr(o, prop, value)
    o.keyframe_insert(data_path=prop, frame=frame)

def linear(o):
    if o.animation_data and o.animation_data.action:
        # Blender 4.5 retains legacy action.fcurves for this simple keyframe API.
        for fc in o.animation_data.action.fcurves:
            for p in fc.keyframe_points:
                p.interpolation = "LINEAR"

def aim(o, at):
    return (Vector(at) - o.location).to_track_quat("-Z", "Y").to_euler()

for name, loc, power, color, size in [
    ("Softbox key", (4, -5, 7), 950, (.78, .87, 1), 4),
    ("Warm rim", (-4, 2, 6), 1300, (1, .62, .28), 3),
    ("Front fill", (0, -4, 3), 450, (.45, .66, 1), 4),
]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    light = bpy.context.object
    light.name = name
    light.data.energy = power
    light.data.color = color
    light.data.size = size
    light.data.use_shadow = name == "Softbox key"
    light.rotation_euler = aim(light, (0, 0, 1.8))
bpy.ops.object.camera_add(location=(5, -9, 5.4))
camera = bpy.context.object
scene.camera = camera
camera.data.lens = 52
camera.rotation_euler = aim(camera, (0, 0, 1.5))
cone("Obsidian studio", 25, 25, .08, (0, 0, -.16),
     material("Stage", (.015, .023, .038), .5, .32))
root = empty(spec["name"] + " assembly")

def sparkle(parent=root, radius=2.2, count=24):
    for i in range(count):
        a = rng.uniform(0, TAU)
        r = rng.uniform(.9, radius)
        o = sphere("Golden stardust", (r*math.cos(a), r*math.sin(a), rng.uniform(.2, 3.5)),
                   (.016, .016, .016), hot, parent, 8)
        z = o.location.z
        key(o, 1, "location", tuple(o.location))
        key(o, scene.frame_end, "location", (o.location.x, o.location.y, z+.6))
        linear(o)

def petal(center, radius, angle, parent, mat=red):
    verts, faces = [], []
    nu, nv = 7, 5
    for u in range(nu+1):
        t = u/nu
        for v in range(nv+1):
            w = (v/nv-.5)*1.8
            r = radius*(.3+.7*t)
            a = angle+w*math.sin(t*math.pi*.8)
            verts.append((center[0]+r*math.cos(a), center[1]+r*math.sin(a),
                          center[2]+.08+.32*t-.19*t*t+.06*w*w))
    for u in range(nu):
        for v in range(nv):
            a = u*(nv+1)+v
            faces.append((a, a+1, a+nv+2, a+nv+1))
    return mesh("Sculpted silk petal", verts, faces, mat, parent)

def rose_at(x, y, z, parent, size=1):
    tube("Rose stem", [(x*.7, y*.7, .35), (x, y, z)], .018, green, parent)
    sphere("Rose leaf", (x+.13, y, z*.65), (.23, .045, .08), green, parent)
    for layer in range(4):
        count = 5+layer*2
        for j in range(count):
            petal((x, y, z+.03*layer), size*(.10+.055*layer), j*TAU/count+layer*.3, parent)

def roses(single=False):
    n = 1 if single else 9
    for i in range(n):
        a = i*2.39996
        r = .20*math.sqrt(i)
        rose_at(r*math.cos(a), r*math.sin(a), 1.6+.08*(i%3), root, 1.3 if single else 1)
    if not single:
        cone("Folded bouquet sleeve", .14, .61, .83, (0, 0, .75), gold, root)
        bow = ring("Ribbon knot", .15, (0, -.42, .82), pink, root)
        bow.rotation_euler.x = math.pi/2

def steam(z, radius=.6):
    mist = material("Soft pearly steam", (.30, .36, .42), 0, 1, .25)
    for i in range(6):
        x, y = rng.uniform(-radius, radius), rng.uniform(-radius*.5, radius*.5)
        o = tube("Rising steam wisp", [(x, y, z), (x+.08, y, z+.2), (x-.05, y, z+.45),
                                      (x+.1, y, z+.68)], .009, mist, root)
        key(o, 1, "location", (0, 0, 0))
        key(o, scene.frame_end, "location", (.12*math.sin(i), .06, .35))
        key(o, 1, "scale", (.7, .7, .7))
        key(o, scene.frame_end, "scale", (1.2, 1.2, 1.2))
        linear(o)

def bowl():
    # Open lathed bowl instead of a solid capped cone concealing the food.
    verts, faces = [], []
    profile = [(.64, .16), (.84, .24), (1.05, .47), (1.13, .68), (1.07, .68), (.82, .31), (.62, .24)]
    for r, z in profile:
        verts.extend((r*math.cos(i*TAU/48), r*math.sin(i*TAU/48), z) for i in range(48))
    for row in range(len(profile)-1):
        for i in range(48):
            j = (i+1)%48
            faces.append((row*48+i, row*48+j, (row+1)*48+j, (row+1)*48+i))
    mesh("Open porcelain serving bowl", verts, faces, ivory, root)
    ring("Gold serving rim", 1.1, (0, 0, .68), gold, root)

def rice(feast=False):
    bowl()
    saffron = material("Saffron grains", (.83, .49, .13), 0, .62)
    plain = material("Basmati grains", (.91, .84, .66), 0, .58)
    sphere("Full rice mound", (0, 0, .59), (.96, .96, .22), saffron, root)
    # Shared geometry and materials keep CPU rendering bounded.
    prototype = sphere("Basmati grain", (0, 0, 0), (.055, .015, .013), plain, root, 8)
    for i in range(340):
        a, r = rng.uniform(0, TAU), math.sqrt(rng.random())*.96
        o = prototype if i == 0 else bpy.data.objects.new("Basmati grain", prototype.data)
        if i:
            bpy.context.collection.objects.link(o)
            o.parent = root
            o.scale = prototype.scale.copy()
        o.location = (r*math.cos(a), r*math.sin(a), .64+.18*(1-r*r)+rng.uniform(0, .065))
        o.rotation_euler.z = rng.uniform(0, TAU)
    for i in range(40):
        a, r = rng.uniform(0, TAU), rng.uniform(.1, .9)
        o = sphere("Saffron garnish", (r*math.cos(a), r*math.sin(a), .82),
                   (.06, .018, .012), saffron, root, 8)
        o.rotation_euler.z = a
    for i in range(7):
        a = i*2.4
        sphere("Roasted garnish", (.6*math.cos(a), .6*math.sin(a), .84), (.1, .065, .035), green, root)
    if feast:
        for x in [-1.35, 1.35]:
            cone("Side dish", .30, .38, .22, (x, 0, .3), gold, root)
            sphere("Spiced sauce", (x, 0, .43), (.31, .31, .07), red, root)
    steam(.85)

def dumplings():
    bamboo = material("Bamboo steamer", (.55, .28, .095), 0, .48)
    cone("Steamer basket", 1.05, 1.05, .45, (0, 0, .43), bamboo, root)
    for z in [.25, .5, .68]:
        ring("Bamboo woven rim", 1.06, (0, 0, z), gold, root, .04)
    for i in range(7):
        a = i*2.4
        x, y = .26*math.sqrt(i)*math.cos(a), .26*math.sqrt(i)*math.sin(a)
        sphere("Pleated dumpling", (x, y, .78), (.23, .20, .16), ivory, root)
        for j in range(7):
            a = j*TAU/7
            tube("Dumpling fold", [(x+.19*math.cos(a), y+.16*math.sin(a), .78),
                                   (x+.08*math.cos(a), y+.07*math.sin(a), .94)], .012, gold, root)
    steam(.95)

def sushi():
    box("Obsidian sushi platter", (0, 0, .3), (2.7, 1.7, .14), black, root)
    salmon = material("Salmon glaze", (.92, .30, .16), 0, .36)
    for i in range(8):
        x, y = (i%4-1.5)*.55, (i//4-.5)*.65
        sphere("Pressed rice", (x, y, .49), (.23, .16, .13), ivory, root)
        o = box("Salmon nigiri", (x, y, .61), (.47, .32, .06), salmon, root)
        o.rotation_euler.z = .07*(i%3)
        for j in range(3):
            tube("Salmon marbling", [(x-.17+j*.1, y-.14, .65), (x-.10+j*.1, y+.14, .65)], .009, ivory, root)

def cake():
    for r, d, z in [(1.05, .55, .55), (.78, .48, 1.06), (.48, .4, 1.5)]:
        cone("Porcelain iced cake tier", r, r, d, (0, 0, z), ivory, root)
        ring("Gold icing band", r+.01, (0, 0, z+d*.33), gold, root)
        for i in range(12):
            a = i*TAU/12
            sphere("Sugar pearl", (r*math.cos(a), r*math.sin(a), z+d*.32), (.035,)*3, pink, root, 8)
    for i in range(5):
        a = i*TAU/5
        x, y = .30*math.cos(a), .30*math.sin(a)
        cone("Birthday candle", .026, .026, .25, (x, y, 1.83), pink, root)
        sphere("Candle flame", (x, y, 2.02), (.025, .025, .06), hot, root, 8)

def fountain(chocolate=False, hearts=False):
    fluid = material("Flowing chocolate", (.13, .035, .012), .05, .2) if chocolate else cyan
    cone("Catch basin", 1.05, 1.1, .23, (0, 0, .32), gold, root)
    for r, z in [(.8, .7), (.53, 1.22), (.27, 1.7)]:
        cone("Cascading tier", r, r*.72, .15, (0, 0, z), gold, root)
        for i in range(16):
            a = i*TAU/16
            points = [(r*.7*math.cos(a), r*.7*math.sin(a), z),
                      (r*math.cos(a), r*math.sin(a), z-.18),
                      ((r+.12)*math.cos(a), (r+.12)*math.sin(a), z-.47)]
            o = tube("Continuous flowing cascade", points, .025 if chocolate else .013, fluid, root)
            for f in [1, 24, 48, 72, 96, scene.frame_end]:
                key(o, f, "scale", (1, 1, .95+.05*math.sin(f*.16+i)))
    cone("Central fountain column", .10, .10, 1.4, (0, 0, 1), gold, root)
    if hearts:
        heart((0, 0, 2.2), .35)

def gem(loc=(0, 0, 1.4), size=.75, mat=None):
    r, z = size, loc[2]
    verts = [(loc[0], loc[1], z-size)]
    verts += [(loc[0]+r*math.cos(i*TAU/8), loc[1]+r*math.sin(i*TAU/8), z) for i in range(8)]
    verts += [(loc[0]+r*.58*math.cos(i*TAU/8), loc[1]+r*.58*math.sin(i*TAU/8), z+size*.42) for i in range(8)]
    faces = [(0, i+1, (i+1)%8+1) for i in range(8)]
    faces += [(i+1, (i+1)%8+1, (i+1)%8+9, i+9) for i in range(8)]
    faces += [tuple(range(9, 17))]
    return mesh("Cut gemstone", verts, faces, mat or cyan, root, False)

def crown():
    for z in [.7, .93]:
        ring("Royal crown band", .8, (0, 0, z), gold, root, .07)
    for i in range(8):
        a = i*TAU/8
        x, y = .8*math.cos(a), .8*math.sin(a)
        tube("Crown fleur", [(x, y, .72), (x*1.05, y*1.05, 1.2), (x*.94, y*.94, 1.7)], .055, gold, root)
        gem((x*.94, y*.94, 1.72), .14, accent)
        gem((x, y, .91), .09, cyan)
    cone("Velvet crown lining", .73, .53, .42, (0, 0, .93), red, root)

def jeweled_ring():
    o = ring("Solid gold promise ring", .7, (0, 0, 1.15), gold, root, .085)
    o.rotation_euler.x = math.pi/2
    gem((0, 0, 1.89), .35, green if args.scene == "emerald-ring" else cyan)
    for x in [-.34, -.17, .17, .34]:
        sphere("Ring shoulder diamond", (x, -.04, 1.7), (.055,)*3, ivory, root, 8)

def heart(loc=(0, 0, 1.4), size=.9, mat=pink):
    # Extruded curved heart with a rounded contour.
    contour = []
    for i in range(64):
        t = i*TAU/64
        x = 16*math.sin(t)**3/17*size
        z = (13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t))/17*size
        contour.append((x+loc[0], z+loc[2]))
    verts = [(x, loc[1]+y, z) for y in [-.12*size, .12*size] for x, z in contour]
    faces = [tuple(range(63, -1, -1)), tuple(range(64, 128))]
    faces += [(i, (i+1)%64, (i+1)%64+64, i+64) for i in range(64)]
    o = mesh("Sculpted heart", verts, faces, mat, root)
    bevel = o.modifiers.new("Rounded heart", "BEVEL")
    bevel.width = .055*size
    bevel.segments = 3
    return o

def palace(castle=False, temple=False):
    box("Marble foundation", (0, 0, .23), (2.6, 1.9, .25), ivory, root)
    box("Palace hall", (0, .22, .87), (1.4, 1.15, 1.15), ivory, root)
    box("Golden entrance", (0, -.38, .72), (.42, .06, .7), gold, root)
    for x in [-1, 1]:
        for y in [-.55, .55]:
            cone("Palace tower", .25, .25, 1.4, (x, y, 1), ivory, root)
            cone("Tower spire", .33, 0, .55, (x, y, 1.98), accent if castle else gold, root)
    if temple:
        for i in range(4):
            box("Temple stepped roof", (0, .22, 1.51+i*.18), (1.65-i*.32, 1.25-i*.22, .18), gold, root)
    else:
        sphere("Central palace dome", (0, .2, 1.52), (.62, .62, .49), gold, root)
        cone("Dome finial", .08, 0, .38, (0, .2, 2.12), gold, root)
    for x in [-.5, .5]:
        box("Glass palace window", (x, -.36, 1), (.18, .03, .28), cyan, root)

def wings(parent, z=1.9, width=1.6, mat=gold):
    result = []
    for side in [-1, 1]:
        verts = [(0, 0, 0), (side*width, .12, .8), (side*width*.92, .18, -.15),
                 (side*width*.45, .08, -.32)]
        o = mesh("Sculpted flight wing", verts, [(0, 1, 2, 3)], mat, parent)
        o.location.z = z
        mod = o.modifiers.new("Wing membrane", "SOLIDIFY")
        mod.thickness = .025
        for f in range(1, scene.frame_end+1, 12):
            key(o, f, "rotation_euler", (0, side*math.sin(f*.13)*.25, 0))
        result.append(o)
    return result

def creature(kind):
    if kind in ("dragon", "phoenix", "butterfly", "peacock", "swan", "whale"):
        if kind == "whale":
            sphere("Whale body", (0, 0, 1.25), (.58, 1.55, .52), blue, root)
            sphere("Whale head", (0, -.95, 1.3), (.64, .58, .53), blue, root)
            wings(root, 1.2, 1.2, blue)
            tube("Whale flukes", [(-.6, 1.4, 1.45), (0, 1.65, 1.23), (.6, 1.4, 1.45)], .13, blue, root)
        elif kind == "swan":
            sphere("Swan crystal body", (0, 0, .9), (.58, .83, .4), ivory, root)
            tube("Swan curved neck", [(0, -.45, 1), (0, -.8, 1.45), (0, -.6, 2.05), (0, -.85, 2.2)], .12, ivory, root)
            sphere("Swan head", (0, -.89, 2.2), (.16, .22, .16), ivory, root)
            cone("Swan golden beak", .09, 0, .28, (0, -1.14, 2.17), gold, root).rotation_euler.x = math.pi/2
            wings(root, 1.03, .72, ivory)
        elif kind == "peacock":
            sphere("Peacock royal body", (0, -.3, 1), (.35, .5, .55), blue, root)
            tube("Peacock neck", [(0, -.5, 1), (0, -.58, 1.55), (0, -.57, 1.9)], .1, blue, root)
            sphere("Peacock head", (0, -.57, 1.93), (.16, .18, .16), blue, root)
            for i in range(17):
                a = math.pi*.12+i*math.pi*.76/16
                x, z = 1.55*math.cos(a), 1+1.55*math.sin(a)
                tube("Peacock feather shaft", [(0, .25, .8), (x, .42, z)], .025, gold, root)
                sphere("Peacock feather eye", (x, .42, z), (.13, .035, .21), green, root)
                sphere("Peacock feather sapphire", (x, .38, z), (.065, .035, .09), cyan, root)
        else:
            bodymat = blue if "ice" in args.scene else gold
            if kind == "butterfly":
                bodymat = purple
            sphere("Flight creature body", (0, 0, 1.45), (.22, .27, .75), bodymat, root)
            sphere("Creature head", (0, -.10, 2.12), (.25, .32, .22), bodymat, root)
            wings(root, 1.7, 1.45, bodymat if kind != "phoenix" else fire)
            if kind == "butterfly":
                wings(root, 1.05, .95, pink)
                for x in [-.13, .13]:
                    tube("Butterfly antenna", [(x, 0, 2.2), (x*2, 0, 2.5)], .016, gold, root)
            else:
                tube("Creature curling tail", [(0, .1, .9), (.2, .2, .55), (.75, .25, .3), (1, .3, .65)], .11, bodymat, root)
                for i in range(5):
                    cone("Crest plume", .08, 0, .24, (0, .1, 1.3+i*.17), fire if kind == "phoenix" else gold, root)
                if kind == "dragon":
                    for x in [-.16, .16]:
                        cone("Dragon horn", .065, 0, .38, (x, .06, 2.38), gold, root)
                    sphere("Dragon fire breath", (0, -.58, 2), (.10, .42, .09), fire, root)
    else:
        fur = material("Animal coat", (.68, .32, .055) if kind != "leopard" else (.62, .68, .76), .18, .38)
        if kind == "horse":
            fur = ivory
        sphere("Animal torso", (0, 0, 1), (.34, .72, .40), fur, root)
        for x in [-.24, .24]:
            for y in [-.42, .42]:
                tube("Animal leg", [(x, y, 1), (x, y-.04, .55), (x, y-.03, .18)], .075, fur, root)
                sphere("Animal paw", (x, y-.08, .18), (.105, .16, .07), black, root)
        tube("Animal neck", [(0, -.43, 1), (0, -.66, 1.6)], .22 if kind == "horse" else .17, fur, root)
        sphere("Animal head", (0, -.78, 1.62), (.28, .34, .28), fur, root)
        for x in [-.17, .17]:
            cone("Animal ear", .08, 0, .20, (x, -.68, 1.96), fur, root)
            sphere("Animal eye", (x, -1.03, 1.68), (.028, .023, .028), black, root, 8)
        tube("Animal tail", [(0, .6, 1.12), (.22, 1, .94), (.3, 1.12, .55)], .045, fur, root)
        if kind == "lion":
            for i in range(16):
                a = i*TAU/16
                sphere("Lion mane", (.31*math.cos(a), -.66, 1.62+.31*math.sin(a)), (.14, .12, .16), gold, root)
        if kind in ("tiger", "leopard"):
            for i in range(20):
                y = -.55+(i//2)*.12
                x = (-1 if i%2 else 1)*.30
                sphere("Coat marking", (x, y, 1.07), (.022, .035 if kind == "leopard" else .055, .06), black, root, 8)

def vehicle(kind):
    if kind in ("jet", "shuttle"):
        sphere("Aerodynamic fuselage", (0, 0, 1.15), (.25, 1.55, .27), ivory if kind == "jet" else black, root)
        mesh("Swept aircraft wings", [(-1.5, .6, 1.05), (0, -.4, 1.1), (1.5, .6, 1.05), (0, .4, 1.08)],
             [(0, 1, 3), (1, 2, 3)], silver, root)
        sphere("Cockpit glass", (0, -1, 1.35), (.19, .35, .12), cyan, root)
        for x in [-.6, .6]:
            sphere("Attached turbine", (x, .4, .9), (.16, .43, .16), black, root)
        fin = box("Aircraft tail", (0, 1.1, 1.48), (.045, .45, .6), gold, root)
        fin.rotation_euler.x = -.3
    elif kind == "yacht":
        sphere("Yacht displacement hull", (0, 0, .6), (.65, 1.6, .4), ivory, root)
        box("Teak main deck", (0, 0, .89), (1.2, 2.55, .13), gold, root)
        box("Yacht cabin", (0, .3, 1.1), (.85, 1.25, .45), ivory, root)
        box("Panoramic cabin glass", (0, -.34, 1.15), (.77, .05, .25), cyan, root)
        box("Flybridge", (0, .38, 1.43), (.9, 1.35, .1), ivory, root)
        for r in [1.8, 2.1, 2.4]:
            ring("Ocean wake", r, (0, 0, .21), blue, root, .02)
    else:
        carriage = kind == "carriage"
        body = gold if carriage else red
        box("Carriage coach" if carriage else "Sports car body", (0, 0, .65), (1.2, 1.9, .42), body, root)
        sphere("Coach roof" if carriage else "Car canopy", (0, .15, .96), (.51, .62, .37), gold if carriage else black, root)
        box("Windshield", (0, -.35, 1.01), (.86, .06, .31), cyan, root)
        for x in [-.63, .63]:
            for y in [-.62, .62]:
                wheel = ring("Spoked wheel", .33 if carriage else .23, (x, y, .4), black, root, .06)
                wheel.rotation_euler.y = math.pi/2
                hub = sphere("Wheel hub", (x, y, .4), (.05, .10, .10), gold, root)
                if carriage:
                    for i in range(8):
                        a = i*TAU/8
                        tube("Coach wheel spoke", [(x, y, .4), (x, y+.30*math.cos(a), .4+.30*math.sin(a))], .012, gold, root)
        for x in [-.43, .43]:
            sphere("Headlamp", (x, -.97, .74), (.12, .035, .065), hot, root)

def garden(forest=False):
    for i in range(9):
        a = i*2.4
        r = .35*math.sqrt(i)
        x, y = r*math.cos(a), r*math.sin(a)
        if forest:
            cone("Forest tree trunk", .07, .045, .9, (x, y, .6), gold, root)
            for z, rad in [(1, .4), (1.35, .32), (1.65, .23)]:
                cone("Evergreen canopy", rad, 0, .6, (x, y, z), green, root)
        else:
            rose_at(x, y, .9+.15*(i%3), root, .8)
    ring("Garden perimeter", 1.55, (0, 0, .2), gold, root)

def cosmos(kind):
    if kind in ("galaxy", "aurora"):
        sphere("Celestial core", (0, 0, 1.4), (.28,)*3, hot, root)
        for i in range(6):
            orbit = ring("Celestial orbit", .65+i*.17, (0, 0, 1.4), palette[i%5], root, .018)
            orbit.rotation_euler = (i*.28+.4, i*.18, 0)
            key(orbit, 1, "rotation_euler", tuple(orbit.rotation_euler))
            key(orbit, scene.frame_end, "rotation_euler", (i*.28+.4, i*.18, TAU*.35))
            planet = sphere("Orbiting gemstone", (.65+i*.17, 0, 1.4), (.10+.02*(i%3),)*3, palette[i%5], root)
            for f in range(1, scene.frame_end+1, 12):
                a = f/scene.frame_end*TAU+i
                key(planet, f, "location", ((.65+i*.17)*math.cos(a), (.65+i*.17)*math.sin(a), 1.4+math.sin(a)*.35))
    elif kind == "waterfall":
        for i in range(14):
            x = (i-6.5)*.16
            tube("Rainbow water ribbon", [(x, .4, 2.4), (x, .3, 1.8), (x, -.15, .4)], .045, palette[i%5], root)
        cone("Waterfall pool", 1.4, 1.4, .12, (0, 0, .25), blue, root)
    elif kind == "lanterns":
        for i in range(12):
            x, y = rng.uniform(-1.4, 1.4), rng.uniform(-.6, .6)
            lantern = empty("Rising lantern")
            lantern.parent = root
            sphere("Paper lantern", (x, y, 0), (.16, .16, .25), gold, lantern)
            ring("Lantern base", .12, (x, y, -.20), red, lantern)
            sphere("Lantern candle", (x, y, -.10), (.05,)*3, hot, lantern, 8)
            key(lantern, 1, "location", (0, 0, .35+i*.16))
            key(lantern, scene.frame_end, "location", (.1, 0, 1.2+i*.18))
            linear(lantern)
    elif kind == "meteors":
        for i in range(16):
            o = empty("Falling meteor")
            o.parent = root
            x, y, z = rng.uniform(-1.8, 1.8), rng.uniform(-.8, .8), rng.uniform(1, 3)
            sphere("Meteor head", (x, y, z), (.07,)*3, hot, o, 8)
            tube("Meteor trail", [(x, y, z), (x+.25, y, z+.7)], .025, fire, o)
            key(o, 1, "location", (.6, 0, 1))
            key(o, scene.frame_end, "location", (-.6, 0, -.8))
            linear(o)

def person(x, woman=False):
    p = empty("Couple partner")
    p.parent = root
    p.location.x = x
    skin = material("Warm ceramic skin", (.64, .35, .20), .12, .36)
    sphere("Partner face", (0, 0, 1.68), (.14, .12, .19), skin, p)
    sphere("Sculpted hair", (0, .035, 1.77), (.15, .12, .14), black, p)
    for x_eye in [-.045, .045]:
        sphere("Partner eye", (x_eye, -.113, 1.73), (.015, .012, .015), black, p, 8)
    sphere("Partner nose", (0, -.127, 1.69), (.025, .028, .027), skin, p, 8)
    tube("Partner smile", [(-.035, -.137, 1.645), (0, -.141, 1.637),
                           (.035, -.137, 1.645)], .008, red, p)
    cone("Dress" if woman else "Tailored jacket", .32 if woman else .17, .13, .7,
         (0, 0, 1.03), ivory if spec["builder"] == "wedding" and woman else pink if woman else black, p)
    for side in [-1, 1]:
        tube("Partner leg", [(side*.09, 0, .74), (side*.09, 0, .20)], .055, skin if woman else black, p)
        sphere("Partner shoe", (side*.09, -.035, .16), (.07, .12, .045), black, p)
        tube("Partner arm", [(side*.14, 0, 1.3), (side*.22, -.06, 1.04), (side*.16, -.1, .95)], .045, skin, p)
    return p

def romance(kind):
    if kind in ("heart", "hearts"):
        if kind == "heart":
            heart()
        else:
            heart((-.52, 0, 1.4), .65, pink)
            heart((.52, .1, 1.55), .65, gold)
            ring("Infinity vow", .36, (0, -.05, .52), gold, root, .07)
        return
    left, right = person(-1, False), person(1, True)
    for p, sign in [(left, -1), (right, 1)]:
        key(p, 1, "location", (sign*1.1, 0, 0))
        key(p, round(scene.frame_end*.45), "location", (sign*.31, 0, 0))
        key(p, round(scene.frame_end*.80), "location", (sign*(.18 if kind in ("kiss", "hug") else .31), 0, 0))
        key(p, scene.frame_end, "location", (sign*(.18 if kind in ("kiss", "hug") else .31), 0, 0))
    if kind in ("kiss", "hug"):
        for p, sign in [(left, 1), (right, -1)]:
            key(p, 1, "rotation_euler", (0, 0, 0))
            key(p, round(scene.frame_end*.5), "rotation_euler", (0, 0, sign*math.pi*.35))
            key(p, round(scene.frame_end*.8), "rotation_euler", (0, 0, sign*math.pi/2))
            key(p, scene.frame_end, "rotation_euler", (0, 0, sign*math.pi/2))
    heart((0, .22, 2.3), .32)
    if kind == "wedding":
        tube("Wedding floral arch", [(-1.2, .45, .2), (-1.25, .45, 1.9), (0, .45, 2.65),
                                    (1.25, .45, 1.9), (1.2, .45, .2)], .065, gold, root)
        for i in range(9):
            a = i*math.pi/8
            sphere("Wedding arch rose", (1.2*math.cos(a), .44, 1.6+math.sin(a)), (.12,)*3, red, root)
    elif kind == "proposal":
        jeweled_ring()
        for i in range(3):
            rose_at(-.7+i*.7, .6, .8, root, .5)
    elif kind == "date":
        sphere("Moonlit date moon", (0, .5, 2.5), (.35, .08, .35), ivory, root)
        box("Garden bench", (0, .55, .55), (1.5, .4, .16), gold, root)

def opera():
    for x in [-.45, .45]:
        sphere("Opera mask", (x, 0, 1.3), (.38, .15, .53), gold if x < 0 else ivory, root)
        for dx in [-.13, .13]:
            sphere("Opera eye opening", (x+dx, -.15, 1.47), (.07, .025, .045), black, root)
        points = [(x-.14, -.17, 1.08), (x, -.18, 1.02 if x < 0 else 1.17), (x+.14, -.17, 1.08)]
        tube("Opera expression", points, .02, black, root)

def country():
    code = args.scene[5:]
    texture = HERE / "flags" / (code + ".png")
    if not texture.is_file():
        raise FileNotFoundError("Missing verified national flag: " + code)
    cloth = material("National flag cloth", (1, 1, 1), 0, .55)
    nodes = cloth.node_tree.nodes
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(str(texture))
    nodes.active = image
    cloth.node_tree.links.new(image.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    verts, faces = [], []
    nx, nz = (64, 48) if code == "np" else (24, 12)
    pixels = list(image.image.pixels) if code == "np" else None
    height = 2.1*image.image.size[1]/image.image.size[0]
    for z in range(nz+1):
        for x in range(nx+1):
            verts.append((-1+x/nx*2.1, 0, 1.75+(z/nz-.5)*height))
    for z in range(nz):
        for x in range(nx):
            a = z*(nx+1)+x
            if pixels is not None:
                px = min(image.image.size[0]-1, int((x+.5)/nx*image.image.size[0]))
                pz = min(image.image.size[1]-1, int((z+.5)/nz*image.image.size[1]))
                if pixels[(pz*image.image.size[0]+px)*4+3] < .5:
                    continue
            faces.append((a, a+1, a+nx+2, a+nx+1))
    flag = mesh("Waving " + code.upper() + " national flag", verts, faces, cloth, root)
    uv = flag.data.uv_layers.new(name="Flag UV")
    for poly in flag.data.polygons:
        for li in poly.loop_indices:
            vi = flag.data.loops[li].vertex_index
            uv.data[li].uv = ((vi%(nx+1))/nx, (vi//(nx+1))/nz)
    flag.shape_key_add(name="Basis")
    states = []
    for phase in range(4):
        shape = flag.shape_key_add(name="Wind " + str(phase))
        for vi, vertex in enumerate(shape.data):
            x = (vi%(nx+1))/nx
            z = (vi//(nx+1))/nz
            vertex.co.y = .28*x*math.sin(x*8+z*2+phase*math.pi/2)
            vertex.co.z += .045*x*math.sin(x*8-z*3+phase*math.pi/2)
        states.append(shape)
    for f in range(1, scene.frame_end+1, 6):
        phase = ((f-1)//6)%4
        for i, shape in enumerate(states):
            shape.value = 1 if i == phase else 0
            shape.keyframe_insert(data_path="value", frame=f)
    cone("Gold flag mast", .026, .026, 2.6, (-1.04, 0, 1.3), gold, root)
    sphere("Mast finial", (-1.04, 0, 2.64), (.07,)*3, gold, root)
    camera.location = (.05, -5.8, 1.75)
    camera.data.lens = 52
    camera.rotation_euler = aim(camera, (0, 0, 1.75))

def exhaust(parent, x, y, z, radius):
    for mat, length, width in [(fire, 1.55, 1), (hot, .83, .47)]:
        flame = cone("Anchored tapered exhaust", 0, radius*width, length, (x, y, z), mat, parent)
        for v in flame.data.vertices:
            v.co.z -= length/2
        for f in range(1, scene.frame_end+1, 8):
            strength = (.10+1.05*min(1, (f-1)/192))*(.93+.09*math.sin(f*.7+x*10))
            key(flame, f, "scale", (1, 1, strength))
        linear(flame)

def rocket():
    level = spec["level"]
    root.name = "Single integrated stealth-black Rocket level " + str(level)
    cone("Graphite pressure hull", .40, .40, 2.7, (0, 0, 2.05), black, root)
    cone("Glossy aerodynamic nose", .40, 0, 1, (0, 0, 3.90), black, root)
    for z in [.73, 1.2, 2.1, 3.35]:
        ring("Gold structural collar", .408, (0, 0, z), gold, root, .022)
    for z in [1.85, 2.55]:
        sphere("Blue glass porthole", (0, -.40, z), (.095, .026, .12), cyan, root)
    for i in range(4):
        a = i*math.pi/2
        verts = [(.38, 0, 1.22), (.9, 0, .70), (.38, 0, .73), (.40, .05, 1.22), (.90, .05, .70), (.40, .05, .73)]
        fin = mesh("Integrated swept stabilizer", verts, [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2)], black, root)
        fin.rotation_euler.z = a
        stripe = tube("Red stabilizer accent", [(.41, 0, 1.12), (.77, 0, .78)], .015, red, root)
        stripe.rotation_euler.z = a
    cone("Steel bell nozzle", .27, .18, .42, (0, 0, .56), silver, root)
    exhaust(root, 0, 0, .36, .25)
    if level >= 2:
        for z in [1.35, 1.55]:
            ring("Reinforced hull band", .43, (0, 0, z), silver, root, .04)
    booster_count = 0 if level < 3 else 2 if level < 5 else 4 if level < 7 else 6
    for i in range(booster_count):
        a = i*TAU/booster_count
        radius = .69 if level < 7 else .84
        x, y = radius*math.cos(a), radius*math.sin(a)
        r = .17+.005*level
        d = 1.5+.08*level
        cone("Attached heavy booster", r, r, d, (x, y, .92+d/2), black, root)
        cone("Booster aerodynamic cap", r, 0, .43, (x, y, 1.13+d), black, root)
        for z in [1.18, 2.05]:
            box("Integral mounting bracket", (x*.65, y*.65, z), (.3, .16, .12), gold, root)
        cone("Booster nozzle", r, r*.65, .28, (x, y, .82), silver, root)
        exhaust(root, x, y, .68, r*.85)
    if level >= 4:
        for i in range(4):
            a = i*math.pi/2
            o = box("Attached hull armour", (.42*math.cos(a), .42*math.sin(a), 2.5), (.12, .23, .8), black, root)
            o.rotation_euler.z = a
    if level >= 6:
        for x in [-.25, .25]:
            cone("Heavy secondary engine", .10, .08, .25, (x, -.1, .52), silver, root)
            exhaust(root, x, -.1, .4, .095)
    if level >= 8:
        for i in range(4):
            a = i*math.pi/2
            o = box("Heavy shoulder fuel pod", (1.03*math.cos(a), 1.03*math.sin(a), 1.95), (.20, .23, 1.1), black, root)
            o.rotation_euler.z = a
            box("Fuel pod connection", (.86*math.cos(a), .86*math.sin(a), 2.05), (.3, .18, .12), gold, root)
    if level >= 9:
        for z in [2.30, 2.65, 3.0]:
            ring("Integrated cyan plasma cage", .50, (0, 0, z), cyan, root, .028)
    if level == 10:
        cone("Command antenna", .04, 0, .40, (0, 0, 4.58), gold, root)
        for z in [1.75, 2.15]:
            ring("Command armour collar", .47, (0, 0, z), gold, root, .045)
    cone("Launch platform", 1.8, 1.8, .18, (0, 0, -.02), black)
    ring("Launch pad guidance ring", 1.68, (0, 0, .08), cyan, thickness=.025)
    for f, z in [(1, 0), (192, 0), (193, 0), (200, .65), (208, 3.4), (216, 9.5)]:
        key(root, f, "location", (0, 0, z))
    # Tracking includes the full model and attached boosters through liftoff.
    camera.location = (6, -11, 5.6)
    camera.data.lens = 43
    for f, at in [(1, 2.15), (192, 2.15), (193, 2.15), (200, 2.8), (208, 5.5), (216, 11.4)]:
        key(camera, f, "rotation_euler", aim(camera, (0, 0, at)))
    linear(root)
    linear(camera)
    smoke = material("Launch smoke", (.18, .22, .28), 0, 1)
    for i in range(16):
        a = i*2.4
        cloud = sphere("Billowing launch smoke", (0, 0, .1), (.01,)*3, smoke, segments=12)
        key(cloud, 1, "scale", (.001,)*3)
        key(cloud, 24, "scale", (.001,)*3)
        key(cloud, 65, "scale", (.28, .28, .20))
        key(cloud, 125, "scale", (.58, .58, .32))
        key(cloud, 192, "scale", (.72, .72, .40))
        key(cloud, 216, "scale", (.92, .92, .50))
        for f, r in [(1, .1), (24, .1), (65, .9), (125, 2), (216, 3)]:
            key(cloud, f, "location", (r*math.cos(a), r*math.sin(a), .10+i%3*.08))
    for i in range(18+level):
        gift = empty("Falling wrapped gift")
        x, y = rng.uniform(-2.4, 2.4), rng.uniform(-.7, .7)
        box("Gift box", (0, 0, 0), (.16, .16, .16), palette[i%5], gift, .01)
        box("Gift ribbon X", (0, 0, .085), (.17, .035, .012), gold, gift, 0)
        box("Gift ribbon Y", (0, 0, .086), (.035, .17, .012), gold, gift, 0)
        for f, z in [(1, -4), (192, -4), (193+i%8, 7), (216, 1+i*.06)]:
            key(gift, f, "location", (x, y, z))
            key(gift, f, "rotation_euler", (f*.023, f*.03, f*.021))
        linear(gift)

builder = spec["builder"]
if builder == "rocket":
    rocket()
elif builder in ("rose", "bouquet"):
    roses(builder == "rose")
elif builder in ("rice", "feast"):
    rice(builder == "feast")
elif builder == "dumplings":
    dumplings()
elif builder == "sushi":
    sushi()
elif builder == "cake":
    cake()
elif builder in ("fountain", "chocolate", "heart-fountain"):
    fountain(builder == "chocolate", builder == "heart-fountain")
elif builder == "jewel":
    gem()
    ring("Jewel display halo", 1.0, (0, 0, .5), gold, root)
elif builder == "crown":
    crown()
elif builder == "ring":
    jeweled_ring()
elif builder == "pearl":
    sphere("Ocean pearl", (0, 0, 1), (.48,)*3, ivory, root)
    for side in [-1, 1]:
        shell = sphere("Open pearl shell", (side*.35, 0, .73), (.6, .7, .11), pink, root)
        shell.rotation_euler.y = side*.6
elif builder in ("castle", "palace", "temple"):
    palace(builder == "castle", builder == "temple")
elif builder in ("dragon", "phoenix", "swan", "peacock", "butterfly", "whale", "tiger", "leopard", "lion", "horse"):
    creature(builder)
elif builder in ("car", "carriage", "yacht", "jet", "shuttle"):
    vehicle(builder)
elif builder in ("garden", "forest"):
    garden(builder == "forest")
elif builder in ("galaxy", "aurora", "waterfall", "lanterns", "meteors"):
    cosmos(builder)
elif builder in ("heart", "hearts", "couple", "kiss", "hug", "date", "proposal", "wedding"):
    romance(builder)
elif builder == "opera":
    opera()
elif builder == "country":
    country()
else:
    raise ValueError("Unimplemented catalog builder: " + builder)

if builder not in ("rocket", "country"):
    if args.scene.startswith("cp-") and builder in ("cake", "carriage", "palace"):
        heart((0, 0, 2.4), .28)
    sparkle()
    for f, angle in [(1, -.18), (scene.frame_end//2, .12), (scene.frame_end, .30)]:
        key(root, f, "rotation_euler", (0, 0, angle))
    # One polished reveal, then a gentle turn; no loop restart before delivery.
    key(root, 1, "scale", (.82,)*3)
    key(root, 18, "scale", (1,)*3)
    key(root, scene.frame_end, "scale", (1,)*3)

if builder == "country":
    # Flag films use real deformed textured geometry with studio lighting.
    # Workbench avoids hundreds of repeated expensive PBR shadow passes.
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.background_type = "WORLD"

if builder not in ("rocket", "country"):
    sys.path.insert(0, str(HERE))
    from surface_detail import enhance
    enhance(globals())

if args.geometry_only:
    if len([o for o in bpy.data.objects if o.type == "MESH"]) < 3:
        raise RuntimeError("Scene has insufficient modeled geometry")
    raise SystemExit(0)

poster_frame = args.poster_frame or (48 if builder == "rocket" else min(48, scene.frame_end))
if not 1 <= poster_frame <= scene.frame_end:
    raise ValueError("Poster frame lies outside the movie")
scene.frame_set(poster_frame)
scene.render.filepath = str(out / "poster.png")
bpy.ops.render.render(write_still=True)
if not args.poster_only:
    scene.render.filepath = str(out / "frame-")
    bpy.ops.render.render(animation=True)
